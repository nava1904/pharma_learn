import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../utils/param_helpers.dart';

/// GET /v1/reports/runs/:id
///
/// Returns the status and progress of a report generation job.
/// Used for polling until status = 'ready'.
///
/// Response:
/// ```json
/// {
///   "report_id": "uuid",
///   "status": "processing",
///   "progress_percent": 60,
///   "template_id": "employee_training_dossier",
///   "report_number": "ALFA-RPT-2026-00142",
///   "requested_at": "2026-04-26T10:00:00Z",
///   "completed_at": null,
///   "error_message": null
/// }
/// ```
Future<Response> reportRunStatusHandler(Request req) async {
  final reportId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify permission
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  // Fetch report
  final report = await supabase
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
        error_message,
        parameters,
        generated_by,
        pdf_url,
        excel_url,
        file_size_bytes
      ''')
      .eq('id', reportId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (report == null) {
    throw NotFoundException('Report not found');
  }

  // Verify access: user must be the requester or have exportReports permission
  final canExport = auth.hasPermission(Permissions.exportReports);
  final isRequester = report['generated_by'] == auth.employeeId;
  
  if (!canExport && !isRequester) {
    throw PermissionDeniedException(
      'You do not have permission to view this report',
    );
  }

  return ApiResponse.ok({
    'report_id': report['id'],
    'template_id': report['template_id'],
    'report_name': report['report_name'],
    'status': report['status'],
    'progress_percent': report['progress_percent'],
    'report_number': report['report_number'],
    'requested_at': report['generated_at'],
    'completed_at': report['completed_at'],
    'error_message': report['error_message'],
    'parameters': report['parameters'],
    'has_pdf': report['pdf_url'] != null,
    'has_csv': report['excel_url'] != null,
    'file_size_bytes': report['file_size_bytes'],
  }).toResponse();
}
