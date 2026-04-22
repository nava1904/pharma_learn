import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/schedules/:id/submit
///
/// Submits a schedule for approval.
/// Transitions status from 'draft' to 'pending_approval'.
Future<Response> scheduleSubmitHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to submit schedules');
  }

  final schedule = await supabase
      .from('training_schedules')
      .select('id, status, course_id, trainer_id, venue_id, scheduled_date')
      .eq('id', scheduleId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Schedule not found');
  }

  if (schedule['status'] != 'draft') {
    throw ConflictException('Only draft schedules can be submitted');
  }

  // Validate required fields before submission
  final errors = <String, String>{};
  if (schedule['course_id'] == null) errors['course_id'] = 'Course is required';
  if (schedule['trainer_id'] == null) errors['trainer_id'] = 'Trainer is required';
  if (schedule['scheduled_date'] == null) errors['scheduled_date'] = 'Scheduled date is required';
  
  if (errors.isNotEmpty) {
    throw ValidationException(errors);
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('training_schedules')
      .update({
        'status': 'pending_approval',
        'submitted_by': auth.employeeId,
        'submitted_at': now,
        'updated_at': now,
      })
      .eq('id', scheduleId);

  // Create approval workflow entry
  await supabase.from('approval_workflows').insert({
    'entity_type': 'training_schedule',
    'entity_id': scheduleId,
    'status': 'pending',
    'submitted_by': auth.employeeId,
    'created_at': now,
  });

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedule',
    'entity_id': scheduleId,
    'action': 'submit',
    'employee_id': auth.employeeId,
    'old_values': {'status': 'draft'},
    'new_values': {'status': 'pending_approval'},
    'created_at': now,
  });

  return ApiResponse.ok({'message': 'Schedule submitted for approval'}).toResponse();
}

/// POST /v1/train/schedules/:id/approve [esig]
///
/// Approves a schedule. Requires e-signature.
/// Transitions status from 'pending_approval' to 'approved'.
Future<Response> scheduleApproveHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);
  final esignatureId = body['esignature_id'] as String?;

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageApprovals)) {
    throw PermissionDeniedException('You do not have permission to approve schedules');
  }

  final schedule = await supabase
      .from('training_schedules')
      .select('id, status')
      .eq('id', scheduleId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Schedule not found');
  }

  if (schedule['status'] != 'pending_approval') {
    throw ConflictException('Only pending schedules can be approved');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('training_schedules')
      .update({
        'status': 'approved',
        'approved_by': auth.employeeId,
        'approved_at': now,
        'approval_esignature_id': esignatureId,
        'updated_at': now,
      })
      .eq('id', scheduleId);

  // Update approval workflow
  await supabase
      .from('approval_workflows')
      .update({
        'status': 'approved',
        'approved_by': auth.employeeId,
        'approved_at': now,
        'esignature_id': esignatureId,
      })
      .eq('entity_type', 'training_schedule')
      .eq('entity_id', scheduleId)
      .eq('status', 'pending');

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedule',
    'entity_id': scheduleId,
    'action': 'approve',
    'employee_id': auth.employeeId,
    'esignature_id': esignatureId,
    'old_values': {'status': 'pending_approval'},
    'new_values': {'status': 'approved'},
    'created_at': now,
  });

  return ApiResponse.ok({'message': 'Schedule approved'}).toResponse();
}

/// POST /v1/train/schedules/:id/reject [esig]
///
/// Rejects a schedule. Requires e-signature.
/// Transitions status from 'pending_approval' to 'rejected'.
Future<Response> scheduleRejectHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);
  final reason = body['reason'] as String?;
  final esignatureId = body['esignature_id'] as String?;

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageApprovals)) {
    throw PermissionDeniedException('You do not have permission to reject schedules');
  }

  final schedule = await supabase
      .from('training_schedules')
      .select('id, status')
      .eq('id', scheduleId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Schedule not found');
  }

  if (schedule['status'] != 'pending_approval') {
    throw ConflictException('Only pending schedules can be rejected');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('training_schedules')
      .update({
        'status': 'rejected',
        'rejected_by': auth.employeeId,
        'rejected_at': now,
        'rejection_reason': reason,
        'rejection_esignature_id': esignatureId,
        'updated_at': now,
      })
      .eq('id', scheduleId);

  // Update approval workflow
  await supabase
      .from('approval_workflows')
      .update({
        'status': 'rejected',
        'rejected_by': auth.employeeId,
        'rejected_at': now,
        'rejection_reason': reason,
        'esignature_id': esignatureId,
      })
      .eq('entity_type', 'training_schedule')
      .eq('entity_id', scheduleId)
      .eq('status', 'pending');

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedule',
    'entity_id': scheduleId,
    'action': 'reject',
    'employee_id': auth.employeeId,
    'esignature_id': esignatureId,
    'old_values': {'status': 'pending_approval'},
    'new_values': {'status': 'rejected', 'reason': reason},
    'created_at': now,
  });

  return ApiResponse.ok({'message': 'Schedule rejected'}).toResponse();
}
