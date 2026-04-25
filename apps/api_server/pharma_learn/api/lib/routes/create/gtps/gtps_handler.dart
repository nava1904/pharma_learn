import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/gtps
Future<Response> gtpsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.viewCourses, jwtPermissions: auth.permissions,
  );

  final q = QueryParams.fromRequest(req);
  final qp = req.url.queryParameters;

  var query = supabase.from('gtp_masters').select().eq('organization_id', auth.orgId);

  if (q.search != null && q.search!.isNotEmpty) {
    query = query.ilike('name', '%${q.search}%');
  }
  if (qp['status'] != null) query = query.eq('status', qp['status']!);
  if (qp['training_type'] != null) query = query.eq('training_type', qp['training_type']!);

  final offset = (q.page - 1) * q.perPage;
  final response = await query
      .order('created_at', ascending: q.sortOrder == 'asc')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  final total = response.count;
  return ApiResponse.paginated(
    response.data,
    Pagination(page: q.page, perPage: q.perPage, total: total,
        totalPages: total == 0 ? 1 : (total / q.perPage).ceil()),
  ).toResponse();
}

/// POST /v1/gtps
///
/// Body: `{name, unique_code?, short_description, schedule_type, training_type,
///         effective_from, effective_to?, is_qualification_gtp?}`
Future<Response> gtpsCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.createGtps, jwtPermissions: auth.permissions,
  );

  final body = await readJson(req);
  final name = requireString(body, 'name');
  final shortDescription = requireString(body, 'short_description');
  final scheduleType = requireString(body, 'schedule_type');
  final trainingType = requireString(body, 'training_type');
  final effectiveFrom = requireString(body, 'effective_from');

  String? uniqueCode = optionalString(body, 'unique_code');
  if (uniqueCode == null) {
    uniqueCode = await supabase.rpc(
      'generate_document_number',
      params: {'p_doc_type': 'gtp', 'p_org_id': auth.orgId},
    ) as String?;
  }

  final gtp = await supabase.from('gtp_masters').insert({
    'name': name,
    'unique_code': uniqueCode ?? name.toLowerCase().replaceAll(' ', '-'),
    'short_description': shortDescription,
    'schedule_category': scheduleType,
    'schedule_type': scheduleType,
    'training_type': trainingType,
    'effective_from': effectiveFrom,
    'effective_to': body['effective_to'],
    'is_qualification_gtp': body['is_qualification_gtp'] ?? false,
    'organization_id': auth.orgId,
    'created_by': auth.employeeId,
    'status': 'draft',
  }).select().single();

  return ApiResponse.created({'gtp': gtp}).toResponse();
}
