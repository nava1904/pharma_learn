import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/retraining
///
/// Creates a retraining assignment for an employee.
/// Body: { employee_id, course_id, reason, original_assignment_id?, due_date }
Future<Response> retrainingCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to create retraining assignments');
  }

  final employeeId = requireUuid(body, 'employee_id');
  final courseId = requireUuid(body, 'course_id');
  final reason = requireString(body, 'reason');
  final originalAssignmentId = body['original_assignment_id'] as String?;
  final dueDateStr = body['due_date'] as String?;
  final notes = body['notes'] as String?;

  // Validate reason
  final validReasons = ['assessment_fail', 'competency_lapse', 'capa', 'periodic', 'sop_update', 'manual'];
  if (!validReasons.contains(reason)) {
    throw ValidationException({
      'reason': 'Must be one of: ${validReasons.join(', ')}',
    });
  }

  // Verify employee exists
  final employee = await supabase
      .from('employees')
      .select('id, organization_id')
      .eq('id', employeeId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  // Verify course exists
  final course = await supabase
      .from('courses')
      .select('id, title, organization_id')
      .eq('id', courseId)
      .maybeSingle();

  if (course == null) {
    throw NotFoundException('Course not found');
  }

  // Parse due date or default to 30 days from now
  DateTime dueDate = DateTime.now().add(const Duration(days: 30));
  if (dueDateStr != null) {
    dueDate = DateTime.tryParse(dueDateStr) ?? dueDate;
  }

  // Check if there's already an active retraining for same employee+course
  final existingRetraining = await supabase
      .from('training_retraining_requests')
      .select('id, status')
      .eq('employee_id', employeeId)
      .eq('course_id', courseId)
      .inFilter('status', ['pending', 'in_progress'])
      .maybeSingle();

  if (existingRetraining != null) {
    throw ConflictException('Employee already has an active retraining assignment for this course');
  }

  // Create retraining request record
  final retraining = await supabase
      .from('training_retraining_requests')
      .insert({
        'employee_id': employeeId,
        'course_id': courseId,
        'reason': reason,
        'original_assignment_id': originalAssignmentId,
        'due_date': dueDate.toIso8601String().split('T')[0],
        'notes': notes,
        'status': 'pending',
        'requested_by': auth.employeeId,
        'requested_at': DateTime.now().toUtc().toIso8601String(),
        'organization_id': auth.orgId,
      })
      .select()
      .single();

  // Create the actual training assignment
  final assignment = await supabase
      .from('employee_training_obligations')
      .insert({
        'employee_id': employeeId,
        'course_id': courseId,
        'due_date': dueDate.toIso8601String().split('T')[0],
        'status': 'assigned',
        'assignment_type': 'retraining',
        'retraining_request_id': retraining['id'],
        'assigned_by': auth.employeeId,
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
        'organization_id': auth.orgId,
      })
      .select()
      .single();

  // Update retraining record with assignment ID
  await supabase
      .from('training_retraining_requests')
      .update({
        'assignment_id': assignment['id'],
        'status': 'in_progress',
      })
      .eq('id', retraining['id']);

  await OutboxService(supabase).publish(
    aggregateType: 'retraining',
    aggregateId: retraining['id'] as String,
    eventType: 'retraining.created',
    payload: {
      'employee_id': employeeId,
      'course_id': courseId,
      'reason': reason,
      'due_date': dueDate.toIso8601String(),
    },
  );

  // Notify employee
  await supabase.functions.invoke('send-notification', body: {
    'employee_id': employeeId,
    'template_key': 'retraining_assigned',
    'data': {
      'course_name': course['title'],
      'reason': reason,
      'due_date': dueDate.toIso8601String(),
    },
  });

  return ApiResponse.created({
    'retraining': retraining,
    'assignment': assignment,
    'course': course,
  }).toResponse();
}

/// GET /v1/train/retraining
///
/// Lists retraining assignments (coordinator view).
/// Query params: page, per_page, employee_id, course_id, reason, status
Future<Response> retrainingListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view retraining assignments');
  }

  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;
  final employeeIdFilter = params['employee_id'];
  final courseIdFilter = params['course_id'];
  final reasonFilter = params['reason'];
  final statusFilter = params['status'];

  var query = supabase
      .from('training_retraining_requests')
      .select('''
        id, reason, due_date, status, notes, requested_at, completed_at,
        employee:employees!training_retraining_requests_employee_id_fkey(
          id, first_name, last_name, department_id,
          departments(id, name)
        ),
        course:courses(
          id, title, course_code
        ),
        requested_by_employee:employees!training_retraining_requests_requested_by_fkey(
          id, first_name, last_name
        ),
        original_assignment:employee_training_obligations(
          id, completed_at
        )
      ''')
      .eq('organization_id', auth.orgId);

  if (employeeIdFilter != null) {
    query = query.eq('employee_id', employeeIdFilter);
  }
  if (courseIdFilter != null) {
    query = query.eq('course_id', courseIdFilter);
  }
  if (reasonFilter != null) {
    query = query.eq('reason', reasonFilter);
  }
  if (statusFilter != null) {
    query = query.eq('status', statusFilter);
  }

  final results = await query
      .order('requested_at', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  // Get counts by status
  final countQuery = await supabase
      .from('training_retraining_requests')
      .select('status')
      .eq('organization_id', auth.orgId);

  final statusCounts = <String, int>{};
  for (final r in countQuery as List) {
    final status = r['status'] as String? ?? 'unknown';
    statusCounts[status] = (statusCounts[status] ?? 0) + 1;
  }

  return ApiResponse.ok({
    'retraining_requests': results,
    'pagination': {
      'page': page,
      'per_page': perPage,
    },
    'summary': statusCounts,
  }).toResponse();
}

/// GET /v1/train/retraining/:id
///
/// Gets retraining assignment detail.
Future<Response> retrainingGetHandler(Request req) async {
  final retrainingId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (retrainingId == null || retrainingId.isEmpty) {
    throw ValidationException({'id': 'Retraining ID is required'});
  }

  final retraining = await supabase
      .from('training_retraining_requests')
      .select('''
        id, reason, due_date, status, notes, requested_at, completed_at,
        employee:employees!training_retraining_requests_employee_id_fkey(
          id, first_name, last_name, email, department_id
        ),
        course:courses(
          id, title, course_code, description
        ),
        requested_by_employee:employees!training_retraining_requests_requested_by_fkey(
          id, first_name, last_name
        ),
        original_assignment:employee_training_obligations!training_retraining_requests_original_assignment_id_fkey(
          id, completed_at, assessment_score
        ),
        current_assignment:employee_training_obligations!training_retraining_requests_assignment_id_fkey(
          id, status, due_date, completed_at
        )
      ''')
      .eq('id', retrainingId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (retraining == null) {
    throw NotFoundException('Retraining request not found');
  }

  // Check access
  final isEmployee = retraining['employee']?['id'] == auth.employeeId;
  if (!isEmployee && !auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have access to this retraining record');
  }

  return ApiResponse.ok(retraining).toResponse();
}

/// POST /v1/train/retraining/:id/cancel
///
/// Coordinator cancels a pending retraining assignment.
/// Body: { reason }
Future<Response> retrainingCancelHandler(Request req) async {
  final retrainingId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to cancel retraining');
  }

  if (retrainingId == null || retrainingId.isEmpty) {
    throw ValidationException({'id': 'Retraining ID is required'});
  }

  final reason = requireString(body, 'reason');

  final retraining = await supabase
      .from('training_retraining_requests')
      .select('id, status, assignment_id')
      .eq('id', retrainingId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (retraining == null) {
    throw NotFoundException('Retraining request not found');
  }

  if (retraining['status'] == 'completed') {
    throw ConflictException('Cannot cancel completed retraining');
  }

  // Update retraining status
  await supabase
      .from('training_retraining_requests')
      .update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_by': auth.employeeId,
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', retrainingId);

  // Cancel the associated assignment
  if (retraining['assignment_id'] != null) {
    await supabase
        .from('employee_training_obligations')
        .update({
          'status': 'cancelled',
          'cancellation_reason': reason,
        })
        .eq('id', retraining['assignment_id']);
  }

  await OutboxService(supabase).publish(
    aggregateType: 'retraining',
    aggregateId: retrainingId,
    eventType: 'retraining.cancelled',
    payload: {
      'reason': reason,
      'cancelled_by': auth.employeeId,
    },
  );

  return ApiResponse.ok({'message': 'Retraining cancelled'}).toResponse();
}
