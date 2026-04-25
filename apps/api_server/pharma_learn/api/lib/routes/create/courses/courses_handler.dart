import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/courses
Future<Response> coursesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCourses,
    jwtPermissions: auth.permissions,
  );

  final q = QueryParams.fromRequest(req);
  final qp = req.url.queryParameters;

  var query = supabase.from('courses').select().eq('organization_id', auth.orgId);

  if (q.search != null && q.search!.isNotEmpty) {
    query = query.ilike('name', '%${q.search}%');
  }
  if (qp['status'] != null) query = query.eq('status', qp['status']!);
  if (qp['course_type'] != null) query = query.eq('course_type', qp['course_type']!);

  final sortColumn = q.sortBy ?? 'created_at';
  final offset = (q.page - 1) * q.perPage;

  final response = await query
      .order(sortColumn, ascending: q.sortOrder == 'asc')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  final total = response.count;
  return ApiResponse.paginated(
    response.data,
    Pagination(page: q.page, perPage: q.perPage, total: total,
        totalPages: total == 0 ? 1 : (total / q.perPage).ceil()),
  ).toResponse();
}

/// POST /v1/courses
///
/// Body: `{name, unique_code?, description?, course_type?, pass_mark?,
///         max_attempts?, certificate_validity_months?, assessment_required?}`
Future<Response> coursesCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.createCourses,
    jwtPermissions: auth.permissions,
  );

  final body = await readJson(req);
  final name = requireString(body, 'name');

  String? uniqueCode = optionalString(body, 'unique_code');
  if (uniqueCode == null) {
    uniqueCode = await supabase.rpc(
      'generate_document_number',
      params: {'p_doc_type': 'course', 'p_org_id': auth.orgId},
    ) as String?;
  }

  final course = await supabase.from('courses').insert({
    'name': name,
    'unique_code': uniqueCode ?? name.toLowerCase().replaceAll(' ', '-'),
    'description': body['description'],
    'course_type': body['course_type'] ?? 'one_time',
    'pass_mark': body['pass_mark'] ?? 70,
    'max_attempts': body['max_attempts'] ?? 3,
    'assessment_required': body['assessment_required'] ?? true,
    'certificate_validity_months': body['certificate_validity_months'],
    'estimated_duration_minutes': body['estimated_duration_minutes'],
    'organization_id': auth.orgId,
    'plant_id': auth.plantId,
    'created_by': auth.employeeId,
    'status': 'draft',
  }).select().single();

  await OutboxService(supabase).publish(
    aggregateType: 'course',
    aggregateId: course['id'] as String,
    eventType: EventTypes.courseCreated,
    payload: {'name': name, 'created_by': auth.employeeId},
    orgId: auth.orgId,
  );

  return ApiResponse.created({'course': course}).toResponse();
}
