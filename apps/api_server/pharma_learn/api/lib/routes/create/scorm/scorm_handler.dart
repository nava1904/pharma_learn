import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/scorm/packages
///
/// Uploads a SCORM package (ZIP file).
/// Expects multipart/form-data with 'file' field.
Future<Response> scormUploadHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.createCourses)) {
    throw PermissionDeniedException('You do not have permission to upload SCORM packages');
  }

  // In production, parse multipart form data
  // This is simplified - actual implementation would use mime package
  final body = await readJson(req);
  
  final fileName = requireString(body, 'file_name');
  final fileSize = body['file_size'] as int? ?? 0;
  final courseId = body['course_id'] as String?;

  final now = DateTime.now().toUtc().toIso8601String();

  // Create SCORM package record
  final package = await supabase
      .from('scorm_packages')
      .insert({
        'course_id': courseId,
        'file_name': fileName,
        'file_size': fileSize,
        'scorm_version': '1.2', // We only support SCORM 1.2
        'status': 'processing',
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  // In production, this would:
  // 1. Upload ZIP to Supabase Storage
  // 2. Trigger Edge Function to extract and validate manifest
  // 3. Update package with manifest data

  return ApiResponse.created({
    'id': package['id'],
    'status': 'processing',
    'message': 'Package uploaded successfully. Processing manifest...',
  }).toResponse();
}

/// GET /v1/scorm/packages
///
/// Lists SCORM packages.
Future<Response> scormPackagesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.viewCourses)) {
    throw PermissionDeniedException('You do not have permission to view SCORM packages');
  }

  final params = req.url.queryParameters;
  final courseId = params['course_id'];
  final status = params['status'];

  var query = supabase
      .from('scorm_packages')
      .select('''
        id, file_name, scorm_version, status, created_at,
        courses(id, name, course_code)
      ''');

  if (courseId != null) query = query.eq('course_id', courseId);
  if (status != null) query = query.eq('status', status);

  final packages = await query.order('created_at', ascending: false);

  return ApiResponse.ok(packages).toResponse();
}

/// GET /v1/scorm/:id
///
/// Gets SCORM package details.
Future<Response> scormPackageGetHandler(Request req) async {
  final packageId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (packageId == null || packageId.isEmpty) {
    throw ValidationException({'id': 'Package ID is required'});
  }

  if (!auth.hasPermission(Permissions.viewCourses)) {
    throw PermissionDeniedException('You do not have permission to view SCORM packages');
  }

  final package = await supabase
      .from('scorm_packages')
      .select('''
        *,
        courses(id, name, course_code)
      ''')
      .eq('id', packageId)
      .maybeSingle();

  if (package == null) {
    throw NotFoundException('SCORM package not found');
  }

  return ApiResponse.ok(package).toResponse();
}

/// GET /v1/scorm/:id/launch
///
/// Gets the launch URL for a SCORM package.
/// Creates/resumes a SCORM session for the user.
Future<Response> scormLaunchHandler(Request req) async {
  final packageId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (packageId == null || packageId.isEmpty) {
    throw ValidationException({'id': 'Package ID is required'});
  }

  // Get package
  final package = await supabase
      .from('scorm_packages')
      .select('id, launch_url, status')
      .eq('id', packageId)
      .maybeSingle();

  if (package == null) {
    throw NotFoundException('SCORM package not found');
  }

  if (package['status'] != 'ready') {
    throw ConflictException('SCORM package is not ready for launch');
  }

  // Find or create SCORM session
  var session = await supabase
      .from('scorm_sessions')
      .select('id, cmi_data, status')
      .eq('package_id', packageId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  final now = DateTime.now().toUtc().toIso8601String();

  session ??= await supabase
        .from('scorm_sessions')
        .insert({
          'package_id': packageId,
          'employee_id': auth.employeeId,
          'status': 'not_attempted',
          'cmi_data': _initializeCmiData(),
          'created_at': now,
        })
        .select()
        .single();

  // Generate signed URL for SCORM content
  final launchUrl = package['launch_url'] as String?;
  
  return ApiResponse.ok({
    'session_id': session['id'],
    'launch_url': launchUrl,
    'cmi_data': session['cmi_data'],
    'status': session['status'],
  }).toResponse();
}

/// POST /v1/scorm/:id/commit
///
/// Commits SCORM CMI data from the JS bridge.
/// Body: { session_id, cmi_data }
Future<Response> scormCommitHandler(Request req) async {
  final packageId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (packageId == null || packageId.isEmpty) {
    throw ValidationException({'id': 'Package ID is required'});
  }

  final sessionId = requireString(body, 'session_id');
  final cmiData = body['cmi_data'] as Map<String, dynamic>?;

  if (cmiData == null) {
    throw ValidationException({'cmi_data': 'CMI data is required'});
  }

  // Verify session belongs to user
  final session = await supabase
      .from('scorm_sessions')
      .select('id, employee_id, status')
      .eq('id', sessionId)
      .eq('package_id', packageId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('SCORM session not found');
  }

  if (session['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('Session does not belong to you');
  }

  // Determine status from CMI data
  final lessonStatus = cmiData['cmi.core.lesson_status'] as String? ?? 'incomplete';
  String newStatus;
  switch (lessonStatus) {
    case 'passed':
    case 'completed':
      newStatus = 'completed';
      break;
    case 'failed':
      newStatus = 'failed';
      break;
    case 'incomplete':
      newStatus = 'incomplete';
      break;
    default:
      newStatus = 'incomplete';
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Update session
  await supabase
      .from('scorm_sessions')
      .update({
        'cmi_data': cmiData,
        'status': newStatus,
        'score': _extractScore(cmiData),
        'total_time': cmiData['cmi.core.total_time'],
        'last_accessed_at': now,
      })
      .eq('id', sessionId);

  // If completed, trigger training completion
  if (newStatus == 'completed' || newStatus == 'passed') {
    // Get course from package
    final package = await supabase
        .from('scorm_packages')
        .select('course_id')
        .eq('id', packageId)
        .single();

    if (package['course_id'] != null) {
      // Create training completion
      await supabase.from('training_completions').upsert(
        {
          'employee_id': auth.employeeId,
          'course_id': package['course_id'],
          'completion_type': 'scorm',
          'completed_at': now,
          'score': _extractScore(cmiData),
        },
        onConflict: 'employee_id,course_id',
      );
    }
  }

  return ApiResponse.ok({
    'status': newStatus,
    'message': 'CMI data committed successfully',
  }).toResponse();
}

/// DELETE /v1/scorm/:id
///
/// Deletes a SCORM package.
Future<Response> scormDeleteHandler(Request req) async {
  final packageId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (packageId == null || packageId.isEmpty) {
    throw ValidationException({'id': 'Package ID is required'});
  }

  if (!auth.hasPermission(Permissions.createCourses)) {
    throw PermissionDeniedException('You do not have permission to delete SCORM packages');
  }

  // Check for active sessions
  final sessions = await supabase
      .from('scorm_sessions')
      .select('id')
      .eq('package_id', packageId)
      .inFilter('status', ['incomplete', 'not_attempted'])
      .limit(1);

  if (sessions.isNotEmpty) {
    throw ConflictException('Cannot delete package with active sessions');
  }

  // Delete from storage (in production)
  // await supabase.storage.from('scorm').remove([package['storage_path']]);

  await supabase.from('scorm_packages').delete().eq('id', packageId);

  return ApiResponse.noContent().toResponse();
}

// Initialize SCORM 1.2 CMI data structure
Map<String, dynamic> _initializeCmiData() {
  return {
    'cmi.core.lesson_status': 'not attempted',
    'cmi.core.lesson_location': '',
    'cmi.core.entry': 'ab-initio',
    'cmi.core.score.raw': '',
    'cmi.core.score.min': '',
    'cmi.core.score.max': '',
    'cmi.core.total_time': '0000:00:00',
    'cmi.core.session_time': '0000:00:00',
    'cmi.suspend_data': '',
  };
}

// Extract score from CMI data
double? _extractScore(Map<String, dynamic> cmiData) {
  final raw = cmiData['cmi.core.score.raw'];
  if (raw == null || raw == '') return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString());
}
