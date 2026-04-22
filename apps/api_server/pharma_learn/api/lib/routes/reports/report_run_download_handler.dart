import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../utils/param_helpers.dart';

/// GET /v1/reports/runs/:id/download
///
/// Returns a signed URL for downloading the report PDF or CSV.
/// Query param: `format=pdf|csv` (default: pdf)
/// Signed URL TTL: 60 minutes
///
/// Response 302: Redirect to signed Supabase Storage URL
/// Response 404: Report not found or not ready
/// Response 400: Requested format not available
Future<Response> reportRunDownloadHandler(Request req) async {
  final reportId = parsePathUuid(req.rawPathParameters[#id]);
  final format = req.url.queryParameters['format'] ?? 'pdf';
  
  if (format != 'pdf' && format != 'csv') {
    throw ValidationException({
      'format': 'Format must be "pdf" or "csv"',
    });
  }

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
        status,
        pdf_url,
        excel_url,
        generated_by,
        template_id,
        report_number
      ''')
      .eq('id', reportId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (report == null) {
    throw NotFoundException('Report not found');
  }

  // Verify access
  final canExport = auth.hasPermission(Permissions.exportReports);
  final isRequester = report['generated_by'] == auth.employeeId;
  
  if (!canExport && !isRequester) {
    throw PermissionDeniedException(
      'You do not have permission to download this report',
    );
  }

  // Check status
  if (report['status'] != 'ready' && report['status'] != 'generated') {
    throw ConflictException(
      'Report is not ready for download. Current status: ${report['status']}',
    );
  }

  // Get the storage path
  final storagePath = format == 'pdf' 
      ? report['pdf_url'] as String?
      : report['excel_url'] as String?;

  if (storagePath == null || storagePath.isEmpty) {
    throw NotFoundException(
      'Report $format file is not available',
    );
  }

  // Generate signed URL (60-minute TTL)
  // The pdf_url/excel_url stores the storage path, not a full URL
  // We need to generate a signed URL from Supabase Storage
  final signedUrl = await supabase.storage
      .from('pharmalearn-files')
      .createSignedUrl(storagePath, 3600); // 60 minutes in seconds

  // Return 302 redirect to the signed URL
  return Response(
    302,
    headers: Headers.build((h) {
      h['location'] = [signedUrl];
      h['cache-control'] = ['no-cache, no-store, must-revalidate'];
    }),
  );
}
