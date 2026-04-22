import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/batches
///
/// Lists training batches (groups of schedules/sessions).
Future<Response> batchesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to view batches');
  }

  final params = req.url.queryParameters;
  final status = params['status'];
  final courseId = params['course_id'];

  var query = supabase
      .from('training_batches')
      .select('''
        id, batch_number, name, status, start_date, end_date,
        courses(id, name, course_code),
        training_schedules(count)
      ''');

  if (status != null) query = query.eq('status', status);
  if (courseId != null) query = query.eq('course_id', courseId);

  final batches = await query.order('start_date', ascending: false);

  final data = batches.map((b) {
    final schedules = b['training_schedules'] as List? ?? [];
    return {
      ...Map<String, dynamic>.from(b as Map)..remove('training_schedules'),
      'schedule_count': schedules.isEmpty ? 0 : (schedules[0]['count'] ?? 0),
    };
  }).toList();

  return ApiResponse.ok(data).toResponse();
}

/// POST /v1/train/batches
///
/// Creates a new training batch.
/// Body: {
///   name: string,
///   course_id: string,
///   start_date: date,
///   end_date?: date,
///   max_participants?: number
/// }
Future<Response> batchCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to create batches');
  }

  final name = requireString(body, 'name');
  final courseId = requireUuid(body, 'course_id');
  final startDate = requireString(body, 'start_date');

  final now = DateTime.now().toUtc().toIso8601String();

  // Generate batch number
  final batchCount = await supabase
      .from('training_batches')
      .select('id')
      .eq('course_id', courseId);
  
  final batchNumber = 'BATCH-${(batchCount as List).length + 1}'.padLeft(3, '0');

  final batch = await supabase
      .from('training_batches')
      .insert({
        'batch_number': batchNumber,
        'name': name,
        'course_id': courseId,
        'start_date': startDate,
        'end_date': body['end_date'],
        'max_participants': body['max_participants'],
        'status': 'planned',
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(batch).toResponse();
}

/// GET /v1/train/batches/:id
///
/// Gets a specific batch with its schedules.
Future<Response> batchGetHandler(Request req) async {
  final batchId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (batchId == null || batchId.isEmpty) {
    throw ValidationException({'id': 'Batch ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to view batches');
  }

  final batch = await supabase
      .from('training_batches')
      .select('''
        *,
        courses(id, name, course_code, description),
        training_schedules(
          id, title, status, scheduled_date, scheduled_time,
          venues(id, name),
          trainers:trainer_id(id, first_name, last_name),
          schedule_enrollments(count)
        )
      ''')
      .eq('id', batchId)
      .maybeSingle();

  if (batch == null) {
    throw NotFoundException('Batch not found');
  }

  return ApiResponse.ok(batch).toResponse();
}

/// PATCH /v1/train/batches/:id
///
/// Updates a batch.
Future<Response> batchUpdateHandler(Request req) async {
  final batchId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (batchId == null || batchId.isEmpty) {
    throw ValidationException({'id': 'Batch ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to update batches');
  }

  final existing = await supabase
      .from('training_batches')
      .select('id, status')
      .eq('id', batchId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Batch not found');
  }

  if (existing['status'] == 'completed') {
    throw ConflictException('Cannot modify a completed batch');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = ['name', 'start_date', 'end_date', 'max_participants', 'status'];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('training_batches')
      .update(updateData)
      .eq('id', batchId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/train/batches/:id/schedules
///
/// Adds a schedule to a batch.
/// Body: { schedule_id: string }
Future<Response> batchAddScheduleHandler(Request req) async {
  final batchId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (batchId == null || batchId.isEmpty) {
    throw ValidationException({'id': 'Batch ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to modify batches');
  }

  final scheduleId = requireUuid(body, 'schedule_id');

  // Verify batch exists
  final batch = await supabase
      .from('training_batches')
      .select('id, course_id, status')
      .eq('id', batchId)
      .maybeSingle();

  if (batch == null) {
    throw NotFoundException('Batch not found');
  }

  if (batch['status'] == 'completed') {
    throw ConflictException('Cannot add schedules to a completed batch');
  }

  // Verify schedule exists and is for the same course
  final schedule = await supabase
      .from('training_schedules')
      .select('id, course_id')
      .eq('id', scheduleId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Schedule not found');
  }

  if (schedule['course_id'] != batch['course_id']) {
    throw ValidationException({
      'schedule_id': 'Schedule course must match batch course'
    });
  }

  // Link schedule to batch
  await supabase
      .from('training_schedules')
      .update({
        'batch_id': batchId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', scheduleId);

  return ApiResponse.ok({'message': 'Schedule added to batch'}).toResponse();
}

/// DELETE /v1/train/batches/:id/schedules/:scheduleId
///
/// Removes a schedule from a batch.
Future<Response> batchRemoveScheduleHandler(Request req) async {
  final batchId = req.rawPathParameters[#id];
  final scheduleId = req.rawPathParameters[#scheduleId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (batchId == null || scheduleId == null) {
    throw ValidationException({'id': 'Batch ID and Schedule ID are required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to modify batches');
  }

  // Remove batch reference from schedule
  await supabase
      .from('training_schedules')
      .update({
        'batch_id': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', scheduleId)
      .eq('batch_id', batchId);

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/train/batches/:id/complete [esig]
///
/// Marks a batch as completed. Requires e-signature.
Future<Response> batchCompleteHandler(Request req) async {
  final batchId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);
  final esignatureId = body['esignature_id'] as String?;

  if (batchId == null || batchId.isEmpty) {
    throw ValidationException({'id': 'Batch ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to complete batches');
  }

  final batch = await supabase
      .from('training_batches')
      .select('id, status')
      .eq('id', batchId)
      .maybeSingle();

  if (batch == null) {
    throw NotFoundException('Batch not found');
  }

  if (batch['status'] == 'completed') {
    throw ConflictException('Batch is already completed');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('training_batches')
      .update({
        'status': 'completed',
        'completed_by': auth.employeeId,
        'completed_at': now,
        'completion_esignature_id': esignatureId,
        'updated_at': now,
      })
      .eq('id', batchId);

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_batch',
    'entity_id': batchId,
    'action': 'complete',
    'employee_id': auth.employeeId,
    'esignature_id': esignatureId,
    'old_values': {'status': batch['status']},
    'new_values': {'status': 'completed'},
    'created_at': now,
  });

  return ApiResponse.ok({'message': 'Batch completed successfully'}).toResponse();
}
