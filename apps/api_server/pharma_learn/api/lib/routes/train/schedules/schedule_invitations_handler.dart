import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/schedules/:id/invitations
///
/// Sends training invitations to enrolled employees.
/// Body: {
///   employee_ids?: string[],  // Specific employees, or all if not provided
///   include_calendar?: bool,  // Include calendar invite (ICS)
///   custom_message?: string   // Custom message in invitation
/// }
Future<Response> scheduleInvitationsHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to send invitations');
  }

  final schedule = await supabase
      .from('training_schedules')
      .select('''
        id, title, status, scheduled_date, scheduled_time, duration_hours,
        courses(id, name, course_code),
        venues(id, name, address),
        trainers:trainer_id(id, first_name, last_name)
      ''')
      .eq('id', scheduleId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Schedule not found');
  }

  if (schedule['status'] != 'approved') {
    throw ConflictException('Only approved schedules can have invitations sent');
  }

  // Get enrollments
  var enrollmentQuery = supabase
      .from('schedule_enrollments')
      .select('''
        id, employee_id,
        employees(id, email, first_name, last_name)
      ''')
      .eq('schedule_id', scheduleId)
      .inFilter('status', ['assigned', 'enrolled']);

  final employeeIds = body['employee_ids'] as List<dynamic>?;
  if (employeeIds != null && employeeIds.isNotEmpty) {
    enrollmentQuery = enrollmentQuery.inFilter('employee_id', employeeIds.cast<String>());
  }

  final enrollments = await enrollmentQuery;
  
  if (enrollments.isEmpty) {
    throw ValidationException({'enrollments': 'No eligible enrollments found'});
  }

  final now = DateTime.now().toUtc().toIso8601String();
  final includeCalendar = body['include_calendar'] as bool? ?? true;
  final customMessage = body['custom_message'] as String?;

  // Build course name
  final course = schedule['courses'] as Map<String, dynamic>?;
  final courseName = course?['name'] ?? 'Training Session';
  
  // Build trainer name
  final trainer = schedule['trainers'] as Map<String, dynamic>?;
  final trainerName = trainer != null 
      ? '${trainer['first_name']} ${trainer['last_name']}'
      : 'TBD';
  
  // Build venue
  final venue = schedule['venues'] as Map<String, dynamic>?;
  final venueName = venue?['name'] ?? 'TBD';

  // Create invitation records and notifications
  final invitations = <Map<String, dynamic>>[];
  final notifications = <Map<String, dynamic>>[];

  for (final enrollment in enrollments) {
    final employee = enrollment['employees'] as Map<String, dynamic>?;
    if (employee == null) continue;

    invitations.add({
      'schedule_id': scheduleId,
      'enrollment_id': enrollment['id'],
      'employee_id': enrollment['employee_id'],
      'status': 'sent',
      'sent_at': now,
      'include_calendar': includeCalendar,
      'custom_message': customMessage,
      'created_at': now,
    });

    notifications.add({
      'employee_id': enrollment['employee_id'],
      'type': 'training_invitation',
      'title': 'Training Invitation: $courseName',
      'message': 'You are invited to attend training on ${schedule['scheduled_date']}.\n'
          'Trainer: $trainerName\n'
          'Venue: $venueName'
          '${customMessage != null ? '\n\n$customMessage' : ''}',
      'entity_type': 'training_schedule',
      'entity_id': scheduleId,
      'created_at': now,
    });
  }

  await supabase.from('training_invitations').insert(invitations);
  await supabase.from('notifications').insert(notifications);

  // Update enrollment status to invited
  final enrollmentIds = enrollments.map((e) => e['id']).toList();
  await supabase
      .from('schedule_enrollments')
      .update({
        'invitation_sent_at': now,
        'updated_at': now,
      })
      .inFilter('id', enrollmentIds);

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedule',
    'entity_id': scheduleId,
    'action': 'send_invitations',
    'employee_id': auth.employeeId,
    'new_values': {
      'sent_count': invitations.length,
      'include_calendar': includeCalendar,
    },
    'created_at': now,
  });

  return ApiResponse.ok({
    'message': 'Invitations sent successfully',
    'sent_count': invitations.length,
  }).toResponse();
}

/// GET /v1/train/schedules/:id/invitations
///
/// Lists invitations for a schedule.
Future<Response> scheduleInvitationsListHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to view invitations');
  }

  final invitations = await supabase
      .from('training_invitations')
      .select('''
        id, status, sent_at, responded_at, response,
        employees(id, employee_number, first_name, last_name, email)
      ''')
      .eq('schedule_id', scheduleId)
      .order('sent_at', ascending: false);

  return ApiResponse.ok(invitations).toResponse();
}

/// POST /v1/train/invitations/:id/respond
///
/// Respond to an invitation (accept/decline).
/// Body: { response: 'accepted' | 'declined', reason?: string }
Future<Response> invitationRespondHandler(Request req) async {
  final invitationId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (invitationId == null || invitationId.isEmpty) {
    throw ValidationException({'id': 'Invitation ID is required'});
  }

  final invitation = await supabase
      .from('training_invitations')
      .select('id, employee_id, schedule_id, enrollment_id, status')
      .eq('id', invitationId)
      .maybeSingle();

  if (invitation == null) {
    throw NotFoundException('Invitation not found');
  }

  // Verify the invitation belongs to the current user
  if (invitation['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('You can only respond to your own invitations');
  }

  if (invitation['status'] != 'sent') {
    throw ConflictException('This invitation has already been responded to');
  }

  final response = requireString(body, 'response');
  if (!['accepted', 'declined'].contains(response)) {
    throw ValidationException({
      'response': 'Response must be either "accepted" or "declined"'
    });
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('training_invitations')
      .update({
        'status': response,
        'response': response,
        'responded_at': now,
        'decline_reason': body['reason'],
        'updated_at': now,
      })
      .eq('id', invitationId);

  // Update enrollment status based on response
  final enrollmentStatus = response == 'accepted' ? 'confirmed' : 'declined';
  await supabase
      .from('schedule_enrollments')
      .update({
        'status': enrollmentStatus,
        'confirmed_at': response == 'accepted' ? now : null,
        'declined_at': response == 'declined' ? now : null,
        'decline_reason': body['reason'],
        'updated_at': now,
      })
      .eq('id', invitation['enrollment_id']);

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_invitation',
    'entity_id': invitationId,
    'action': 'respond',
    'employee_id': auth.employeeId,
    'new_values': {
      'response': response,
      'reason': body['reason'],
    },
    'created_at': now,
  });

  return ApiResponse.ok({
    'message': 'Response recorded successfully',
    'response': response,
  }).toResponse();
}
