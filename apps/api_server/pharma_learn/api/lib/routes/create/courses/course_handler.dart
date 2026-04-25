import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/courses/:id
Future<Response> courseGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.viewCourses, jwtPermissions: auth.permissions,
  );

  final course = await supabase
      .from('courses')
      .select('*, employees!created_by ( id, first_name, last_name ), course_topics ( topic_id, order_index, topics ( id, name ) )')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (course == null) throw NotFoundException('Course not found');
  return ApiResponse.ok({'course': course}).toResponse();
}

/// PATCH /v1/courses/:id
Future<Response> coursePatchHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.editCourses, jwtPermissions: auth.permissions,
  );

  final course = await supabase
      .from('courses').select('id, status').eq('id', id).eq('organization_id', auth.orgId).maybeSingle();

  if (course == null) throw NotFoundException('Course not found');

  final status = course['status'] as String? ?? '';
  if (!['draft', 'initiated', 'returned'].contains(status)) {
    throw ConflictException('Course cannot be edited in status "$status".');
  }

  final body = await readJson(req);
  final editableFields = [
    'name', 'description', 'course_type', 'pass_mark', 'max_attempts',
    'assessment_required', 'certificate_validity_months', 'estimated_duration_minutes',
    'thumbnail_url', 'sop_number', 'effective_date', 'self_study',
  ];
  final updates = <String, dynamic>{};
  for (final f in editableFields) {
    if (body.containsKey(f)) updates[f] = body[f];
  }

  if (updates.isEmpty) return ApiResponse.ok({'course': course}).toResponse();

  final updated = await supabase
      .from('courses').update(updates).eq('id', id).eq('organization_id', auth.orgId).select().single();

  return ApiResponse.ok({'course': updated}).toResponse();
}
