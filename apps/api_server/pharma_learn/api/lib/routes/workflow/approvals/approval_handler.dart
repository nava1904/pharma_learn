import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/workflow/approvals
/// Returns pending approval steps for the authenticated employee.
/// Only returns steps where employee has the required role/tier.
Future<Response> approvalListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1')
      ?.clamp(1, 1000) ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20')
      ?.clamp(1, 100) ?? 20;
  final offset = (page - 1) * perPage;

  // Get pending approvals where employee has required role
  final approvals = await supabase
      .from('approval_steps')
      .select('''
        id,
        entity_type,
        entity_id,
        step_order,
        step_name,
        required_role,
        min_approval_tier,
        status,
        created_at,
        documents:entity_id(title, version, status),
        courses:entity_id(title, version, status),
        training_plans:entity_id(title, version, status)
      ''')
      .eq('organization_id', auth.orgId)
      .eq('status', 'pending')
      .order('created_at')
      .range(offset, offset + perPage - 1);

  // Filter to only those the current user can approve
  // (This should ideally be done in SQL with a view/function)
  final filteredApprovals = (approvals as List).where((step) {
    return auth.hasPermission('${step['entity_type']}.approve');
  }).toList();

  final countResult = await supabase
      .from('approval_steps')
      .select()
      .eq('organization_id', auth.orgId)
      .eq('status', 'pending')
      .count();

  return ApiResponse.paginated(
    {'approvals': filteredApprovals},
    Pagination.compute(page: page, perPage: perPage, total: countResult.count),
  ).toResponse();
}

/// GET /v1/workflow/approvals/:id
/// Returns details of a specific approval step.
Future<Response> approvalGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final step = await supabase
      .from('approval_steps')
      .select('''
        *,
        documents:entity_id(id, title, version, status, created_by, summary),
        courses:entity_id(id, title, version, status, created_by, description),
        training_plans:entity_id(id, title, version, status, created_by)
      ''')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (step == null) {
    throw NotFoundException('Approval step not found');
  }

  // Check permission
  final entityType = step['entity_type'] as String;
  await PermissionChecker(supabase).require(
    auth.employeeId,
    '${entityType}.approve',
    jwtPermissions: auth.permissions,
  );

  return ApiResponse.ok({'approval': step}).toResponse();
}

/// POST /v1/workflow/approvals/:id/approve
/// Approves an approval step (requires e-signature if step requires it).
Future<Response> approvalApproveHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Get step details
  final step = await supabase
      .from('approval_steps')
      .select('entity_type, entity_id, status, required_role')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (step == null) {
    throw NotFoundException('Approval step not found');
  }

  if (step['status'] != 'pending') {
    throw ConflictException('Step is not pending: ${step['status']}');
  }

  // Check permission
  final entityType = step['entity_type'] as String;
  await PermissionChecker(supabase).require(
    auth.employeeId,
    '${entityType}.approve',
    jwtPermissions: auth.permissions,
  );

  // Get e-signature session from context if required
  final esig = RequestContext.esig;
  final esignatureSessionId = esig?.reauthSessionId;

  // Call workflow_engine internal endpoint
  final workflowEngineUrl = const String.fromEnvironment(
    'WORKFLOW_ENGINE_URL',
    defaultValue: 'http://localhost:8085',
  );

  final response = await http.post(
    Uri.parse('$workflowEngineUrl/internal/workflow/approve-step'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'step_id': id,
      'approved_by': auth.employeeId,
      'esignature_id': esignatureSessionId,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to approve step: ${response.body}');
  }

  final result = jsonDecode(response.body) as Map<String, dynamic>;

  return ApiResponse.ok(result['data'] ?? result).toResponse();
}

/// POST /v1/workflow/approvals/:id/reject
/// Rejects an approval step (requires reason and e-signature if required).
Future<Response> approvalRejectHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  final reason = body['reason'] as String?;
  if (reason == null || reason.trim().isEmpty) {
    throw ValidationException({'reason': 'Rejection reason is required'});
  }

  // Get step details
  final step = await supabase
      .from('approval_steps')
      .select('entity_type, entity_id, status, required_role')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (step == null) {
    throw NotFoundException('Approval step not found');
  }

  if (step['status'] != 'pending') {
    throw ConflictException('Step is not pending: ${step['status']}');
  }

  // Check permission
  final entityType = step['entity_type'] as String;
  await PermissionChecker(supabase).require(
    auth.employeeId,
    '${entityType}.approve',
    jwtPermissions: auth.permissions,
  );

  // Get e-signature session from context if required
  final esig = RequestContext.esig;
  final esignatureSessionId = esig?.reauthSessionId;

  // Call workflow_engine internal endpoint
  final workflowEngineUrl = const String.fromEnvironment(
    'WORKFLOW_ENGINE_URL',
    defaultValue: 'http://localhost:8085',
  );

  final response = await http.post(
    Uri.parse('$workflowEngineUrl/internal/workflow/reject'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'step_id': id,
      'rejected_by': auth.employeeId,
      'reason': reason,
      'esignature_id': esignatureSessionId,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to reject step: ${response.body}');
  }

  final result = jsonDecode(response.body) as Map<String, dynamic>;

  return ApiResponse.ok(result['data'] ?? result).toResponse();
}

/// GET /v1/workflow/approvals/history
/// Returns historical approval actions taken by the authenticated employee.
Future<Response> approvalHistoryHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1')
      ?.clamp(1, 1000) ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20')
      ?.clamp(1, 100) ?? 20;
  final offset = (page - 1) * perPage;

  final history = await supabase
      .from('approval_steps')
      .select('''
        id,
        entity_type,
        entity_id,
        step_name,
        status,
        approved_at,
        rejection_reason
      ''')
      .eq('approved_by', auth.employeeId)
      .neq('status', 'pending')
      .order('approved_at', ascending: false)
      .range(offset, offset + perPage - 1);

  final countResult = await supabase
      .from('approval_steps')
      .select()
      .eq('approved_by', auth.employeeId)
      .neq('status', 'pending')
      .count();

  return ApiResponse.paginated(
    {'history': history},
    Pagination.compute(page: page, perPage: perPage, total: countResult.count),
  ).toResponse();
}

/// POST /v1/workflow/approvals/:id/return
/// Returns an approval to the submitter for corrections (soft reject).
/// 
/// Unlike reject (which terminates the workflow), return allows the
/// submitter to make corrections and resubmit for approval.
/// 
/// WHO GMP §4.3.3 - Document control must allow for corrections and re-review.
Future<Response> approvalReturnHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  final reason = body['reason'] as String?;
  final corrections = body['corrections'] as List<dynamic>?;
  
  if (reason == null || reason.trim().isEmpty) {
    throw ValidationException({'reason': 'Return reason is required'});
  }

  // Get step details
  final step = await supabase
      .from('approval_steps')
      .select('entity_type, entity_id, status, required_role, step_name')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (step == null) {
    throw NotFoundException('Approval step not found');
  }

  if (step['status'] != 'pending') {
    throw ConflictException('Step is not pending: ${step['status']}');
  }

  // Check permission
  final entityType = step['entity_type'] as String;
  await PermissionChecker(supabase).require(
    auth.employeeId,
    '${entityType}.approve',
    jwtPermissions: auth.permissions,
  );

  final now = DateTime.now().toUtc();

  // Update step status to 'returned'
  await supabase.from('approval_steps').update({
    'status': 'returned',
    'return_reason': reason,
    'returned_by': auth.employeeId,
    'returned_at': now.toIso8601String(),
  }).eq('id', id);

  // Get entity table and update status
  final tableMap = {
    'document': 'documents',
    'course': 'courses',
    'training_plan': 'training_plans',
    'gtp': 'training_plans',
    'question_paper': 'question_papers',
    'curriculum': 'curricula',
    'trainer': 'trainers',
    'schedule': 'training_schedules',
  };
  final tableName = tableMap[entityType];
  
  if (tableName != null) {
    await supabase.from(tableName).update({
      'status': 'RETURNED',
      'updated_at': now.toIso8601String(),
    }).eq('id', step['entity_id']);
  }

  // Create return record for tracking
  await supabase.from('approval_returns').insert({
    'approval_step_id': id,
    'entity_type': entityType,
    'entity_id': step['entity_id'],
    'returned_by': auth.employeeId,
    'return_reason': reason,
    'requested_corrections': corrections != null 
        ? jsonEncode(corrections) 
        : null,
    'organization_id': auth.orgId,
    'created_at': now.toIso8601String(),
  });

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': entityType,
    'entity_id': step['entity_id'],
    'action': 'APPROVAL_RETURNED',
    'event_category': 'WORKFLOW',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'step_id': id,
      'step_name': step['step_name'],
      'reason': reason,
      'corrections': corrections,
    }),
  });

  // Publish event for notification to submitter
  await EventPublisher.publish(
    supabase,
    eventType: '$entityType.returned',
    aggregateType: entityType,
    aggregateId: step['entity_id'] as String,
    orgId: auth.orgId,
    payload: {
      'step_id': id,
      'step_name': step['step_name'],
      'returned_by': auth.employeeId,
      'reason': reason,
      'corrections': corrections,
    },
  );

  return ApiResponse.ok({
    'message': 'Approval returned for corrections',
    'step_id': id,
    'entity_type': entityType,
    'entity_id': step['entity_id'],
    'status': 'returned',
  }).toResponse();
}
