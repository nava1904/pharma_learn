import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/documents
Future<Response> documentsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewDocuments,
    jwtPermissions: auth.permissions,
  );

  final q = QueryParams.fromRequest(req);
  final qp = req.url.queryParameters;

  var query = supabase
      .from('documents')
      .select('*, employees!owner_id ( id, first_name, last_name )')
      .eq('organization_id', auth.orgId);

  if (q.search != null && q.search!.isNotEmpty) {
    query = query.ilike('name', '%${q.search}%');
  }
  if (qp['status'] != null) {
    query = query.eq('status', qp['status']!);
  }
  if (qp['document_type'] != null) {
    query = query.eq('document_type', qp['document_type']!);
  }
  if (qp['department_id'] != null) {
    query = query.eq('department_id', qp['department_id']!);
  }

  final sortColumn = q.sortBy ?? 'created_at';
  final offset = (q.page - 1) * q.perPage;

  final response = await query
      .order(sortColumn, ascending: q.sortOrder == 'asc')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  final total = response.count;
  return ApiResponse.paginated(
    response.data,
    Pagination(
      page: q.page,
      perPage: q.perPage,
      total: total,
      totalPages: total == 0 ? 1 : (total / q.perPage).ceil(),
    ),
  ).toResponse();
}

/// POST /v1/documents
///
/// Body: `{name, unique_code?, document_type, description?, department_id?,
///         owner_id?, effective_from?, effective_until?, next_review?, sop_number?}`
Future<Response> documentsCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.createDocuments,
    jwtPermissions: auth.permissions,
  );

  final body = await readJson(req);
  final name = requireString(body, 'name');
  final documentType = requireString(body, 'document_type');

  // Auto-generate unique_code via DB numbering scheme if not supplied
  String? uniqueCode = optionalString(body, 'unique_code');
  if (uniqueCode == null) {
    uniqueCode = await supabase.rpc(
      'generate_document_number',
      params: {'p_doc_type': documentType, 'p_org_id': auth.orgId},
    ) as String?;
  }

  final document = await supabase
      .from('documents')
      .insert({
        'name': name,
        'unique_code': uniqueCode ?? name.toLowerCase().replaceAll(' ', '-'),
        'document_type': documentType,
        'description': body['description'],
        'department_id': body['department_id'],
        'owner_id': body['owner_id'] ?? auth.employeeId,
        'effective_from': body['effective_from'],
        'effective_until': body['effective_until'],
        'next_review': body['next_review'],
        'sop_number': body['sop_number'],
        'organization_id': auth.orgId,
        'plant_id': auth.plantId,
        'created_by': auth.employeeId,
        'status': 'draft',
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'document',
    aggregateId: document['id'] as String,
    eventType: EventTypes.documentCreated,
    payload: {
      'name': name,
      'document_type': documentType,
      'created_by': auth.employeeId,
    },
    orgId: auth.orgId,
  );

  return ApiResponse.created({'document': document}).toResponse();
}
