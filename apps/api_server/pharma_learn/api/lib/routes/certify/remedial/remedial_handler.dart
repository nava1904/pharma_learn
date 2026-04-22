import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/certify/remedial
///
/// Lists remedial training assignments.
/// Query params:
/// - employee_id: filter by employee
/// - status: pending|in_progress|completed
/// - trigger: failed_assessment|compliance_gap|manual
Future<Response> remedialListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view remedial training');
  }

  final params = req.url.queryParameters;
  final employeeId = params['employee_id'];
  final status = params['status'];
  final trigger = params['trigger'];

  var query = supabase
      .from('remedial_training')
      .select('''
        id, status, trigger_type, trigger_id, reason, due_date, completed_at,
        employees(id, employee_number, first_name, last_name),
        courses(id, name, course_code),
        assigned_by:employees!assigned_by(id, first_name, last_name)
      ''');

  if (employeeId != null) query = query.eq('employee_id', employeeId);
  if (status != null) query = query.eq('status', status);
  if (trigger != null) query = query.eq('trigger_type', trigger);

  final remedials = await query.order('created_at', ascending: false);

  return ApiResponse.ok(remedials).toResponse();
}

/// GET /v1/certify/remedial/my
///
/// Gets the current user's remedial training assignments.
Future<Response> remedialMyHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final remedials = await supabase
      .from('remedial_training')
      .select('''
        id, status, trigger_type, reason, due_date, created_at,
        courses(id, name, course_code, description, duration_hours)
      ''')
      .eq('employee_id', auth.employeeId)
      .inFilter('status', ['pending', 'in_progress'])
      .order('due_date', ascending: true);

  return ApiResponse.ok(remedials).toResponse();
}

/// POST /v1/certify/remedial
///
/// Creates a remedial training assignment.
/// Body: {
///   employee_id: string,
///   course_id: string,
///   trigger_type: 'failed_assessment' | 'compliance_gap' | 'competency_gap' | 'manual',
///   trigger_id?: string,   // ID of the triggering event (e.g., failed assessment)
///   reason: string,
///   due_date: date,
///   priority?: 'low' | 'medium' | 'high' | 'critical'
/// }
Future<Response> remedialCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to create remedial training');
  }

  final employeeId = requireUuid(body, 'employee_id');
  final courseId = requireUuid(body, 'course_id');
  final triggerType = requireString(body, 'trigger_type');
  final reason = requireString(body, 'reason');
  final dueDate = requireString(body, 'due_date');

  // Validate trigger type
  final validTriggers = ['failed_assessment', 'compliance_gap', 'competency_gap', 'manual'];
  if (!validTriggers.contains(triggerType)) {
    throw ValidationException({
      'trigger_type': 'Invalid trigger type. Must be one of: ${validTriggers.join(', ')}'
    });
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Check for existing pending remedial for same course
  final existing = await supabase
      .from('remedial_training')
      .select('id')
      .eq('employee_id', employeeId)
      .eq('course_id', courseId)
      .inFilter('status', ['pending', 'in_progress'])
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Employee already has pending remedial training for this course');
  }

  final remedial = await supabase
      .from('remedial_training')
      .insert({
        'employee_id': employeeId,
        'course_id': courseId,
        'trigger_type': triggerType,
        'trigger_id': body['trigger_id'],
        'reason': reason,
        'due_date': dueDate,
        'priority': body['priority'] ?? 'medium',
        'status': 'pending',
        'assigned_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  // Create notification for employee
  await supabase.from('notifications').insert({
    'employee_id': employeeId,
    'type': 'remedial_training_assigned',
    'title': 'Remedial Training Assigned',
    'message': 'You have been assigned remedial training: $reason',
    'entity_type': 'remedial_training',
    'entity_id': remedial['id'],
    'priority': body['priority'] ?? 'medium',
    'created_at': now,
  });

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'remedial_training',
    'entity_id': remedial['id'],
    'action': 'create',
    'employee_id': auth.employeeId,
    'new_values': {
      'employee_id': employeeId,
      'course_id': courseId,
      'trigger_type': triggerType,
      'reason': reason,
    },
    'created_at': now,
  });

  return ApiResponse.created(remedial).toResponse();
}

/// GET /v1/certify/remedial/:id
///
/// Gets a specific remedial training assignment.
Future<Response> remedialGetHandler(Request req) async {
  final remedialId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (remedialId == null || remedialId.isEmpty) {
    throw ValidationException({'id': 'Remedial ID is required'});
  }

  final remedial = await supabase
      .from('remedial_training')
      .select('''
        *,
        employees(id, employee_number, first_name, last_name, email),
        courses(id, name, course_code, description, duration_hours),
        assigned_by:employees!assigned_by(id, first_name, last_name),
        completed_by:employees!completed_by(id, first_name, last_name)
      ''')
      .eq('id', remedialId)
      .maybeSingle();

  if (remedial == null) {
    throw NotFoundException('Remedial training not found');
  }

  // Verify access - either the employee or someone with permission
  if (remedial['employee_id'] != auth.employeeId &&
      !auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view this remedial training');
  }

  return ApiResponse.ok(remedial).toResponse();
}

/// POST /v1/certify/remedial/:id/start
///
/// Marks remedial training as started.
Future<Response> remedialStartHandler(Request req) async {
  final remedialId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (remedialId == null || remedialId.isEmpty) {
    throw ValidationException({'id': 'Remedial ID is required'});
  }

  final remedial = await supabase
      .from('remedial_training')
      .select('id, employee_id, status')
      .eq('id', remedialId)
      .maybeSingle();

  if (remedial == null) {
    throw NotFoundException('Remedial training not found');
  }

  // Only the assigned employee can start
  if (remedial['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('Only the assigned employee can start this training');
  }

  if (remedial['status'] != 'pending') {
    throw ConflictException('Remedial training has already been started');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('remedial_training')
      .update({
        'status': 'in_progress',
        'started_at': now,
        'updated_at': now,
      })
      .eq('id', remedialId);

  return ApiResponse.ok({'message': 'Remedial training started'}).toResponse();
}

/// POST /v1/certify/remedial/:id/complete [esig]
///
/// Marks remedial training as completed. Requires e-signature.
Future<Response> remedialCompleteHandler(Request req) async {
  final remedialId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);
  final esignatureId = body['esignature_id'] as String?;

  if (remedialId == null || remedialId.isEmpty) {
    throw ValidationException({'id': 'Remedial ID is required'});
  }

  final remedial = await supabase
      .from('remedial_training')
      .select('id, employee_id, status, course_id')
      .eq('id', remedialId)
      .maybeSingle();

  if (remedial == null) {
    throw NotFoundException('Remedial training not found');
  }

  // Only the assigned employee can complete
  if (remedial['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('Only the assigned employee can complete this training');
  }

  if (remedial['status'] != 'in_progress') {
    throw ConflictException('Remedial training must be in progress to complete');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('remedial_training')
      .update({
        'status': 'completed',
        'completed_at': now,
        'completed_by': auth.employeeId,
        'completion_esignature_id': esignatureId,
        'updated_at': now,
      })
      .eq('id', remedialId);

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'remedial_training',
    'entity_id': remedialId,
    'action': 'complete',
    'employee_id': auth.employeeId,
    'esignature_id': esignatureId,
    'old_values': {'status': 'in_progress'},
    'new_values': {'status': 'completed'},
    'created_at': now,
  });

  return ApiResponse.ok({'message': 'Remedial training completed'}).toResponse();
}

/// DELETE /v1/certify/remedial/:id
///
/// Cancels a remedial training assignment (admin only).
Future<Response> remedialCancelHandler(Request req) async {
  final remedialId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (remedialId == null || remedialId.isEmpty) {
    throw ValidationException({'id': 'Remedial ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to cancel remedial training');
  }

  final remedial = await supabase
      .from('remedial_training')
      .select('id, status')
      .eq('id', remedialId)
      .maybeSingle();

  if (remedial == null) {
    throw NotFoundException('Remedial training not found');
  }

  if (remedial['status'] == 'completed') {
    throw ConflictException('Cannot cancel completed remedial training');
  }

  final reason = body['reason'] as String? ?? 'Cancelled by administrator';
  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('remedial_training')
      .update({
        'status': 'cancelled',
        'cancelled_at': now,
        'cancelled_by': auth.employeeId,
        'cancellation_reason': reason,
        'updated_at': now,
      })
      .eq('id', remedialId);

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'remedial_training',
    'entity_id': remedialId,
    'action': 'cancel',
    'employee_id': auth.employeeId,
    'old_values': {'status': remedial['status']},
    'new_values': {'status': 'cancelled', 'reason': reason},
    'created_at': now,
  });

  return ApiResponse.noContent().toResponse();
}
