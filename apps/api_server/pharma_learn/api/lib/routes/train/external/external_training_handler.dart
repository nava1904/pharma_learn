import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/external-training
///
/// Employee or coordinator submits an external training record.
/// Body: { employee_id?, course_name, institution_name, completion_date, 
///         certificate_attachment_id?, training_hours, training_type }
Future<Response> externalTrainingCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Employee can submit for self, coordinator can submit for anyone
  final employeeId = body['employee_id'] as String? ?? auth.employeeId;
  
  if (employeeId != auth.employeeId && !auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You can only submit external training records for yourself');
  }

  final courseName = requireString(body, 'course_name');
  final institutionName = requireString(body, 'institution_name');
  final completionDateStr = requireString(body, 'completion_date');
  final trainingHours = body['training_hours'] as num?;
  final trainingType = body['training_type'] as String? ?? 'external';
  final certificateAttachmentId = body['certificate_attachment_id'] as String?;
  final description = body['description'] as String?;
  final skillsAcquired = body['skills_acquired'] as List? ?? [];

  // Validate completion date
  final completionDate = DateTime.tryParse(completionDateStr);
  if (completionDate == null) {
    throw ValidationException({
      'completion_date': 'Invalid date format. Use ISO 8601 (YYYY-MM-DD)',
    });
  }

  // Cannot be in the future
  if (completionDate.isAfter(DateTime.now())) {
    throw ValidationException({
      'completion_date': 'Completion date cannot be in the future',
    });
  }

  // Validate training type
  final validTypes = ['external', 'conference', 'workshop', 'certification', 'webinar', 'self_study'];
  if (!validTypes.contains(trainingType)) {
    throw ValidationException({
      'training_type': 'Must be one of: ${validTypes.join(', ')}',
    });
  }

  // Insert record
  final record = await supabase
      .from('external_training_records')
      .insert({
        'employee_id': employeeId,
        'organization_id': auth.orgId,
        'course_name': courseName,
        'institution_name': institutionName,
        'completion_date': completionDate.toIso8601String().split('T')[0],
        'training_hours': trainingHours,
        'training_type': trainingType,
        'certificate_attachment_id': certificateAttachmentId,
        'description': description,
        'skills_acquired': skillsAcquired,
        'status': 'pending_approval',
        'submitted_by': auth.employeeId,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'external_training',
    aggregateId: record['id'] as String,
    eventType: 'external_training.submitted',
    payload: {
      'employee_id': employeeId,
      'course_name': courseName,
      'institution_name': institutionName,
    },
  );

  return ApiResponse.created(record).toResponse();
}

/// GET /v1/train/external-training
///
/// Lists external training records.
/// Query params: page, per_page, employee_id, status, from_date, to_date
Future<Response> externalTrainingListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;
  final employeeIdFilter = params['employee_id'];
  final statusFilter = params['status'];
  final fromDate = params['from_date'];
  final toDate = params['to_date'];

  var query = supabase
      .from('external_training_records')
      .select('''
        id, course_name, institution_name, completion_date, training_hours,
        training_type, status, submitted_at, approved_at,
        employee:employees!external_training_records_employee_id_fkey(
          id, first_name, last_name, department_id
        ),
        submitted_by_employee:employees!external_training_records_submitted_by_fkey(
          id, first_name, last_name
        ),
        approved_by_employee:employees!external_training_records_approved_by_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('organization_id', auth.orgId);

  // Non-coordinators can only see their own records
  if (!auth.hasPermission(Permissions.manageTraining)) {
    query = query.eq('employee_id', auth.employeeId);
  } else if (employeeIdFilter != null) {
    query = query.eq('employee_id', employeeIdFilter);
  }

  if (statusFilter != null) {
    query = query.eq('status', statusFilter);
  }

  if (fromDate != null) {
    query = query.gte('completion_date', fromDate);
  }

  if (toDate != null) {
    query = query.lte('completion_date', toDate);
  }

  final results = await query
      .order('submitted_at', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  // Get total count
  var countQuery = supabase
      .from('external_training_records')
      .select('id')
      .eq('organization_id', auth.orgId);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    countQuery = countQuery.eq('employee_id', auth.employeeId);
  }

  final countResult = await countQuery;
  final total = (countResult as List).length;

  return ApiResponse.ok({
    'external_training_records': results,
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': total,
      'total_pages': (total / perPage).ceil(),
    },
  }).toResponse();
}

/// GET /v1/train/external-training/:id
///
/// Gets a specific external training record.
Future<Response> externalTrainingGetHandler(Request req) async {
  final recordId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (recordId == null || recordId.isEmpty) {
    throw ValidationException({'id': 'Record ID is required'});
  }

  final record = await supabase
      .from('external_training_records')
      .select('''
        id, course_name, institution_name, completion_date, training_hours,
        training_type, description, skills_acquired, certificate_attachment_id,
        status, submitted_at, approved_at, rejection_reason,
        employee:employees!external_training_records_employee_id_fkey(
          id, first_name, last_name, email, department_id
        ),
        submitted_by_employee:employees!external_training_records_submitted_by_fkey(
          id, first_name, last_name
        ),
        approved_by_employee:employees!external_training_records_approved_by_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('id', recordId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (record == null) {
    throw NotFoundException('External training record not found');
  }

  // Check access
  if (record['employee']?['id'] != auth.employeeId && 
      !auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have access to this record');
  }

  return ApiResponse.ok(record).toResponse();
}

/// PATCH /v1/train/external-training/:id
///
/// Updates an external training record (before approval).
Future<Response> externalTrainingPatchHandler(Request req) async {
  final recordId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (recordId == null || recordId.isEmpty) {
    throw ValidationException({'id': 'Record ID is required'});
  }

  // Get existing record
  final existing = await supabase
      .from('external_training_records')
      .select('id, employee_id, status')
      .eq('id', recordId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('External training record not found');
  }

  // Check access - only submitter/employee can update, and only if pending
  if (existing['employee_id'] != auth.employeeId && 
      !auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to update this record');
  }

  if (existing['status'] != 'pending_approval') {
    throw ConflictException('Cannot update record after it has been approved or rejected');
  }

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  if (body.containsKey('course_name')) {
    updates['course_name'] = requireString(body, 'course_name');
  }
  if (body.containsKey('institution_name')) {
    updates['institution_name'] = requireString(body, 'institution_name');
  }
  if (body.containsKey('completion_date')) {
    updates['completion_date'] = body['completion_date'];
  }
  if (body.containsKey('training_hours')) {
    updates['training_hours'] = body['training_hours'];
  }
  if (body.containsKey('description')) {
    updates['description'] = body['description'];
  }
  if (body.containsKey('skills_acquired')) {
    updates['skills_acquired'] = body['skills_acquired'];
  }
  if (body.containsKey('certificate_attachment_id')) {
    updates['certificate_attachment_id'] = body['certificate_attachment_id'];
  }

  final result = await supabase
      .from('external_training_records')
      .update(updates)
      .eq('id', recordId)
      .select()
      .single();

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/external-training/:id/approve
///
/// Coordinator approves external training record.
/// Body: { esig: { reauth_session_id, meaning }, create_training_record?: true }
Future<Response> externalTrainingApproveHandler(Request req) async {
  final recordId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to approve external training');
  }

  if (recordId == null || recordId.isEmpty) {
    throw ValidationException({'id': 'Record ID is required'});
  }

  // Get the record
  final record = await supabase
      .from('external_training_records')
      .select('id, employee_id, status, course_name, completion_date, training_hours')
      .eq('id', recordId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (record == null) {
    throw NotFoundException('External training record not found');
  }

  if (record['status'] != 'pending_approval') {
    throw ConflictException('Record has already been processed');
  }

  // Validate e-signature
  final esig = body['esig'] as Map<String, dynamic>?;
  if (esig == null) {
    throw ValidationException({'esig': 'E-signature is required for approval'});
  }

  final esigService = EsigService(supabase);
  final esigId = await esigService.createEsignature(
    employeeId: auth.employeeId,
    meaning: esig['meaning'] as String? ?? 'APPROVE_EXTERNAL_TRAINING',
    entityType: 'external_training_record',
    entityId: recordId,
    reauthSessionId: esig['reauth_session_id'] as String,
  );

  // Update record
  await supabase
      .from('external_training_records')
      .update({
        'status': 'approved',
        'approved_by': auth.employeeId,
        'approved_at': DateTime.now().toUtc().toIso8601String(),
        'esignature_id': esigId,
      })
      .eq('id', recordId);

  // Optionally create a training_record
  final createTrainingRecord = body['create_training_record'] as bool? ?? true;
  String? trainingRecordId;

  if (createTrainingRecord) {
    final trainingRecord = await supabase
        .from('training_records')
        .insert({
          'employee_id': record['employee_id'],
          'organization_id': auth.orgId,
          'training_type': 'external',
          'external_training_id': recordId,
          'course_name': record['course_name'],
          'completed_at': record['completion_date'],
          'training_hours': record['training_hours'],
          'overall_status': 'completed',
          'recorded_by': auth.employeeId,
          'recorded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    trainingRecordId = trainingRecord['id'] as String;
  }

  await OutboxService(supabase).publish(
    aggregateType: 'external_training',
    aggregateId: recordId,
    eventType: 'external_training.approved',
    payload: {
      'approved_by': auth.employeeId,
      'training_record_id': trainingRecordId,
    },
  );

  return ApiResponse.ok({
    'message': 'External training approved',
    'training_record_id': trainingRecordId,
  }).toResponse();
}

/// POST /v1/train/external-training/:id/reject
///
/// Coordinator rejects external training record.
/// Body: { reason }
Future<Response> externalTrainingRejectHandler(Request req) async {
  final recordId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to reject external training');
  }

  if (recordId == null || recordId.isEmpty) {
    throw ValidationException({'id': 'Record ID is required'});
  }

  final reason = requireString(body, 'reason');

  // Get the record
  final record = await supabase
      .from('external_training_records')
      .select('id, status')
      .eq('id', recordId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (record == null) {
    throw NotFoundException('External training record not found');
  }

  if (record['status'] != 'pending_approval') {
    throw ConflictException('Record has already been processed');
  }

  await supabase
      .from('external_training_records')
      .update({
        'status': 'rejected',
        'rejection_reason': reason,
        'rejected_by': auth.employeeId,
        'rejected_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', recordId);

  await OutboxService(supabase).publish(
    aggregateType: 'external_training',
    aggregateId: recordId,
    eventType: 'external_training.rejected',
    payload: {
      'rejected_by': auth.employeeId,
      'reason': reason,
    },
  );

  return ApiResponse.ok({'message': 'External training rejected'}).toResponse();
}
