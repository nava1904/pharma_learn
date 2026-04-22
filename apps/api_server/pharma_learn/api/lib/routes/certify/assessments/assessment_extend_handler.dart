import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/certify/assessments/:id/extend
///
/// Employee requests extension for a running assessment.
/// Body: { requested_extension_minutes, reason }
Future<Response> assessmentExtendRequestHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (attemptId == null || attemptId.isEmpty) {
    throw ValidationException({'id': 'Assessment attempt ID is required'});
  }

  final requestedMinutes = (body['requested_extension_minutes'] as num?)?.toInt();
  if (requestedMinutes == null) {
    throw ValidationException({'requested_extension_minutes': 'Required field'});
  }
  final reason = requireString(body, 'reason');

  if (requestedMinutes <= 0 || requestedMinutes > 60) {
    throw ValidationException({
      'requested_extension_minutes': 'Must be between 1 and 60 minutes',
    });
  }

  // Get the attempt
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, employee_id, status, started_at, time_limit_minutes,
        question_paper:question_papers(
          id, title
        )
      ''')
      .eq('id', attemptId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  // Verify it's the employee's own attempt
  if (attempt['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('You can only request extension for your own assessment');
  }

  // Check attempt is still in progress
  if (attempt['status'] != 'started' && attempt['status'] != 'in_progress') {
    throw ConflictException('Extension can only be requested for in-progress assessments');
  }

  // Check if already has a pending extension request
  final existingRequest = await supabase
      .from('question_paper_extensions')
      .select('id, status')
      .eq('attempt_id', attemptId)
      .eq('status', 'pending')
      .maybeSingle();

  if (existingRequest != null) {
    throw ConflictException('You already have a pending extension request');
  }

  // Create extension request
  final extension = await supabase
      .from('question_paper_extensions')
      .insert({
        'attempt_id': attemptId,
        'employee_id': auth.employeeId,
        'requested_extension_minutes': requestedMinutes,
        'reason': reason,
        'status': 'pending',
        'requested_at': DateTime.now().toUtc().toIso8601String(),
        'organization_id': auth.orgId,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'assessment_extension',
    aggregateId: extension['id'] as String,
    eventType: 'assessment_extension.requested',
    payload: {
      'attempt_id': attemptId,
      'employee_id': auth.employeeId,
      'requested_minutes': requestedMinutes,
    },
  );

  return ApiResponse.created({
    'extension_request': extension,
    'message': 'Extension request submitted. Awaiting coordinator approval.',
  }).toResponse();
}

/// POST /v1/certify/assessments/:id/extend/approve
///
/// Coordinator approves extension request.
/// Body: { extension_minutes_granted, esig: { reauth_session_id, meaning } }
Future<Response> assessmentExtendApproveHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to approve extensions');
  }

  if (attemptId == null || attemptId.isEmpty) {
    throw ValidationException({'id': 'Assessment attempt ID is required'});
  }

  final grantedMinutes = (body['extension_minutes_granted'] as num?)?.toInt();
  if (grantedMinutes == null) {
    throw ValidationException({'extension_minutes_granted': 'Required field'});
  }

  if (grantedMinutes <= 0 || grantedMinutes > 120) {
    throw ValidationException({
      'extension_minutes_granted': 'Must be between 1 and 120 minutes',
    });
  }

  // Validate e-signature
  final esig = body['esig'] as Map<String, dynamic>?;
  if (esig == null) {
    throw ValidationException({'esig': 'E-signature is required for approval'});
  }

  // Get pending extension request
  final extensionRequest = await supabase
      .from('question_paper_extensions')
      .select('id, attempt_id, status, requested_extension_minutes')
      .eq('attempt_id', attemptId)
      .eq('status', 'pending')
      .maybeSingle();

  if (extensionRequest == null) {
    throw NotFoundException('No pending extension request found');
  }

  // Verify attempt is still in progress
  final attempt = await supabase
      .from('assessment_attempts')
      .select('id, status, time_limit_minutes')
      .eq('id', attemptId)
      .single();

  if (attempt['status'] != 'started' && attempt['status'] != 'in_progress') {
    throw ConflictException('Assessment is no longer in progress');
  }

  // Create e-signature
  final esigService = EsigService(supabase);
  final esigId = await esigService.createEsignature(
    employeeId: auth.employeeId,
    meaning: esig['meaning'] as String? ?? 'APPROVE_ASSESSMENT_EXTENSION',
    entityType: 'question_paper_extension',
    entityId: extensionRequest['id'] as String,
    reauthSessionId: esig['reauth_session_id'] as String,
  );

  // Update extension request
  await supabase
      .from('question_paper_extensions')
      .update({
        'status': 'approved',
        'extension_minutes_granted': grantedMinutes,
        'approved_by': auth.employeeId,
        'approved_at': DateTime.now().toUtc().toIso8601String(),
        'esignature_id': esigId,
      })
      .eq('id', extensionRequest['id']);

  // Extend the attempt's time limit
  final newTimeLimit = (attempt['time_limit_minutes'] as int) + grantedMinutes;
  await supabase
      .from('assessment_attempts')
      .update({
        'time_limit_minutes': newTimeLimit,
        'extension_granted': true,
        'extension_minutes': grantedMinutes,
      })
      .eq('id', attemptId);

  await OutboxService(supabase).publish(
    aggregateType: 'assessment_extension',
    aggregateId: extensionRequest['id'] as String,
    eventType: 'assessment_extension.approved',
    payload: {
      'attempt_id': attemptId,
      'granted_minutes': grantedMinutes,
      'approved_by': auth.employeeId,
    },
  );

  return ApiResponse.ok({
    'message': 'Extension approved',
    'extension_minutes_granted': grantedMinutes,
    'new_time_limit_minutes': newTimeLimit,
  }).toResponse();
}

/// POST /v1/certify/assessments/:id/extend/reject
///
/// Coordinator rejects extension request.
/// Body: { reason }
Future<Response> assessmentExtendRejectHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to reject extensions');
  }

  if (attemptId == null || attemptId.isEmpty) {
    throw ValidationException({'id': 'Assessment attempt ID is required'});
  }

  final reason = requireString(body, 'reason');

  // Get pending extension request
  final extensionRequest = await supabase
      .from('question_paper_extensions')
      .select('id, status')
      .eq('attempt_id', attemptId)
      .eq('status', 'pending')
      .maybeSingle();

  if (extensionRequest == null) {
    throw NotFoundException('No pending extension request found');
  }

  await supabase
      .from('question_paper_extensions')
      .update({
        'status': 'rejected',
        'rejection_reason': reason,
        'rejected_by': auth.employeeId,
        'rejected_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', extensionRequest['id']);

  await OutboxService(supabase).publish(
    aggregateType: 'assessment_extension',
    aggregateId: extensionRequest['id'] as String,
    eventType: 'assessment_extension.rejected',
    payload: {
      'attempt_id': attemptId,
      'rejected_by': auth.employeeId,
      'reason': reason,
    },
  );

  return ApiResponse.ok({
    'message': 'Extension request rejected',
    'reason': reason,
  }).toResponse();
}

/// GET /v1/certify/assessments/extensions/pending
///
/// Coordinator views pending extension requests.
Future<Response> assessmentExtensionsPendingHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view extensions');
  }

  final extensions = await supabase
      .from('question_paper_extensions')
      .select('''
        id, requested_extension_minutes, reason, requested_at,
        employee:employees!question_paper_extensions_employee_id_fkey(
          id, first_name, last_name
        ),
        attempt:assessment_attempts(
          id, started_at, time_limit_minutes,
          question_paper:question_papers(
            id, title
          )
        )
      ''')
      .eq('organization_id', auth.orgId)
      .eq('status', 'pending')
      .order('requested_at', ascending: true);

  return ApiResponse.ok({
    'pending_extensions': extensions,
    'count': (extensions as List).length,
  }).toResponse();
}
