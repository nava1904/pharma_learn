import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/curricula
///
/// Lists curricula with filters.
Future<Response> curriculaListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.viewCourses)) {
    throw PermissionDeniedException('You do not have permission to view curricula');
  }

  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;
  final status = params['status'];

  var countQuery = supabase.from('curricula').select('id');
  if (status != null) countQuery = countQuery.eq('status', status);
  final countResult = await countQuery;
  final total = countResult.length;

  var query = supabase
      .from('curricula')
      .select('''
        id, name, description, status, effective_date, expiry_date, created_at,
        curriculum_courses(count)
      ''');

  if (status != null) query = query.eq('status', status);

  final curricula = await query
      .order('name', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  final data = curricula.map((c) {
    final courses = c['curriculum_courses'] as List? ?? [];
    return {
      ...Map<String, dynamic>.from(c as Map)..remove('curriculum_courses'),
      'course_count': courses.isEmpty ? 0 : (courses[0]['count'] ?? 0),
    };
  }).toList();

  return ApiResponse.paginated(
    data,
    Pagination.compute(page: page, perPage: perPage, total: total),
  ).toResponse();
}

/// GET /v1/curricula/:id
///
/// Gets a curriculum with its courses.
Future<Response> curriculumGetHandler(Request req) async {
  final curriculumId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (curriculumId == null || curriculumId.isEmpty) {
    throw ValidationException({'id': 'Curriculum ID is required'});
  }

  if (!auth.hasPermission(Permissions.viewCourses)) {
    throw PermissionDeniedException('You do not have permission to view curricula');
  }

  final curriculum = await supabase
      .from('curricula')
      .select('''
        *,
        curriculum_courses(
          id, sort_order, is_mandatory,
          courses(id, name, course_code, duration_hours)
        )
      ''')
      .eq('id', curriculumId)
      .maybeSingle();

  if (curriculum == null) {
    throw NotFoundException('Curriculum not found');
  }

  return ApiResponse.ok(curriculum).toResponse();
}

/// POST /v1/curricula
///
/// Creates a new curriculum.
/// Body: { name, description?, effective_date?, courses?: [{course_id, sort_order, is_mandatory}] }
Future<Response> curriculumCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.createCourses)) {
    throw PermissionDeniedException('You do not have permission to create curricula');
  }

  final name = requireString(body, 'name');

  final now = DateTime.now().toUtc().toIso8601String();

  final curriculum = await supabase
      .from('curricula')
      .insert({
        'name': name,
        'description': body['description'],
        'status': 'draft',
        'effective_date': body['effective_date'],
        'expiry_date': body['expiry_date'],
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  // Add courses if provided
  final courses = body['courses'] as List?;
  if (courses != null && courses.isNotEmpty) {
    for (final course in courses) {
      await supabase.from('curriculum_courses').insert({
        'curriculum_id': curriculum['id'],
        'course_id': course['course_id'],
        'sort_order': course['sort_order'] ?? 0,
        'is_mandatory': course['is_mandatory'] ?? true,
      });
    }
  }

  return ApiResponse.created(curriculum).toResponse();
}

/// PATCH /v1/curricula/:id
///
/// Updates a curriculum.
Future<Response> curriculumUpdateHandler(Request req) async {
  final curriculumId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (curriculumId == null || curriculumId.isEmpty) {
    throw ValidationException({'id': 'Curriculum ID is required'});
  }

  if (!auth.hasPermission(Permissions.editCourses)) {
    throw PermissionDeniedException('You do not have permission to update curricula');
  }

  final existing = await supabase
      .from('curricula')
      .select('id, status')
      .eq('id', curriculumId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Curriculum not found');
  }

  if (existing['status'] == 'approved') {
    throw ConflictException('Cannot modify an approved curriculum');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  for (final field in ['name', 'description', 'effective_date', 'expiry_date']) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('curricula')
      .update(updateData)
      .eq('id', curriculumId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/curricula/:id/courses
///
/// Adds a course to a curriculum.
/// Body: { course_id, sort_order?, is_mandatory? }
Future<Response> curriculumAddCourseHandler(Request req) async {
  final curriculumId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (curriculumId == null || curriculumId.isEmpty) {
    throw ValidationException({'id': 'Curriculum ID is required'});
  }

  if (!auth.hasPermission(Permissions.editCourses)) {
    throw PermissionDeniedException('You do not have permission to modify curricula');
  }

  final courseId = requireUuid(body, 'course_id');

  await supabase.from('curriculum_courses').upsert(
    {
      'curriculum_id': curriculumId,
      'course_id': courseId,
      'sort_order': body['sort_order'] ?? 0,
      'is_mandatory': body['is_mandatory'] ?? true,
    },
    onConflict: 'curriculum_id,course_id',
  );

  return ApiResponse.ok({'message': 'Course added to curriculum'}).toResponse();
}

/// DELETE /v1/curricula/:id/courses/:courseId
///
/// Removes a course from a curriculum.
Future<Response> curriculumRemoveCourseHandler(Request req) async {
  final curriculumId = req.rawPathParameters[#id];
  final courseId = req.rawPathParameters[#courseId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (curriculumId == null || courseId == null) {
    throw ValidationException({'id': 'Curriculum ID and Course ID are required'});
  }

  if (!auth.hasPermission(Permissions.editCourses)) {
    throw PermissionDeniedException('You do not have permission to modify curricula');
  }

  await supabase
      .from('curriculum_courses')
      .delete()
      .eq('curriculum_id', curriculumId)
      .eq('course_id', courseId);

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/curricula/:id/submit
///
/// Submits a curriculum for approval.
Future<Response> curriculumSubmitHandler(Request req) async {
  final curriculumId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (curriculumId == null || curriculumId.isEmpty) {
    throw ValidationException({'id': 'Curriculum ID is required'});
  }

  if (!auth.hasPermission(Permissions.createCourses)) {
    throw PermissionDeniedException('You do not have permission to submit curricula');
  }

  final existing = await supabase
      .from('curricula')
      .select('id, status')
      .eq('id', curriculumId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Curriculum not found');
  }

  if (existing['status'] != 'draft') {
    throw ConflictException('Only draft curricula can be submitted');
  }

  // Check it has at least one course
  final courses = await supabase
      .from('curriculum_courses')
      .select('id')
      .eq('curriculum_id', curriculumId)
      .limit(1);

  if (courses.isEmpty) {
    throw ValidationException({'courses': 'Curriculum must have at least one course'});
  }

  await supabase
      .from('curricula')
      .update({
        'status': 'pending_approval',
        'submitted_by': auth.employeeId,
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', curriculumId);

  return ApiResponse.ok({'message': 'Curriculum submitted for approval'}).toResponse();
}

/// POST /v1/curricula/:id/approve [esig]
///
/// Approves a curriculum.
Future<Response> curriculumApproveHandler(Request req) async {
  final curriculumId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;
  final supabase = RequestContext.supabase;

  if (curriculumId == null || curriculumId.isEmpty) {
    throw ValidationException({'id': 'Curriculum ID is required'});
  }

  if (esig == null) {
    throw EsigRequiredException('E-signature required to approve curriculum');
  }

  if (!auth.hasPermission(Permissions.approveCourses)) {
    throw PermissionDeniedException('You do not have permission to approve curricula');
  }

  final existing = await supabase
      .from('curricula')
      .select('id, status')
      .eq('id', curriculumId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Curriculum not found');
  }

  if (existing['status'] != 'pending_approval') {
    throw ConflictException('Only pending curricula can be approved');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Create e-signature
  final esigResult = await supabase.rpc('create_esignature', params: {
    'p_employee_id': auth.employeeId,
    'p_reauth_session_id': esig.reauthSessionId,
    'p_entity_type': 'curricula',
    'p_entity_id': curriculumId,
    'p_action': 'approve',
    'p_meaning': esig.meaning,
    'p_reason': esig.reason,
  });

  await supabase
      .from('curricula')
      .update({
        'status': 'approved',
        'approved_by': auth.employeeId,
        'approved_at': now,
        'approval_esig_id': esigResult['id'],
      })
      .eq('id', curriculumId);

  return ApiResponse.ok({'message': 'Curriculum approved'}).toResponse();
}
