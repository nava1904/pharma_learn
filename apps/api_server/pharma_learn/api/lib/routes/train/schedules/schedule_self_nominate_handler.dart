import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/schedules/:id/self-nominate
///
/// Employee nominates themselves for an open training schedule.
/// Body: { reason? }
Future<Response> scheduleSelfNominateHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  final reason = body['reason'] as String?;

  // Get schedule details
  final schedule = await supabase
      .from('training_schedules')
      .select('''
        id, title, status, max_participants, allow_self_nomination,
        nomination_deadline, organization_id
      ''')
      .eq('id', scheduleId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Training schedule not found');
  }

  if (schedule['organization_id'] != auth.orgId) {
    throw PermissionDeniedException('You do not have access to this schedule');
  }

  // Check if self-nomination is allowed
  if (schedule['allow_self_nomination'] != true) {
    throw ValidationException({
      'schedule': 'Self-nomination is not allowed for this training schedule',
    });
  }

  // Check nomination deadline
  if (schedule['nomination_deadline'] != null) {
    final deadline = DateTime.parse(schedule['nomination_deadline'] as String);
    if (DateTime.now().isAfter(deadline)) {
      throw ValidationException({
        'schedule': 'Nomination deadline has passed',
      });
    }
  }

  // Check if already nominated
  final existingNomination = await supabase
      .from('training_nominations')
      .select('id, status')
      .eq('schedule_id', scheduleId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (existingNomination != null) {
    if (existingNomination['status'] == 'pending' || existingNomination['status'] == 'accepted') {
      throw ConflictException('You have already nominated yourself for this training');
    }
  }

  // Check if already enrolled
  final existingEnrollment = await supabase
      .from('schedule_enrollments')
      .select('id')
      .eq('schedule_id', scheduleId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (existingEnrollment != null) {
    throw ConflictException('You are already enrolled in this training');
  }

  // Check available seats
  final enrollmentCount = await supabase
      .from('schedule_enrollments')
      .select('id')
      .eq('schedule_id', scheduleId);

  final currentEnrollments = (enrollmentCount as List).length;
  final maxParticipants = schedule['max_participants'] as int?;
  final seatsAvailable = maxParticipants == null || currentEnrollments < maxParticipants;

  // Create nomination
  final nomination = await supabase
      .from('training_nominations')
      .insert({
        'schedule_id': scheduleId,
        'employee_id': auth.employeeId,
        'reason': reason,
        'status': 'pending',
        'nominated_at': DateTime.now().toUtc().toIso8601String(),
        'organization_id': auth.orgId,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'training_nomination',
    aggregateId: nomination['id'] as String,
    eventType: 'training_nomination.submitted',
    payload: {
      'schedule_id': scheduleId,
      'employee_id': auth.employeeId,
      'seats_available': seatsAvailable,
    },
  );

  return ApiResponse.created({
    'nomination': nomination,
    'seats_available': seatsAvailable,
    'message': seatsAvailable 
        ? 'Nomination submitted. Awaiting coordinator approval.'
        : 'Nomination submitted (waitlist). Schedule is currently full.',
  }).toResponse();
}

/// DELETE /v1/train/schedules/:id/self-nominate
///
/// Employee withdraws their nomination before acceptance.
Future<Response> scheduleWithdrawNominationHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  // Find existing nomination
  final nomination = await supabase
      .from('training_nominations')
      .select('id, status')
      .eq('schedule_id', scheduleId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (nomination == null) {
    throw NotFoundException('No nomination found for this schedule');
  }

  if (nomination['status'] == 'accepted') {
    throw ConflictException('Cannot withdraw nomination after it has been accepted');
  }

  await supabase
      .from('training_nominations')
      .update({
        'status': 'withdrawn',
        'withdrawn_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', nomination['id']);

  return ApiResponse.ok({'message': 'Nomination withdrawn'}).toResponse();
}

/// GET /v1/train/schedules/:id/nominations
///
/// Coordinator views all nominations for a schedule.
Future<Response> scheduleNominationsListHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to view nominations');
  }

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  final statusFilter = req.url.queryParameters['status'];

  var query = supabase
      .from('training_nominations')
      .select('''
        id, reason, status, nominated_at, processed_at, rejection_reason,
        employee:employees!training_nominations_employee_id_fkey(
          id, first_name, last_name, email, department_id,
          departments(id, name)
        ),
        processed_by_employee:employees!training_nominations_processed_by_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('schedule_id', scheduleId);

  if (statusFilter != null) {
    query = query.eq('status', statusFilter);
  }

  final nominations = await query.order('nominated_at', ascending: true);

  // Get schedule capacity info
  final schedule = await supabase
      .from('training_schedules')
      .select('max_participants')
      .eq('id', scheduleId)
      .single();

  final enrollmentCount = await supabase
      .from('schedule_enrollments')
      .select('id')
      .eq('schedule_id', scheduleId);

  final currentEnrollments = (enrollmentCount as List).length;
  final maxParticipants = schedule['max_participants'] as int?;

  return ApiResponse.ok({
    'schedule_id': scheduleId,
    'nominations': nominations,
    'summary': {
      'total': (nominations as List).length,
      'pending': nominations.where((n) => n['status'] == 'pending').length,
      'accepted': nominations.where((n) => n['status'] == 'accepted').length,
      'rejected': nominations.where((n) => n['status'] == 'rejected').length,
    },
    'capacity': {
      'current_enrollments': currentEnrollments,
      'max_participants': maxParticipants,
      'available_seats': maxParticipants != null ? maxParticipants - currentEnrollments : null,
    },
  }).toResponse();
}

/// POST /v1/train/schedules/:id/nominations/:employeeId/accept
///
/// Coordinator accepts a nomination, creating an enrollment.
Future<Response> scheduleNominationAcceptHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final employeeId = req.rawPathParameters[#employeeId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to accept nominations');
  }

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }
  if (employeeId == null || employeeId.isEmpty) {
    throw ValidationException({'employeeId': 'Employee ID is required'});
  }

  // Find nomination
  final nomination = await supabase
      .from('training_nominations')
      .select('id, status')
      .eq('schedule_id', scheduleId)
      .eq('employee_id', employeeId)
      .eq('status', 'pending')
      .maybeSingle();

  if (nomination == null) {
    throw NotFoundException('Pending nomination not found');
  }

  // Check capacity
  final schedule = await supabase
      .from('training_schedules')
      .select('max_participants')
      .eq('id', scheduleId)
      .single();

  final enrollmentCount = await supabase
      .from('schedule_enrollments')
      .select('id')
      .eq('schedule_id', scheduleId);

  final currentEnrollments = (enrollmentCount as List).length;
  final maxParticipants = schedule['max_participants'] as int?;

  if (maxParticipants != null && currentEnrollments >= maxParticipants) {
    throw ConflictException('Schedule has reached maximum capacity');
  }

  // Update nomination
  await supabase
      .from('training_nominations')
      .update({
        'status': 'accepted',
        'processed_by': auth.employeeId,
        'processed_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', nomination['id']);

  // Create enrollment
  final enrollment = await supabase
      .from('schedule_enrollments')
      .insert({
        'schedule_id': scheduleId,
        'employee_id': employeeId,
        'enrolled_by': auth.employeeId,
        'enrolled_at': DateTime.now().toUtc().toIso8601String(),
        'enrollment_source': 'self_nomination',
        'nomination_id': nomination['id'],
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'training_nomination',
    aggregateId: nomination['id'] as String,
    eventType: 'training_nomination.accepted',
    payload: {
      'schedule_id': scheduleId,
      'employee_id': employeeId,
      'enrollment_id': enrollment['id'],
    },
  );

  return ApiResponse.ok({
    'message': 'Nomination accepted and employee enrolled',
    'enrollment': enrollment,
  }).toResponse();
}

/// POST /v1/train/schedules/:id/nominations/:employeeId/reject
///
/// Coordinator rejects a nomination.
/// Body: { reason }
Future<Response> scheduleNominationRejectHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final employeeId = req.rawPathParameters[#employeeId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to reject nominations');
  }

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }
  if (employeeId == null || employeeId.isEmpty) {
    throw ValidationException({'employeeId': 'Employee ID is required'});
  }

  final reason = requireString(body, 'reason');

  // Find nomination
  final nomination = await supabase
      .from('training_nominations')
      .select('id, status')
      .eq('schedule_id', scheduleId)
      .eq('employee_id', employeeId)
      .eq('status', 'pending')
      .maybeSingle();

  if (nomination == null) {
    throw NotFoundException('Pending nomination not found');
  }

  await supabase
      .from('training_nominations')
      .update({
        'status': 'rejected',
        'rejection_reason': reason,
        'processed_by': auth.employeeId,
        'processed_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', nomination['id']);

  await OutboxService(supabase).publish(
    aggregateType: 'training_nomination',
    aggregateId: nomination['id'] as String,
    eventType: 'training_nomination.rejected',
    payload: {
      'schedule_id': scheduleId,
      'employee_id': employeeId,
      'reason': reason,
    },
  );

  return ApiResponse.ok({'message': 'Nomination rejected'}).toResponse();
}
