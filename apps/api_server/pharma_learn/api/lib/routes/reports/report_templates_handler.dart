import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/reports/templates
///
/// Returns the list of available report templates with their metadata.
/// Used by the UI to populate the report selection dropdown.
Future<Response> reportTemplatesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify user has permission to view reports
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  final templates = ReportTemplate.all;

  // Filter templates based on permissions
  // Users with exportReports can access all templates
  // Users with only viewReports get limited access
  final canExport = auth.hasPermission(Permissions.exportReports);
  final canViewAudit = auth.hasPermission(Permissions.viewAudit);
  final canManageTraining = auth.hasPermission(Permissions.manageTraining);

  final filtered = templates.where((t) {
    // Audit reports require viewAudit permission
    if (t.category == 'audit' && !canViewAudit) {
      return false;
    }
    // Full export permission grants access to all templates
    if (canExport) {
      return true;
    }
    // Training managers can access training-related reports
    if (canManageTraining) {
      return ['assessment_performance_report', 'overdue_training_report',
              'department_compliance_summary'].contains(t.id);
    }
    // Regular employees can only request their own dossier
    return t.id == 'employee_training_dossier';
  }).toList();

  return ApiResponse.ok({
    'templates': filtered.map((t) => t.toJson()).toList(),
  }).toResponse();
}
