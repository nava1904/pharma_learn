import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/courses/:id/topics
Future<Response> courseTopicsListHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.viewCourses, jwtPermissions: auth.permissions,
  );

  final exists = await supabase.from('courses').select('id').eq('id', id).eq('organization_id', auth.orgId).maybeSingle();
  if (exists == null) throw NotFoundException('Course not found');

  final topics = await supabase
      .from('course_topics')
      .select('*, topics ( id, name, description )')
      .eq('course_id', id)
      .order('order_index', ascending: true);

  return ApiResponse.ok({'topics': topics}).toResponse();
}

/// POST /v1/courses/:id/topics
///
/// Body: `{topic_id, order_index?, is_mandatory?}`
Future<Response> courseTopicsAddHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.editCourses, jwtPermissions: auth.permissions,
  );

  final course = await supabase.from('courses').select('id, status').eq('id', id).eq('organization_id', auth.orgId).maybeSingle();
  if (course == null) throw NotFoundException('Course not found');

  final status = course['status'] as String? ?? '';
  if (!['draft', 'initiated', 'returned'].contains(status)) {
    throw ConflictException('Topics can only be modified in draft/initiated/returned state.');
  }

  final body = await readJson(req);
  final topicId = requireString(body, 'topic_id');

  final added = await supabase.from('course_topics').upsert({
    'course_id': id,
    'topic_id': topicId,
    'order_index': body['order_index'] ?? 0,
    'is_mandatory': body['is_mandatory'] ?? true,
  }, onConflict: 'course_id,topic_id').select('*, topics ( id, name )').single();

  return ApiResponse.created({'course_topic': added}).toResponse();
}
