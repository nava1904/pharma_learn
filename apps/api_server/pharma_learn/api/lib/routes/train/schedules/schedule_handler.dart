import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/schedules/:id - Get schedule by ID
Future<Response> scheduleGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('training_schedules')
      .select('''
        *,
        course:courses(id, code, name, course_type),
        trainer:trainers(id, employee:employees(id, full_name)),
        venue:venues(id, name, location),
        training_sessions(*)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Schedule not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/train/schedules/:id - Update schedule
Future<Response> scheduleUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'schedules.update',
    jwtPermissions: auth.permissions,
  );

  // Check if schedule is in draft status
  final existing = await supabase
      .from('training_schedules')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Schedule not found').toResponse();
  }

  if (existing['status'] != 'draft') {
    return ErrorResponse.conflict('Only draft schedules can be edited').toResponse();
  }

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final updateData = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'updated_by': auth.employeeId,
  };

  if (body['name'] != null) updateData['name'] = body['name'];
  if (body['description'] != null) updateData['description'] = body['description'];
  if (body['start_date'] != null) updateData['start_date'] = body['start_date'];
  if (body['end_date'] != null) updateData['end_date'] = body['end_date'];
  if (body['trainer_id'] != null) updateData['trainer_id'] = body['trainer_id'];
  if (body['venue_id'] != null) updateData['venue_id'] = body['venue_id'];
  if (body['max_participants'] != null) updateData['max_participants'] = body['max_participants'];

  final result = await supabase
      .from('training_schedules')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedules',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/schedules/:id/submit - Submit schedule for approval
Future<Response> scheduleSubmitHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'schedules.submit',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('training_schedules')
      .select('id, status, name')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Schedule not found').toResponse();
  }

  if (existing['status'] != 'draft') {
    return ErrorResponse.conflict('Only draft schedules can be submitted').toResponse();
  }

  final result = await supabase
      .from('training_schedules')
      .update({
        'status': 'pending_approval',
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
        'submitted_by': auth.employeeId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  // Create approval request
  await supabase.from('approval_requests').insert({
    'entity_type': 'training_schedules',
    'entity_id': id,
    'requested_by': auth.employeeId,
    'status': 'pending',
    'org_id': auth.orgId,
  });

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedules',
    'entity_id': id,
    'action': 'SUBMIT',
    'performed_by': auth.employeeId,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/schedules/:id/approve - Approve schedule [esig]
Future<Response> scheduleApproveHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to approve schedule').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'schedules.approve',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('training_schedules')
      .select('id, status, name')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Schedule not found').toResponse();
  }

  if (existing['status'] != 'pending_approval') {
    return ErrorResponse.conflict('Schedule is not pending approval').toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'training_schedules',
    'entity_id': id,
    'meaning': 'APPROVE',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  final result = await supabase
      .from('training_schedules')
      .update({
        'status': 'approved',
        'approved_at': DateTime.now().toUtc().toIso8601String(),
        'approved_by': auth.employeeId,
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedules',
    'entity_id': id,
    'action': 'APPROVE',
    'performed_by': auth.employeeId,
    'changes': {'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/schedules/:id/assign - Bulk assign employees (TNI)
/// Reference: Alfa §4.2.1.25 — Training Needs Identification
Future<Response> scheduleAssignHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'schedules.assign',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('training_schedules')
      .select('id, status, course_id')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Schedule not found').toResponse();
  }

  if (existing['status'] != 'approved') {
    return ErrorResponse.conflict('Can only assign to approved schedules').toResponse();
  }

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;
  final employeeIds = (body['employee_ids'] as List?)?.cast<String>() ?? [];
  final dueDate = body['due_date'] as String?;

  if (employeeIds.isEmpty) {
    return ErrorResponse.validation({'employee_ids': 'employee_ids is required'}).toResponse();
  }

  // Create employee_assignments for each employee
  final assignments = employeeIds.map((empId) => {
    'employee_id': empId,
    'course_id': existing['course_id'],
    'schedule_id': id,
    'due_date': dueDate,
    'status': 'pending',
    'assigned_by': auth.employeeId,
    'org_id': auth.orgId,
  }).toList();

  await supabase.from('employee_assignments').upsert(
    assignments,
    onConflict: 'employee_id,course_id,schedule_id',
    ignoreDuplicates: true,
  );

  // Publish event for notifications
  await OutboxService(supabase).publish(
    aggregateType: 'training_schedules',
    aggregateId: id,
    eventType: 'training.assigned',
    payload: {
      'schedule_id': id,
      'employee_ids': employeeIds,
      'assigned_by': auth.employeeId,
    },
    orgId: auth.orgId,
  );

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedules',
    'entity_id': id,
    'action': 'BULK_ASSIGN',
    'performed_by': auth.employeeId,
    'changes': {'employee_count': employeeIds.length},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok({
    'schedule_id': id,
    'assigned_count': employeeIds.length,
  }).toResponse();
}

/// GET /v1/train/schedules/:id/sessions - List sessions for schedule
Future<Response> scheduleSessionsListHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;

  final result = await supabase
      .from('training_sessions')
      .select('*, session_attendance(count)')
      .eq('schedule_id', id)
      .order('session_date');

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/schedules/:id/sessions - Create session for schedule
Future<Response> scheduleSessionsCreateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sessions.create',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final errors = <String, String>{};
  if (body['session_date'] == null) {
    errors['session_date'] = 'session_date is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  final result = await supabase.from('training_sessions').insert({
    'schedule_id': id,
    'session_date': body['session_date'],
    'start_time': body['start_time'],
    'end_time': body['end_time'],
    'venue_id': body['venue_id'],
    'trainer_id': body['trainer_id'],
    'status': 'scheduled',
    'org_id': auth.orgId,
    'created_by': auth.employeeId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_sessions',
    'entity_id': result['id'],
    'action': 'CREATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}
