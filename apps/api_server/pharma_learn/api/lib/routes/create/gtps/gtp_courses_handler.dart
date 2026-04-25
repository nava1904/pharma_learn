import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/gtps/:id/courses
Future<Response> gtpCoursesListHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.viewCourses, jwtPermissions: auth.permissions,
  );

  final exists = await supabase.from('gtp_masters').select('id').eq('id', id).eq('organization_id', auth.orgId).maybeSingle();
  if (exists == null) throw NotFoundException('GTP not found');

  final courses = await supabase
      .from('gtp_courses')
      .select('*, courses ( id, name, unique_code, course_type, estimated_duration_minutes )')
      .eq('gtp_id', id)
      .order('sequence_number', ascending: true);

  return ApiResponse.ok({'courses': courses}).toResponse();
}

/// POST /v1/gtps/:id/courses
///
/// Body: `{course_id, sequence_number?, is_mandatory?}`
Future<Response> gtpCoursesAddHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.editGtps, jwtPermissions: auth.permissions,
  );

  final gtp = await supabase.from('gtp_masters').select('id, status').eq('id', id).eq('organization_id', auth.orgId).maybeSingle();
  if (gtp == null) throw NotFoundException('GTP not found');

  final status = gtp['status'] as String? ?? '';
  if (!['draft', 'initiated', 'returned'].contains(status)) {
    throw ConflictException('Courses can only be added to GTP in draft/initiated/returned state.');
  }

  final body = await readJson(req);
  final courseId = requireString(body, 'course_id');

  final added = await supabase.from('gtp_courses').upsert({
    'gtp_id': id,
    'course_id': courseId,
    'sequence_number': body['sequence_number'] ?? 1,
    'is_mandatory': body['is_mandatory'] ?? true,
  }, onConflict: 'gtp_id,course_id').select('*, courses ( id, name )').single();

  return ApiResponse.created({'gtp_course': added}).toResponse();
}
