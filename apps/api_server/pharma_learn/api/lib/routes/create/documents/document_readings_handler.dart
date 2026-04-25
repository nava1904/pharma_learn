import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';
import '../../../utils/query_parser.dart';

/// GET /v1/documents/:id/readings
///
/// Lists document_readings rows for this document (manager view or own view).
Future<Response> documentReadingsListHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewDocuments,
    jwtPermissions: auth.permissions,
  );

  final exists = await supabase
      .from('documents')
      .select('id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (exists == null) throw NotFoundException('Document not found');

  final q = QueryParams.fromRequest(req);
  final qp = req.url.queryParameters;
  final offset = (q.page - 1) * q.perPage;

  var query = supabase
      .from('document_readings')
      .select('*, employees ( id, first_name, last_name, employee_id )')
      .eq('document_id', id)
      .eq('organization_id', auth.orgId);

  if (qp['employee_id'] != null) {
    query = query.eq('employee_id', qp['employee_id']!);
  }
  if (qp['status'] != null) {
    query = query.eq('status', qp['status']!);
  }

  final response = await query
      .order('assigned_at', ascending: false)
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

/// POST /v1/documents/:id/readings
///
/// Assigns a document reading to the calling employee (or a specified employee).
/// Typically called by a workflow or manager to assign reading obligations.
///
/// Body: `{employee_id?, document_version_id?, due_date?, obligation_id?}`
Future<Response> documentReadingsCreateHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final document = await supabase
      .from('documents')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (document == null) throw NotFoundException('Document not found');

  final docStatus = document['status'] as String? ?? '';
  if (!['active', 'pending_approval'].contains(docStatus)) {
    throw ConflictException(
      'Document readings can only be assigned for active or pending-approval documents.',
    );
  }

  final body = await readJson(req);
  final employeeId =
      optionalString(body, 'employee_id') ?? auth.employeeId;

  // Upsert to handle re-assignment of the same document+version to same employee
  final reading = await supabase
      .from('document_readings')
      .upsert({
        'document_id': id,
        'employee_id': employeeId,
        'document_version_id': body['document_version_id'],
        'due_date': body['due_date'],
        'obligation_id': body['obligation_id'],
        'status': 'ASSIGNED',
        'organization_id': auth.orgId,
        'plant_id': auth.plantId,
        'created_by': auth.employeeId,
      }, onConflict: 'document_id,document_version_id,employee_id')
      .select()
      .single();

  return ApiResponse.created({'reading': reading}).toResponse();
}
