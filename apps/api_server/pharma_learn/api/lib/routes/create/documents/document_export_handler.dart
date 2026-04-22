import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/create/documents/:id/export
///
/// Exports a document as PDF with full e-signature history.
/// 21 CFR §11.10(b) — printable format for FDA inspection.
///
/// Query params:
/// - format: pdf (default) | csv
/// - include_audit: true (default) | false
Future<Response> documentExportHandler(Request req) async {
  final docId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final format = req.url.queryParameters['format'] ?? 'pdf';
  final includeAudit = req.url.queryParameters['include_audit'] != 'false';

  // Permission check
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewDocuments,
    jwtPermissions: auth.permissions,
  );

  // Load document with all related data
  final doc = await supabase
      .from('documents')
      .select('''
        id, document_number, title, description, status, version,
        effective_date, expiry_date, created_at, updated_at,
        document_types(name),
        employees!created_by(first_name, last_name, employee_number),
        document_control(*)
      ''')
      .eq('id', docId)
      .maybeSingle();

  if (doc == null) {
    throw NotFoundException('Document not found');
  }

  // Get e-signature history
  final esignatures = await supabase
      .from('electronic_signatures')
      .select('''
        id, meaning, reason, signed_at,
        employees(first_name, last_name, employee_number, job_title)
      ''')
      .eq('entity_type', 'document')
      .eq('entity_id', docId)
      .order('signed_at', ascending: true);

  // Get approval history
  final approvals = await supabase
      .from('approval_steps')
      .select('''
        step_order, status, approved_at, comments,
        employees!approver_id(first_name, last_name, employee_number),
        roles(name)
      ''')
      .eq('entity_type', 'document')
      .eq('entity_id', docId)
      .order('step_order', ascending: true);

  // Get audit trail if requested
  List? auditTrail;
  if (includeAudit) {
    auditTrail = await supabase
        .from('audit_trails')
        .select('''
          action, event_category, old_values, new_values, created_at,
          employees!performed_by(first_name, last_name, employee_number)
        ''')
        .eq('entity_type', 'document')
        .eq('entity_id', docId)
        .order('created_at', ascending: true);
  }

  // For PDF, call Edge Function to generate
  if (format == 'pdf') {
    final pdfResult = await supabase.functions.invoke(
      'generate-document-export',
      body: {
        'document': doc,
        'esignatures': esignatures,
        'approvals': approvals,
        'audit_trail': auditTrail,
        'exported_by': auth.employeeId,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    if (pdfResult.data == null || pdfResult.data['url'] == null) {
      throw ConflictException('Failed to generate PDF export');
    }

    return ApiResponse.ok({
      'download_url': pdfResult.data['url'],
      'expires_in': 300,
      'format': 'pdf',
    }).toResponse();
  }

  // For JSON/CSV, return data directly
  return ApiResponse.ok({
    'document': doc,
    'esignatures': esignatures,
    'approvals': approvals,
    'audit_trail': auditTrail,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'exported_by': auth.employeeId,
  }).toResponse();
}
