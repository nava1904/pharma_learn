import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart' as params;

/// GET /v1/schedules
///
/// Lists training schedules with filtering.
/// Query: ?course_id=UUID&trainer_id=UUID&status=scheduled|in_progress|completed|cancelled
///        &start_date=YYYY-MM-DD&end_date=YYYY-MM-DD&page=1&per_page=20
Future<Response> schedulesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  
  if (!auth.hasPermission(Permissions.manageSessions)) {
    throw PermissionDeniedException('You do not have permission to view training schedules');
  }

  final queryParams = req.url.queryParameters;
  final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(queryParams['per_page'] ?? '20') ?? 20;

  // Build count query
  var countQuery = supabase.from('training_schedules').select('id');
  if (queryParams['course_id'] != null) countQuery = countQuery.eq('course_id', queryParams['course_id']!);
  if (queryParams['trainer_id'] != null) countQuery = countQuery.eq('trainer_id', queryParams['trainer_id']!);
  if (queryParams['status'] != null) countQuery = countQuery.eq('status', queryParams['status']!);
  if (queryParams['start_date'] != null) countQuery = countQuery.gte('scheduled_date', queryParams['start_date']!);
  if (queryParams['end_date'] != null) countQuery = countQuery.lte('scheduled_date', queryParams['end_date']!);
  final countResult = await countQuery;
  final total = countResult.length;

  // Build data query
  var query = supabase
      .from('training_schedules')
      .select('''
        id, name, scheduled_date, start_time, end_time, location, status, max_participants,
        courses!inner(id, name, course_code, course_type),
        trainers(id, first_name, last_name, email),
        training_sessions(id)
      ''');

  if (queryParams['course_id'] != null) query = query.eq('course_id', queryParams['course_id']!);
  if (queryParams['trainer_id'] != null) query = query.eq('trainer_id', queryParams['trainer_id']!);
  if (queryParams['status'] != null) query = query.eq('status', queryParams['status']!);
  if (queryParams['start_date'] != null) query = query.gte('scheduled_date', queryParams['start_date']!);
  if (queryParams['end_date'] != null) query = query.lte('scheduled_date', queryParams['end_date']!);

  final schedules = await query
      .order('scheduled_date', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  // Attach session count to each schedule
  final data = schedules.map((s) {
    final sessions = s['training_sessions'] as List? ?? [];
    return {
      ...Map<String, dynamic>.from(s as Map)..remove('training_sessions'),
      'session_count': sessions.length,
    };
  }).toList();

  return ApiResponse.paginated(
    data,
    Pagination.compute(page: page, perPage: perPage, total: total),
  ).toResponse();
}

/// GET /v1/schedules/:id
///
/// Returns schedule details including all sessions.
Future<Response> scheduleGetHandler(Request req) async {
  final scheduleId = params.parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  
  if (!auth.hasPermission(Permissions.manageSessions)) {
    throw PermissionDeniedException('You do not have permission to view this schedule');
  }

  final schedule = await supabase
      .from('training_schedules')
      .select('''
        *,
        courses!inner(id, name, course_code, course_type, duration_hours),
        trainers(id, first_name, last_name, email),
        training_sessions(
          id, session_code, session_number, session_date, start_time, end_time,
          status, training_method, online_offline,
          session_attendance(id, employee_id, attendance_status)
        )
      ''')
      .eq('id', scheduleId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Training schedule not found');
  }

  return ApiResponse.ok(schedule).toResponse();
}

/// POST /v1/schedules
///
/// Creates a new training schedule.
/// Body: { course_id, trainer_id?, scheduled_date, start_time?, end_time?, location?, max_participants? }
Future<Response> scheduleCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to create training schedules');
  }

  final courseId = requireUuid(body, 'course_id');
  final scheduledDate = requireString(body, 'scheduled_date');
  final trainerId = optionalString(body, 'trainer_id');
  final maxParticipants = body['max_participants'] as int? ?? 50;

  // Verify course exists and is approved
  final course = await supabase
      .from('courses')
      .select('id, name, status')
      .eq('id', courseId)
      .maybeSingle();

  if (course == null) {
    throw NotFoundException('Course not found');
  }

  if (course['status'] != 'approved') {
    throw ValidationException({'course_id': 'Cannot schedule training for unapproved course'});
  }

  // Create the schedule
  final scheduleData = <String, dynamic>{
    'course_id': courseId,
    'trainer_id': trainerId,
    'scheduled_date': scheduledDate,
    'start_time': body['start_time'],
    'end_time': body['end_time'],
    'location': body['location'],
    'max_participants': maxParticipants,
    'status': 'scheduled',
    'created_by': auth.employeeId,
    'created_at': DateTime.now().toUtc().toIso8601String(),
  };

  final created = await supabase
      .from('training_schedules')
      .insert(scheduleData)
      .select()
      .single();

  // Log audit event
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': EventTypes.trainingAssigned,
    'entity_type': 'training_schedules',
    'entity_id': created['id'],
    'details': {
      'course_id': courseId,
      'scheduled_date': scheduledDate,
      'trainer_id': trainerId,
    },
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  return ApiResponse.created(created).toResponse();
}

/// PATCH /v1/schedules/:id
///
/// Updates a training schedule (only if not completed or cancelled).
Future<Response> scheduleUpdateHandler(Request req) async {
  final scheduleId = params.parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to update training schedules');
  }

  // Check schedule exists and is updatable
  final existing = await supabase
      .from('training_schedules')
      .select('id, status')
      .eq('id', scheduleId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Training schedule not found');
  }

  final status = existing['status'] as String?;
  if (status == 'completed' || status == 'cancelled') {
    throw ConflictException('Cannot update a completed or cancelled schedule');
  }

  // Build update data
  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = [
    'trainer_id', 'scheduled_date', 'start_time', 'end_time',
    'location', 'max_participants', 'status', 'notes',
  ];

  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('training_schedules')
      .update(updateData)
      .eq('id', scheduleId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/schedules/:id
///
/// Cancels a training schedule (soft delete).
Future<Response> scheduleCancelHandler(Request req) async {
  final scheduleId = params.parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to cancel training schedules');
  }

  // Check schedule exists
  final existing = await supabase
      .from('training_schedules')
      .select('id, status')
      .eq('id', scheduleId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Training schedule not found');
  }

  if (existing['status'] == 'completed') {
    throw ConflictException('Cannot cancel a completed schedule');
  }

  // Update status to cancelled
  await supabase
      .from('training_schedules')
      .update({
        'status': 'cancelled',
        'cancelled_by': auth.employeeId,
        'cancelled_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', scheduleId);

  // Also cancel all pending sessions
  await supabase
      .from('training_sessions')
      .update({'status': 'cancelled'})
      .eq('schedule_id', scheduleId)
      .neq('status', 'completed');

  return ApiResponse.noContent().toResponse();
}
