import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/trainers
///
/// Lists trainers with filters.
Future<Response> trainersListHandler(Request req) async {
  final supabase = RequestContext.supabase;

  final params = req.url.queryParameters;
  final isActive = params['is_active'];
  final competencyId = params['competency_id'];

  var query = supabase
      .from('trainers')
      .select('''
        id, trainer_type, specializations, is_active, created_at,
        employees(id, first_name, last_name, email)
      ''');

  if (isActive != null) {
    query = query.eq('is_active', isActive == 'true');
  }

  final trainers = await query.order('created_at', ascending: false);

  // Filter by competency if needed (post-query)
  List<Map<String, dynamic>> result = List<Map<String, dynamic>>.from(trainers);
  if (competencyId != null) {
    // Get trainer IDs with this competency
    final competentTrainers = await supabase
        .from('trainer_competencies')
        .select('trainer_id')
        .eq('competency_id', competencyId);
    final competentIds = competentTrainers.map((c) => c['trainer_id']).toSet();
    result = result.where((t) => competentIds.contains(t['id'])).toList();
  }

  return ApiResponse.ok(result).toResponse();
}

/// GET /v1/trainers/:id
Future<Response> trainerGetHandler(Request req) async {
  final trainerId = req.rawPathParameters[#id];
  final supabase = RequestContext.supabase;

  if (trainerId == null || trainerId.isEmpty) {
    throw ValidationException({'id': 'Trainer ID is required'});
  }

  final trainer = await supabase
      .from('trainers')
      .select('''
        *,
        employees(id, first_name, last_name, email, department_id),
        trainer_competencies(
          id,
          competencies(id, name, description)
        )
      ''')
      .eq('id', trainerId)
      .maybeSingle();

  if (trainer == null) {
    throw NotFoundException('Trainer not found');
  }

  return ApiResponse.ok(trainer).toResponse();
}

/// POST /v1/trainers
///
/// Creates a trainer record for an employee.
/// Body: { employee_id, trainer_type, specializations?, competency_ids?: [] }
Future<Response> trainerCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to create trainers');
  }

  final employeeId = requireUuid(body, 'employee_id');
  final trainerType = requireString(body, 'trainer_type');

  // Check employee exists
  final employee = await supabase
      .from('employees')
      .select('id')
      .eq('id', employeeId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  // Check not already a trainer
  final existing = await supabase
      .from('trainers')
      .select('id')
      .eq('employee_id', employeeId)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Employee is already registered as a trainer');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final trainer = await supabase
      .from('trainers')
      .insert({
        'employee_id': employeeId,
        'trainer_type': trainerType,
        'specializations': body['specializations'],
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  // Add competencies if provided
  final competencyIds = body['competency_ids'] as List?;
  if (competencyIds != null && competencyIds.isNotEmpty) {
    for (final compId in competencyIds) {
      await supabase.from('trainer_competencies').insert({
        'trainer_id': trainer['id'],
        'competency_id': compId,
        'assigned_at': now,
        'assigned_by': auth.employeeId,
      });
    }
  }

  return ApiResponse.created(trainer).toResponse();
}

/// PATCH /v1/trainers/:id
Future<Response> trainerUpdateHandler(Request req) async {
  final trainerId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (trainerId == null || trainerId.isEmpty) {
    throw ValidationException({'id': 'Trainer ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to update trainers');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  for (final field in ['trainer_type', 'specializations', 'is_active']) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('trainers')
      .update(updateData)
      .eq('id', trainerId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/trainers/:id/competencies
///
/// Adds competencies to a trainer.
/// Body: { competency_ids: [] }
Future<Response> trainerAddCompetenciesHandler(Request req) async {
  final trainerId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (trainerId == null || trainerId.isEmpty) {
    throw ValidationException({'id': 'Trainer ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to manage trainer competencies');
  }

  final competencyIds = body['competency_ids'] as List?;
  if (competencyIds == null || competencyIds.isEmpty) {
    throw ValidationException({'competency_ids': 'At least one competency ID is required'});
  }

  final now = DateTime.now().toUtc().toIso8601String();

  for (final compId in competencyIds) {
    await supabase.from('trainer_competencies').upsert(
      {
        'trainer_id': trainerId,
        'competency_id': compId,
        'assigned_at': now,
        'assigned_by': auth.employeeId,
      },
      onConflict: 'trainer_id,competency_id',
    );
  }

  return ApiResponse.ok({'message': 'Competencies added'}).toResponse();
}

/// DELETE /v1/trainers/:id/competencies/:competencyId
///
/// Removes a competency from a trainer.
Future<Response> trainerRemoveCompetencyHandler(Request req) async {
  final trainerId = req.rawPathParameters[#id];
  final competencyId = req.rawPathParameters[#competencyId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (trainerId == null || competencyId == null) {
    throw ValidationException({'id': 'Trainer ID and Competency ID are required'});
  }

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to manage trainer competencies');
  }

  await supabase
      .from('trainer_competencies')
      .delete()
      .eq('trainer_id', trainerId)
      .eq('competency_id', competencyId);

  return ApiResponse.noContent().toResponse();
}

/// DELETE /v1/trainers/:id
Future<Response> trainerDeleteHandler(Request req) async {
  final trainerId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (trainerId == null || trainerId.isEmpty) {
    throw ValidationException({'id': 'Trainer ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to delete trainers');
  }

  // Check for assigned sessions
  final sessions = await supabase
      .from('training_sessions')
      .select('id')
      .eq('trainer_id', trainerId)
      .inFilter('status', ['scheduled', 'in_progress'])
      .limit(1);

  if (sessions.isNotEmpty) {
    throw ConflictException('Cannot delete trainer with assigned sessions');
  }

  // Remove competencies first
  await supabase.from('trainer_competencies').delete().eq('trainer_id', trainerId);
  
  // Delete trainer
  await supabase.from('trainers').delete().eq('id', trainerId);

  return ApiResponse.noContent().toResponse();
}
