import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/reports/templates/:id
///
/// Returns detailed information about a specific report template,
/// including its full parameter schema.
Future<Response> reportTemplateGetHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify user has permission to view reports
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  // Look up template
  final template = ReportTemplate.byId(templateId);
  if (template == null) {
    throw NotFoundException('Report template not found: $templateId');
  }

  // Verify user has access to this specific template
  // (same logic as list handler)
  final canViewAudit = auth.hasPermission(Permissions.viewAudit);
  if (template.category == 'audit' && !canViewAudit) {
    throw PermissionDeniedException(
      'You do not have permission to access audit reports',
    );
  }

  return ApiResponse.ok({
    'template': template.toJson(),
  }).toResponse();
}
