import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/reports/:templateId/run
///
/// Enqueues a report generation job.
/// Returns the report_id immediately; client polls for status.
///
/// Body:
/// ```json
/// {
///   "parameters": {
///     "employee_id": "uuid",
///     "as_of": "2026-04-01"
///   }
/// }
/// ```
///
/// Response 202:
/// ```json
/// {
///   "report_id": "uuid",
///   "status": "queued",
///   "template_id": "employee_training_dossier"
/// }
/// ```
Future<Response> reportRunHandler(Request req) async {
  final templateId = req.rawPathParameters[#templateId];
  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'templateId': 'Template ID is required'});
  }

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify template exists
  final template = ReportTemplate.byId(templateId);
  if (template == null) {
    throw NotFoundException('Report template not found: $templateId');
  }

  // Verify permission
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  // Additional permission checks for audit reports
  final canViewAudit = auth.hasPermission(Permissions.viewAudit);
  if (template.category == 'audit' && !canViewAudit) {
    throw PermissionDeniedException(
      'You do not have permission to run audit reports',
    );
  }

  // Parse request body
  final body = await readJson(req);
  final parameters = body['parameters'] as Map<String, dynamic>? ?? {};

  // Validate required parameters
  for (final param in template.parameters) {
    if (param.required && !parameters.containsKey(param.name)) {
      throw ValidationException({
        param.name: '${param.label} is required',
      });
    }
  }

  // Special case: employee_training_dossier for own record
  // Regular employees can only request their own dossier
  if (templateId == 'employee_training_dossier') {
    final requestedEmployeeId = parameters['employee_id'] as String?;
    final canExport = auth.hasPermission(Permissions.exportReports);
    
    if (!canExport && requestedEmployeeId != auth.employeeId) {
      throw PermissionDeniedException(
        'You can only request your own training dossier',
      );
    }
  }

  // Get organization details for report number generation
  final org = await supabase
      .from('organizations')
      .select('id, short_code')
      .eq('id', auth.orgId)
      .single();

  final orgCode = org['short_code'] as String? ?? 'XXX';

  // Get numbering scheme for reports
  final schemeResult = await supabase
      .from('numbering_schemes')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('entity_type', 'report')
      .eq('is_default', true)
      .eq('is_active', true)
      .maybeSingle();

  String? reportNumber;
  if (schemeResult != null) {
    final schemeId = schemeResult['id'] as String;
    final numberResult = await supabase.rpc(
      'get_next_number',
      params: {
        'p_scheme_id': schemeId,
        'p_org_code': orgCode,
      },
    );
    reportNumber = numberResult as String?;
  }

  // Determine priority
  final priority = template.defaultPriority;

  // Calculate report period (for compliance_reports table compatibility)
  final now = DateTime.now();
  final dateFrom = parameters['date_from'] as String?;
  final dateTo = parameters['date_to'] as String?;
  final asOf = parameters['as_of'] as String?;
  
  final periodStart = dateFrom ?? asOf ?? now.toIso8601String().split('T')[0];
  final periodEnd = dateTo ?? asOf ?? now.toIso8601String().split('T')[0];

  // Write audit trail entry
  final auditTrail = await supabase
      .from('audit_trails')
      .insert({
        'organization_id': auth.orgId,
        'employee_id': auth.employeeId,
        'action': 'REPORT_GENERATED',
        'entity_type': 'compliance_report',
        'event_category': 'REPORT',
        'new_values': {
          'template_id': templateId,
          'parameters': parameters,
        },
        'ip_address': req.headers['x-forwarded-for']?.first,
        'user_agent': req.headers['user-agent']?.first,
      })
      .select('id')
      .single();

  final auditTrailId = auditTrail['id'] as String;

  // Insert into compliance_reports with queued status
  final report = await supabase
      .from('compliance_reports')
      .insert({
        'organization_id': auth.orgId,
        'report_type': templateId,
        'template_id': templateId,
        'report_name': template.name,
        'report_period_start': periodStart,
        'report_period_end': periodEnd,
        'generated_by': auth.employeeId,
        'generated_at': now.toUtc().toIso8601String(),
        'parameters': parameters,
        'status': 'queued',
        'progress_percent': 0,
        'priority': priority,
        'report_number': reportNumber,
        'audit_trail_id': auditTrailId,
        'report_data': <String, dynamic>{}, // Will be populated by generator
      })
      .select('id, status, report_number, generated_at')
      .single();

  // Return 202 Accepted with report info
  return Response(
    202,
    body: Body.fromString(
      '{"data": ${_jsonEncode({
        'report_id': report['id'],
        'status': report['status'],
        'report_number': report['report_number'],
        'template_id': templateId,
        'requested_at': report['generated_at'],
      })}}',
      mimeType: MimeType.json,
    ),
  );
}

String _jsonEncode(Object? value) {
  return jsonEncode(value);
}
