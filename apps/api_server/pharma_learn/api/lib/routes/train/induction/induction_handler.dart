import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/induction/status
///
/// Returns the current employee's induction status including:
/// - Whether induction is completed
/// - List of mandatory modules with completion status
/// - Overall progress percentage
Future<Response> inductionStatusHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Get employee's induction progress
  final employee = await supabase
      .from('employees')
      .select('id, first_name, last_name, induction_completed, induction_completed_at')
      .eq('id', auth.employeeId)
      .single();

  // Get all mandatory induction courses for the employee's plant/role
  final mandatoryCourses = await supabase
      .from('courses')
      .select('''
        id, name, course_code, course_type, duration_hours,
        training_obligations!inner(id, is_mandatory)
      ''')
      .eq('is_induction', true)
      .eq('status', 'approved');

  // Get employee's completed trainings for these courses
  final completedTrainings = await supabase
      .from('training_completions')
      .select('id, course_id, completed_at, certificate_id')
      .eq('employee_id', auth.employeeId)
      .inFilter('course_id', mandatoryCourses.map((c) => c['id']).toList());

  final completedCourseIds = completedTrainings
      .map((t) => t['course_id'])
      .toSet();

  // Build module status list
  final modules = mandatoryCourses.map((course) {
    final completed = completedCourseIds.contains(course['id']);
    final completion = completedTrainings
        .where((t) => t['course_id'] == course['id'])
        .firstOrNull;
    
    return {
      'course_id': course['id'],
      'name': course['name'],
      'course_code': course['course_code'],
      'duration_hours': course['duration_hours'],
      'completed': completed,
      'completed_at': completion?['completed_at'],
      'certificate_id': completion?['certificate_id'],
    };
  }).toList();

  final completedCount = modules.where((m) => m['completed'] == true).length;
  final totalCount = modules.length;
  final progressPercent = totalCount > 0 
      ? ((completedCount / totalCount) * 100).round()
      : 100;

  return ApiResponse.ok({
    'employee': {
      'id': employee['id'],
      'name': '${employee['first_name']} ${employee['last_name']}',
      'induction_completed': employee['induction_completed'] ?? false,
      'induction_completed_at': employee['induction_completed_at'],
    },
    'progress': {
      'completed': completedCount,
      'total': totalCount,
      'percent': progressPercent,
    },
    'modules': modules,
    'can_complete': completedCount == totalCount && totalCount > 0,
  }).toResponse();
}

/// POST /v1/induction/complete
///
/// Marks the employee's induction as complete. 
/// REQUIRES: All mandatory induction modules completed.
/// REQUIRES: E-signature via withEsig middleware.
///
/// Body: { reason: "Mandatory induction training completed" }
Future<Response> inductionCompleteHandler(Request req) async {
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;
  final supabase = RequestContext.supabase;

  if (esig == null) {
    throw EsigRequiredException('E-signature required to complete induction');
  }

  // Verify all mandatory modules are complete
  final mandatoryCourses = await supabase
      .from('courses')
      .select('id')
      .eq('is_induction', true)
      .eq('status', 'approved');

  final completedCourseIds = await supabase
      .from('training_completions')
      .select('course_id')
      .eq('employee_id', auth.employeeId)
      .inFilter('course_id', mandatoryCourses.map((c) => c['id']).toList());

  final mandatoryIds = mandatoryCourses.map((c) => c['id']).toSet();
  final completedIds = completedCourseIds.map((c) => c['course_id']).toSet();

  if (!mandatoryIds.every((id) => completedIds.contains(id))) {
    throw ValidationException({
      'induction': 'Not all mandatory induction modules are completed',
    });
  }

  // Already completed check
  final employee = await supabase
      .from('employees')
      .select('induction_completed')
      .eq('id', auth.employeeId)
      .single();

  if (employee['induction_completed'] == true) {
    throw ConflictException('Induction already completed');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Create e-signature record via RPC
  final esigResult = await supabase.rpc('create_esignature', params: {
    'p_employee_id': auth.employeeId,
    'p_reauth_session_id': esig.reauthSessionId,
    'p_entity_type': 'induction',
    'p_entity_id': auth.employeeId,
    'p_action': 'complete',
    'p_meaning': esig.meaning,
    'p_reason': esig.reason ?? 'Mandatory induction training completed',
  });

  final esigId = esigResult['id'] as String;

  // Update employee record
  await supabase
      .from('employees')
      .update({
        'induction_completed': true,
        'induction_completed_at': now,
        'induction_esig_id': esigId,
      })
      .eq('id', auth.employeeId);

  // Create audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': EventTypes.trainingCompleted,
    'entity_type': 'induction',
    'entity_id': auth.employeeId,
    'esig_id': esigId,
    'details': {
      'action': 'induction_completed',
      'completed_modules': completedIds.toList(),
    },
    'created_at': now,
  });

  return ApiResponse.ok({
    'message': 'Induction completed successfully',
    'induction_completed': true,
    'completed_at': now,
    'esig_id': esigId,
  }).toResponse();
}

/// GET /v1/induction/modules
///
/// Returns the list of available induction modules (courses).
/// Public within the org - no special permission needed.
Future<Response> inductionModulesHandler(Request req) async {
  final supabase = RequestContext.supabase;

  final modules = await supabase
      .from('courses')
      .select('''
        id, name, course_code, description, course_type,
        duration_hours, content_type, thumbnail_url,
        is_induction, is_mandatory
      ''')
      .eq('is_induction', true)
      .eq('status', 'approved')
      .order('sort_order', ascending: true);

  return ApiResponse.ok(modules).toResponse();
}

/// GET /v1/induction/modules/:id
///
/// Returns details of a specific induction module for the employee to start.
Future<Response> inductionModuleDetailHandler(Request req) async {
  final moduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (moduleId == null || moduleId.isEmpty) {
    throw ValidationException({'id': 'Module ID is required'});
  }

  final module = await supabase
      .from('courses')
      .select('''
        *,
        course_sections(
          id, title, sort_order, duration_minutes,
          section_content(id, content_type, title, sort_order)
        )
      ''')
      .eq('id', moduleId)
      .eq('is_induction', true)
      .eq('status', 'approved')
      .maybeSingle();

  if (module == null) {
    throw NotFoundException('Induction module not found');
  }

  // Check employee's progress on this module
  final progress = await supabase
      .from('training_progress')
      .select('*')
      .eq('employee_id', auth.employeeId)
      .eq('course_id', moduleId)
      .maybeSingle();

  final completion = await supabase
      .from('training_completions')
      .select('id, completed_at, certificate_id')
      .eq('employee_id', auth.employeeId)
      .eq('course_id', moduleId)
      .maybeSingle();

  return ApiResponse.ok({
    ...module,
    'employee_progress': progress,
    'completion': completion,
  }).toResponse();
}
