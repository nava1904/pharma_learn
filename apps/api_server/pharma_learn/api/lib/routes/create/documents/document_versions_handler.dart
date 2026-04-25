import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';
import '../../../utils/query_parser.dart';

/// GET /v1/documents/:id/versions
///
/// Returns version history for a document, ordered newest-first.
Future<Response> documentVersionsHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewDocuments,
    jwtPermissions: auth.permissions,
  );

  // Verify document belongs to org
  final exists = await supabase
      .from('documents')
      .select('id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (exists == null) throw NotFoundException('Document not found');

  final q = QueryParams.fromRequest(req);
  final offset = (q.page - 1) * q.perPage;

  final response = await supabase
      .from('document_versions')
      .select('*, employees!created_by ( id, first_name, last_name ), employees!approved_by ( id, first_name, last_name )')
      .eq('document_id', id)
      .order('created_at', ascending: false)
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
