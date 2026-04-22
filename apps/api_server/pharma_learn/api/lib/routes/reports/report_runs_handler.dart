import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/reports/runs
///
/// Lists report generation history with filtering.
/// Query params:
/// - `template_id`: Filter by template type
/// - `status`: Filter by status (queued, processing, ready, failed)
/// - `date_from`: Reports requested after this date
/// - `date_to`: Reports requested before this date
/// - `page`: Page number (default 1)
/// - `per_page`: Results per page (default 20, max 100)
Future<Response> reportRunsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify permission
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  // Parse query params
  final templateId = req.url.queryParameters['template_id'];
  final status = req.url.queryParameters['status'];
  final dateFrom = req.url.queryParameters['date_from'];
  final dateTo = req.url.queryParameters['date_to'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  var perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  if (perPage > 100) perPage = 100;

  // Determine scope based on permissions
  final canExport = auth.hasPermission(Permissions.exportReports);

  // Build query
  var query = supabase
      .from('compliance_reports')
      .select('''
        id,
        template_id,
        report_name,
        status,
        progress_percent,
        report_number,
        generated_at,
        completed_at,
        parameters,
        generated_by,
        employees!generated_by ( id, first_name, last_name, employee_number )
      ''')
      .eq('organization_id', auth.orgId);

  // If user doesn't have export permission, only show their own reports
  if (!canExport) {
    query = query.eq('generated_by', auth.employeeId);
  }

  // Apply filters
  if (templateId != null) {
    query = query.eq('template_id', templateId);
  }
  if (status != null) {
    query = query.eq('status', status);
  }
  if (dateFrom != null) {
    query = query.gte('generated_at', dateFrom);
  }
  if (dateTo != null) {
    query = query.lte('generated_at', dateTo);
  }

  // Get total count for pagination
  final countQuery = supabase
      .from('compliance_reports')
      .select('id')
      .eq('organization_id', auth.orgId);
  
  // Apply same filters to count query
  var countFiltered = countQuery;
  if (!canExport) {
    countFiltered = countFiltered.eq('generated_by', auth.employeeId);
  }
  if (templateId != null) {
    countFiltered = countFiltered.eq('template_id', templateId);
  }
  if (status != null) {
    countFiltered = countFiltered.eq('status', status);
  }
  if (dateFrom != null) {
    countFiltered = countFiltered.gte('generated_at', dateFrom);
  }
  if (dateTo != null) {
    countFiltered = countFiltered.lte('generated_at', dateTo);
  }

  final countResult = await countFiltered;
  final total = countResult.length;

  // Get paginated results
  final reports = await query
      .order('generated_at', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  return ApiResponse.paginated(
    {'reports': reports},
    Pagination.compute(
      page: page,
      perPage: perPage,
      total: total,
    ),
  ).toResponse();
}
