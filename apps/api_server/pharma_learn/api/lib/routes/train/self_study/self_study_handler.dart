import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/self-study-courses
///
/// Browses catalogue of open courses for self-study enrollment.
/// Query params: category, type, duration_max, page, per_page
Future<Response> selfStudyCoursesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;
  final category = params['category'];
  final courseType = params['type'];
  final maxDuration = int.tryParse(params['duration_max'] ?? '0');

  var query = supabase
      .from('self_study_courses')
      .select('''
        id, name, description, course_type, duration_hours,
        thumbnail_url, is_active, created_at,
        category:categories(id, name),
        enrolled_count:self_study_enrollments(count)
      ''')
      .eq('organization_id', auth.orgId)
      .eq('is_active', true)
      .eq('is_open_enrollment', true);

  if (category != null) {
    query = query.eq('category_id', category);
  }

  if (courseType != null) {
    query = query.eq('course_type', courseType);
  }

  if (maxDuration != null && maxDuration > 0) {
    query = query.lte('duration_hours', maxDuration);
  }

  final results = await query
      .order('name', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  // Get user's current enrollments to mark enrolled courses
  final userEnrollments = await supabase
      .from('self_study_enrollments')
      .select('course_id, status')
      .eq('employee_id', auth.employeeId);

  final enrolledCourseIds = <String, String>{};
  for (final e in userEnrollments as List) {
    enrolledCourseIds[e['course_id'] as String] = e['status'] as String;
  }

  // Enhance results with enrollment status
  final enhancedResults = (results as List).map((course) {
    final courseId = course['id'] as String;
    return {
      ...course,
      'enrollment_status': enrolledCourseIds[courseId],
      'is_enrolled': enrolledCourseIds.containsKey(courseId),
    };
  }).toList();

  return ApiResponse.ok({
    'courses': enhancedResults,
    'pagination': {
      'page': page,
      'per_page': perPage,
    },
  }).toResponse();
}

/// GET /v1/train/self-study-courses/:id
///
/// Gets self-study course detail with module list.
Future<Response> selfStudyCourseGetHandler(Request req) async {
  final courseId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (courseId == null || courseId.isEmpty) {
    throw ValidationException({'id': 'Course ID is required'});
  }

  final course = await supabase
      .from('self_study_courses')
      .select('''
        id, name, description, course_type, duration_hours,
        thumbnail_url, is_active, prerequisites, learning_objectives,
        category:categories(id, name),
        modules:self_study_modules(
          id, name, description, sequence_order, duration_minutes,
          content_type, content_url
        )
      ''')
      .eq('id', courseId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (course == null) {
    throw NotFoundException('Self-study course not found');
  }

  // Check enrollment status
  final enrollment = await supabase
      .from('self_study_enrollments')
      .select('id, status, enrolled_at, started_at, completed_at')
      .eq('course_id', courseId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  // Get progress if enrolled
  Map<String, dynamic>? progress;
  if (enrollment != null) {
    final progressData = await supabase
        .from('learning_progress')
        .select('module_id:content_id, status, progress_percent')
        .eq('employee_id', auth.employeeId)
        .eq('content_type', 'self_study_module')
        .inFilter('content_id', (course['modules'] as List).map((m) => m['id']).toList());

    final moduleProgress = <String, Map<String, dynamic>>{};
    for (final p in progressData as List) {
      moduleProgress[p['module_id'] as String] = p;
    }

    final totalModules = (course['modules'] as List).length;
    final completedModules = moduleProgress.values
        .where((p) => p['status'] == 'completed')
        .length;

    progress = {
      'total_modules': totalModules,
      'completed_modules': completedModules,
      'progress_percent': totalModules > 0 
          ? (completedModules / totalModules * 100).round() 
          : 0,
      'module_progress': moduleProgress,
    };
  }

  return ApiResponse.ok({
    'course': course,
    'enrollment': enrollment,
    'progress': progress,
  }).toResponse();
}

/// POST /v1/train/self-study-courses/:id/enroll
///
/// Employee self-enrolls in an open course.
Future<Response> selfStudyCourseEnrollHandler(Request req) async {
  final courseId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (courseId == null || courseId.isEmpty) {
    throw ValidationException({'id': 'Course ID is required'});
  }

  // Verify course exists and is open
  final course = await supabase
      .from('self_study_courses')
      .select('id, name, is_active, is_open_enrollment, prerequisites')
      .eq('id', courseId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (course == null) {
    throw NotFoundException('Self-study course not found');
  }

  if (course['is_active'] != true || course['is_open_enrollment'] != true) {
    throw ValidationException({
      'course': 'This course is not available for self-enrollment',
    });
  }

  // Check if already enrolled
  final existing = await supabase
      .from('self_study_enrollments')
      .select('id, status')
      .eq('course_id', courseId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (existing != null) {
    if (existing['status'] == 'completed') {
      throw ConflictException('You have already completed this course');
    }
    throw ConflictException('You are already enrolled in this course');
  }

  // Check prerequisites
  final prerequisites = course['prerequisites'] as List? ?? [];
  if (prerequisites.isNotEmpty) {
    final completedCourses = await supabase
        .from('self_study_enrollments')
        .select('course_id')
        .eq('employee_id', auth.employeeId)
        .eq('status', 'completed')
        .inFilter('course_id', prerequisites);

    final completedIds = (completedCourses as List)
        .map((c) => c['course_id'] as String)
        .toSet();

    final missingPrereqs = prerequisites
        .where((p) => !completedIds.contains(p))
        .toList();

    if (missingPrereqs.isNotEmpty) {
      throw ValidationException({
        'prerequisites': 'You must complete prerequisite courses first',
        'missing': missingPrereqs,
      });
    }
  }

  // Create enrollment
  final enrollment = await supabase
      .from('self_study_enrollments')
      .insert({
        'course_id': courseId,
        'employee_id': auth.employeeId,
        'status': 'enrolled',
        'enrolled_at': DateTime.now().toUtc().toIso8601String(),
        'organization_id': auth.orgId,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'self_study_enrollment',
    aggregateId: enrollment['id'] as String,
    eventType: 'self_study.enrolled',
    payload: {
      'course_id': courseId,
      'employee_id': auth.employeeId,
    },
  );

  return ApiResponse.created({
    'enrollment': enrollment,
    'message': 'Successfully enrolled in course',
  }).toResponse();
}

/// GET /v1/train/self-study-courses/:id/progress
///
/// Gets employee's own progress in a self-study course.
Future<Response> selfStudyCourseProgressHandler(Request req) async {
  final courseId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (courseId == null || courseId.isEmpty) {
    throw ValidationException({'id': 'Course ID is required'});
  }

  // Get enrollment
  final enrollment = await supabase
      .from('self_study_enrollments')
      .select('id, status, enrolled_at, started_at, completed_at')
      .eq('course_id', courseId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (enrollment == null) {
    throw NotFoundException('You are not enrolled in this course');
  }

  // Get modules
  final modules = await supabase
      .from('self_study_modules')
      .select('id, name, sequence_order, duration_minutes')
      .eq('course_id', courseId)
      .order('sequence_order');

  // Get progress for each module
  final progressData = await supabase
      .from('learning_progress')
      .select('content_id, status, progress_percent, started_at, completed_at')
      .eq('employee_id', auth.employeeId)
      .eq('content_type', 'self_study_module')
      .inFilter('content_id', (modules as List).map((m) => m['id']).toList());

  final moduleProgress = <String, Map<String, dynamic>>{};
  for (final p in progressData as List) {
    moduleProgress[p['content_id'] as String] = p;
  }

  // Calculate overall progress
  final totalModules = modules.length;
  final completedModules = moduleProgress.values
      .where((p) => p['status'] == 'completed')
      .length;

  final modulesWithProgress = modules.map((m) {
    final progress = moduleProgress[m['id'] as String];
    return {
      ...m,
      'status': progress?['status'] ?? 'not_started',
      'progress_percent': progress?['progress_percent'] ?? 0,
      'started_at': progress?['started_at'],
      'completed_at': progress?['completed_at'],
    };
  }).toList();

  return ApiResponse.ok({
    'enrollment': enrollment,
    'modules': modulesWithProgress,
    'summary': {
      'total_modules': totalModules,
      'completed_modules': completedModules,
      'progress_percent': totalModules > 0 
          ? (completedModules / totalModules * 100).round() 
          : 0,
    },
  }).toResponse();
}

/// DELETE /v1/train/self-study-courses/:id/enroll
///
/// Unenrolls from a self-study course (if not yet started).
Future<Response> selfStudyCourseUnenrollHandler(Request req) async {
  final courseId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (courseId == null || courseId.isEmpty) {
    throw ValidationException({'id': 'Course ID is required'});
  }

  // Get enrollment
  final enrollment = await supabase
      .from('self_study_enrollments')
      .select('id, status, started_at')
      .eq('course_id', courseId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (enrollment == null) {
    throw NotFoundException('You are not enrolled in this course');
  }

  if (enrollment['started_at'] != null) {
    throw ConflictException('Cannot unenroll after starting the course');
  }

  if (enrollment['status'] == 'completed') {
    throw ConflictException('Cannot unenroll from a completed course');
  }

  await supabase
      .from('self_study_enrollments')
      .delete()
      .eq('id', enrollment['id']);

  return ApiResponse.ok({
    'message': 'Successfully unenrolled from course',
  }).toResponse();
}
