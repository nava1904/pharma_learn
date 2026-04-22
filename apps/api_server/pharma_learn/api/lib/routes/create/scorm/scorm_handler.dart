import 'dart:convert';
import 'dart:typed_data';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart' hide ScormService, ScormValidationException;

import '../../../services/scorm_service.dart';

// ---------------------------------------------------------------------------
// SCORM Handlers — S8 Implementation
// ---------------------------------------------------------------------------
// SCORM 1.2 support: package upload, launch, CMI commit
// Uses synchronous ZIP extraction with archive package
// ---------------------------------------------------------------------------

/// POST /v1/scorm/packages
///
/// Uploads and processes a SCORM package (ZIP file).
/// 
/// Accepts either:
/// - multipart/form-data with 'file' field
/// - application/json with base64-encoded file data
///
/// Flow:
/// 1. Create scorm_packages record (status='processing')
/// 2. Extract ZIP, parse imsmanifest.xml
/// 3. Upload extracted files to Storage
/// 4. Update record with manifest data (status='ready')
Future<Response> scormUploadHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.createCourses)) {
    throw PermissionDeniedException('You do not have permission to upload SCORM packages');
  }

  // Parse request - support both multipart and JSON with base64
  Uint8List zipBytes;
  String fileName;
  String? courseId;

  final contentType = req.headers['content-type']?.first ?? '';
  
  if (contentType.contains('multipart/form-data')) {
    // Parse multipart form data
    final boundary = _extractBoundary(contentType);
    if (boundary == null) {
      throw ValidationException({'content-type': 'Invalid multipart boundary'});
    }
    
    final bodyBytes = await req.read().expand((chunk) => chunk).toList();
    final parts = _parseMultipart(Uint8List.fromList(bodyBytes), boundary);
    
    final filePart = parts['file'];
    if (filePart == null) {
      throw ValidationException({'file': 'SCORM ZIP file is required'});
    }
    
    zipBytes = filePart.bytes;
    fileName = filePart.filename ?? 'package.zip';
    courseId = parts['course_id']?.asString;
  } else {
    // JSON with base64-encoded file
    final body = await readJson(req);
    final fileData = body['file_data'] as String?;
    fileName = body['file_name'] as String? ?? 'package.zip';
    courseId = body['course_id'] as String?;
    
    if (fileData == null) {
      throw ValidationException({'file_data': 'Base64 file data is required'});
    }
    
    try {
      zipBytes = base64Decode(fileData);
    } catch (e) {
      throw ValidationException({'file_data': 'Invalid base64 encoding'});
    }
  }

  // Validate file extension
  if (!fileName.toLowerCase().endsWith('.zip')) {
    throw ValidationException({'file': 'File must be a ZIP archive'});
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Create initial package record
  final package = await supabase
      .from('scorm_packages')
      .insert({
        'organization_id': auth.orgId,
        'course_id': courseId,
        'file_name': fileName,
        'file_size_bytes': zipBytes.length,
        'scorm_version': '1.2',
        'status': 'processing',
        'uploaded_by': auth.employeeId,
        'uploaded_at': now,
        'created_at': now,
      })
      .select()
      .single();

  final packageId = package['id'] as String;

  try {
    // Process SCORM package
    final scormService = ScormService(supabase);
    final manifest = await scormService.processPackage(
      zipBytes: zipBytes,
      orgId: auth.orgId,
      packageId: packageId,
    );

    // Update package with manifest data
    await supabase
        .from('scorm_packages')
        .update({
          'title': manifest.title,
          'launch_url': manifest.launchUrl,
          'mastery_threshold': manifest.masteryScore,
          'manifest_json': manifest.toJson(),
          'status': 'ready',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', packageId);

    // Publish event
    await EventPublisher.publish(
      supabase,
      eventType: 'scorm.package_uploaded',
      aggregateType: 'scorm_package',
      aggregateId: packageId,
      orgId: auth.orgId,
      payload: {
        'course_id': courseId,
        'title': manifest.title,
        'sco_count': manifest.scoList.length,
      },
    );

    return ApiResponse.created({
      'id': packageId,
      'title': manifest.title,
      'launch_url': manifest.launchUrl,
      'status': 'ready',
      'manifest': manifest.toJson(),
    }).toResponse();

  } on ScormValidationException catch (e) {
    // Mark package as error
    await supabase
        .from('scorm_packages')
        .update({
          'status': 'error',
          'error_message': e.message,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', packageId);

    throw ValidationException({'file': e.message});
  } catch (e) {
    // Mark package as error
    await supabase
        .from('scorm_packages')
        .update({
          'status': 'error',
          'error_message': e.toString(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', packageId);

    rethrow;
  }
}

/// GET /v1/scorm/packages
///
/// Lists SCORM packages with optional filters.
Future<Response> scormPackagesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.viewCourses)) {
    throw PermissionDeniedException('You do not have permission to view SCORM packages');
  }

  final params = req.url.queryParameters;
  final courseId = params['course_id'];
  final status = params['status'];
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20')?.clamp(1, 100) ?? 20;
  final offset = (page - 1) * perPage;

  var query = supabase
      .from('scorm_packages')
      .select('''
        id, title, file_name, scorm_version, status, 
        file_size_bytes, mastery_threshold, created_at,
        courses(id, title, course_code)
      ''')
      .eq('organization_id', auth.orgId);

  if (courseId != null) query = query.eq('course_id', courseId);
  if (status != null) query = query.eq('status', status);

  final packages = await query
      .order('created_at', ascending: false)
      .range(offset, offset + perPage - 1);

  final countQuery = supabase
      .from('scorm_packages')
      .select()
      .eq('organization_id', auth.orgId);
  
  if (courseId != null) countQuery.eq('course_id', courseId);
  if (status != null) countQuery.eq('status', status);
  
  final countResult = await countQuery.count();

  return ApiResponse.paginated(
    {'packages': packages},
    Pagination.compute(page: page, perPage: perPage, total: countResult.count),
  ).toResponse();
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
        courses(id, title, course_code)
      ''')
      .eq('id', packageId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (package == null) {
    throw NotFoundException('SCORM package not found');
  }

  return ApiResponse.ok({'package': package}).toResponse();
}

/// GET /v1/scorm/:id/launch
///
/// Gets launch parameters for a SCORM package.
/// Creates or resumes a SCORM session for the employee.
Future<Response> scormLaunchHandler(Request req) async {
  final packageId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (packageId == null || packageId.isEmpty) {
    throw ValidationException({'id': 'Package ID is required'});
  }

  final trainingRecordId = req.url.queryParameters['training_record_id'];

  // Get package
  final package = await supabase
      .from('scorm_packages')
      .select('id, organization_id, launch_url, status, title')
      .eq('id', packageId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (package == null) {
    throw NotFoundException('SCORM package not found');
  }

  if (package['status'] != 'ready') {
    throw ConflictException('SCORM package is not ready for launch (status: ${package['status']})');
  }

  // Get or create session using RPC
  final sessionResult = await supabase.rpc(
    'get_or_create_scorm_session',
    params: {
      'p_package_id': packageId,
      'p_employee_id': auth.employeeId,
      'p_training_record_id': trainingRecordId,
    },
  );

  if ((sessionResult as List).isEmpty) {
    throw Exception('Failed to create SCORM session');
  }

  final session = sessionResult[0];
  
  // Generate signed URLs
  final scormService = ScormService(supabase);
  final launchUrls = await scormService.getLaunchUrls(
    orgId: package['organization_id'] as String,
    packageId: packageId,
    launchUrl: package['launch_url'] as String,
    expiresInSeconds: 3600, // 1 hour
  );

  return ApiResponse.ok({
    'session_id': session['session_id'],
    'attempt_number': session['attempt_number'],
    'is_new_session': session['is_new_session'],
    'package': {
      'id': packageId,
      'title': package['title'],
    },
    'launch': launchUrls,
    'cmi_data': session['cmi_data'],
    'status': session['status'],
  }).toResponse();
}

/// POST /v1/scorm/:id/initialize
///
/// Initializes a SCORM session for CMI data tracking.
/// Called by the JS bridge on LMSInitialize().
/// Creates a new session if one doesn't exist, or returns existing session data.
Future<Response> scormInitializeHandler(Request req) async {
  final packageId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (packageId == null || packageId.isEmpty) {
    throw ValidationException({'id': 'Package ID is required'});
  }

  final sessionId = body['session_id'] as String?;

  // Verify package exists and is ready
  final package = await supabase
      .from('scorm_packages')
      .select('id, organization_id, status, mastery_threshold')
      .eq('id', packageId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (package == null) {
    throw NotFoundException('SCORM package not found');
  }

  if (package['status'] != 'ready') {
    throw ConflictException('SCORM package is not ready');
  }

  // If session_id provided, verify it exists and return its CMI data
  if (sessionId != null) {
    final session = await supabase
        .from('scorm_sessions')
        .select('id, cmi_data, status, attempt_number')
        .eq('id', sessionId)
        .eq('employee_id', auth.employeeId)
        .maybeSingle();

    if (session != null) {
      // Update last_accessed_at
      await supabase
          .from('scorm_sessions')
          .update({'last_accessed_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', sessionId);

      return ApiResponse.ok({
        'session_id': session['id'],
        'cmi_data': session['cmi_data'],
        'status': session['status'],
        'attempt_number': session['attempt_number'],
        'mastery_score': package['mastery_threshold'],
        'initialized': true,
      }).toResponse();
    }
  }

  // Create new session via RPC
  final sessionResult = await supabase.rpc(
    'get_or_create_scorm_session',
    params: {
      'p_package_id': packageId,
      'p_employee_id': auth.employeeId,
      'p_training_record_id': null,
    },
  );

  if ((sessionResult as List).isEmpty) {
    throw Exception('Failed to create SCORM session');
  }

  final session = sessionResult[0];

  return ApiResponse.ok({
    'session_id': session['session_id'],
    'cmi_data': session['cmi_data'],
    'status': session['status'],
    'attempt_number': session['attempt_number'],
    'mastery_score': package['mastery_threshold'],
    'initialized': true,
  }).toResponse();
}

/// POST /v1/scorm/:id/commit
///
/// Commits CMI data from the SCORM player.
/// Called by the JS bridge on LMSCommit() and LMSFinish().
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

  // Commit CMI data using RPC
  final result = await supabase.rpc(
    'commit_scorm_cmi',
    params: {
      'p_session_id': sessionId,
      'p_employee_id': auth.employeeId,
      'p_cmi_data': cmiData,
    },
  );

  if ((result as List).isEmpty) {
    throw Exception('Failed to commit CMI data');
  }

  final commitResult = result[0];
  final isCompleted = commitResult['is_completed'] as bool? ?? false;

  // If completed, create training record
  if (isCompleted) {
    try {
      await supabase.rpc(
        'complete_scorm_training',
        params: {
          'p_session_id': sessionId,
          'p_employee_id': auth.employeeId,
        },
      );

      // Publish completion event
      await EventPublisher.publish(
        supabase,
        eventType: 'training.completed',
        aggregateType: 'scorm_session',
        aggregateId: sessionId,
        orgId: auth.orgId,
        payload: {
          'package_id': packageId,
          'score': commitResult['score_raw'],
        },
      );
    } catch (e) {
      // Log but don't fail the commit - training completion can be retried
    }
  }

  return ApiResponse.ok({
    'status': commitResult['status'],
    'score': commitResult['score_raw'],
    'is_completed': isCompleted,
    'committed_at': DateTime.now().toIso8601String(),
  }).toResponse();
}

/// GET /v1/scorm/:id/progress
///
/// Gets progress for a specific SCORM package for the authenticated employee.
Future<Response> scormProgressHandler(Request req) async {
  final packageId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (packageId == null || packageId.isEmpty) {
    throw ValidationException({'id': 'Package ID is required'});
  }

  // Get all sessions for this package
  final sessions = await supabase
      .from('scorm_sessions')
      .select('''
        id, attempt_number, status, score_raw, total_time,
        created_at, last_accessed_at, completed_at
      ''')
      .eq('package_id', packageId)
      .eq('employee_id', auth.employeeId)
      .order('attempt_number', ascending: false);

  // Get best score and completion status
  double? bestScore;
  bool hasCompleted = false;
  
  for (final session in sessions as List) {
    if (session['status'] == 'completed') {
      hasCompleted = true;
    }
    final score = session['score_raw'] as num?;
    if (score != null && (bestScore == null || score > bestScore)) {
      bestScore = score.toDouble();
    }
  }

  return ApiResponse.ok({
    'package_id': packageId,
    'attempts': sessions.length,
    'best_score': bestScore,
    'has_completed': hasCompleted,
    'sessions': sessions,
  }).toResponse();
}

/// DELETE /v1/scorm/:id
///
/// Deletes a SCORM package and its storage files.
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

  // Get package for org validation
  final package = await supabase
      .from('scorm_packages')
      .select('id, organization_id')
      .eq('id', packageId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (package == null) {
    throw NotFoundException('SCORM package not found');
  }

  // Check for active sessions
  final activeSessions = await supabase
      .from('scorm_sessions')
      .select('id')
      .eq('package_id', packageId)
      .inFilter('status', ['incomplete', 'not_attempted'])
      .limit(1);

  if ((activeSessions as List).isNotEmpty) {
    throw ConflictException('Cannot delete package with active sessions');
  }

  // Delete storage content
  final scormService = ScormService(supabase);
  await scormService.deletePackageContent(
    orgId: auth.orgId,
    packageId: packageId,
  );

  // Delete database record (cascades to sessions)
  await supabase.from('scorm_packages').delete().eq('id', packageId);

  // Publish event
  await EventPublisher.publish(
    supabase,
    eventType: 'scorm.package_deleted',
    aggregateType: 'scorm_package',
    aggregateId: packageId,
    orgId: auth.orgId,
    payload: {},
  );

  return ApiResponse.noContent().toResponse();
}

// ---------------------------------------------------------------------------
// MULTIPART PARSING HELPERS
// ---------------------------------------------------------------------------

String? _extractBoundary(String contentType) {
  final match = RegExp(r'boundary=(.+)').firstMatch(contentType);
  return match?.group(1)?.replaceAll('"', '');
}

Map<String, _MultipartPart> _parseMultipart(Uint8List body, String boundary) {
  final parts = <String, _MultipartPart>{};
  final boundaryBytes = utf8.encode('--$boundary');
  
  int start = 0;
  while (true) {
    // Find start of next part
    final partStart = _indexOf(body, boundaryBytes, start);
    if (partStart == -1) break;
    
    // Find end of this part
    final nextBoundary = _indexOf(body, boundaryBytes, partStart + boundaryBytes.length);
    if (nextBoundary == -1) break;
    
    // Parse headers and content
    final partBytes = body.sublist(partStart + boundaryBytes.length + 2, nextBoundary - 2);
    final part = _parsePart(partBytes);
    
    if (part != null && part.name != null) {
      parts[part.name!] = part;
    }
    
    start = nextBoundary;
    
    // Check for end boundary
    final endBoundaryBytes = utf8.encode('--$boundary--');
    if (_startsWith(body, endBoundaryBytes, nextBoundary)) break;
  }
  
  return parts;
}

_MultipartPart? _parsePart(Uint8List bytes) {
  // Find header/body separator (double CRLF)
  final separator = utf8.encode('\r\n\r\n');
  final sepIndex = _indexOf(bytes, separator, 0);
  if (sepIndex == -1) return null;
  
  final headerBytes = bytes.sublist(0, sepIndex);
  final contentBytes = bytes.sublist(sepIndex + 4);
  
  final headers = utf8.decode(headerBytes);
  
  // Parse Content-Disposition
  String? name;
  String? filename;
  final dispMatch = RegExp(r'Content-Disposition:[^\r\n]+').firstMatch(headers);
  if (dispMatch != null) {
    final disp = dispMatch.group(0)!;
    final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(disp);
    final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(disp);
    name = nameMatch?.group(1);
    filename = filenameMatch?.group(1);
  }
  
  return _MultipartPart(
    name: name,
    filename: filename,
    bytes: Uint8List.fromList(contentBytes),
  );
}

int _indexOf(Uint8List haystack, List<int> needle, int start) {
  outer:
  for (int i = start; i <= haystack.length - needle.length; i++) {
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}

bool _startsWith(Uint8List data, List<int> prefix, int offset) {
  if (offset + prefix.length > data.length) return false;
  for (int i = 0; i < prefix.length; i++) {
    if (data[offset + i] != prefix[i]) return false;
  }
  return true;
}

class _MultipartPart {
  final String? name;
  final String? filename;
  final Uint8List bytes;
  
  _MultipartPart({this.name, this.filename, required this.bytes});
  
  String get asString => utf8.decode(bytes);
}
