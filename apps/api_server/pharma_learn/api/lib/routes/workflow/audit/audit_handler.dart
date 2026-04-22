import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/audit/:entityType/:entityId
///
/// Retrieves audit trail for a specific entity.
/// Implements 21 CFR §11.10(e) - Audit trails.
Future<Response> auditEntityHandler(Request req) async {
  final entityType = req.rawPathParameters[#entityType];
  final entityId = req.rawPathParameters[#entityId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (entityType == null || entityType.isEmpty) {
    throw ValidationException({'entityType': 'Entity type is required'});
  }
  if (entityId == null || entityId.isEmpty) {
    throw ValidationException({'entityId': 'Entity ID is required'});
  }

  // Permission check - only admins and QA can view full audit trails
  if (!auth.hasPermission('audit.view')) {
    throw PermissionDeniedException('You do not have permission to view audit trails');
  }

  final trails = await supabase
      .from('audit_trails')
      .select('''
        id, entity_type, entity_id, action, event_category,
        old_values, new_values, details, ip_address, user_agent,
        performed_by, created_at,
        performer:employees!audit_trails_performed_by_fkey (
          id, full_name, employee_number
        )
      ''')
      .eq('entity_type', entityType)
      .eq('entity_id', entityId)
      .eq('organization_id', auth.orgId)
      .order('created_at', ascending: false);

  return ApiResponse.ok({
    'entity_type': entityType,
    'entity_id': entityId,
    'audit_trails': trails,
    'count': trails.length,
  }).toResponse();
}

/// GET /v1/audit/search
///
/// Searches audit trails with filters.
/// Query params: entity_type, action, performed_by, from_date, to_date, page, per_page
Future<Response> auditSearchHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission('audit.view')) {
    throw PermissionDeniedException('You do not have permission to view audit trails');
  }

  final queryParams = req.url.queryParameters;
  final entityType = queryParams['entity_type'];
  final action = queryParams['action'];
  final performedBy = queryParams['performed_by'];
  final fromDate = queryParams['from_date'];
  final toDate = queryParams['to_date'];
  final page = int.tryParse(queryParams['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(queryParams['per_page'] ?? '50') ?? 50;

  var query = supabase
      .from('audit_trails')
      .select('''
        id, entity_type, entity_id, action, event_category,
        details, performed_by, created_at,
        performer:employees!audit_trails_performed_by_fkey (
          id, full_name, employee_number
        )
      ''')
      .eq('organization_id', auth.orgId);

  if (entityType != null && entityType.isNotEmpty) {
    query = query.eq('entity_type', entityType);
  }
  if (action != null && action.isNotEmpty) {
    query = query.eq('action', action);
  }
  if (performedBy != null && performedBy.isNotEmpty) {
    query = query.eq('performed_by', performedBy);
  }
  if (fromDate != null && fromDate.isNotEmpty) {
    query = query.gte('created_at', fromDate);
  }
  if (toDate != null && toDate.isNotEmpty) {
    query = query.lte('created_at', toDate);
  }

  final offset = (page - 1) * perPage;
  final trails = await query
      .order('created_at', ascending: false)
      .range(offset, offset + perPage - 1);

  return ApiResponse.ok({
    'audit_trails': trails,
    'page': page,
    'per_page': perPage,
    'count': trails.length,
  }).toResponse();
}

/// GET /v1/workflow/audit/:entityType/:entityId/export
///
/// Exports audit trail in CSV or PDF format.
/// Implements 21 CFR §11.10(b) - printable/retrievable format.
/// Query params: format (csv|pdf)
Future<Response> auditExportHandler(Request req) async {
  final entityType = req.rawPathParameters[#entityType];
  final entityId = req.rawPathParameters[#entityId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (entityType == null || entityType.isEmpty) {
    throw ValidationException({'entityType': 'Entity type is required'});
  }
  if (entityId == null || entityId.isEmpty) {
    throw ValidationException({'entityId': 'Entity ID is required'});
  }

  if (!auth.hasPermission('audit.export')) {
    throw PermissionDeniedException('You do not have permission to export audit trails');
  }

  final format = req.url.queryParameters['format'] ?? 'csv';
  if (format != 'csv' && format != 'pdf') {
    throw ValidationException({'format': 'Format must be csv or pdf'});
  }

  final trails = await supabase
      .from('audit_trails')
      .select('''
        id, entity_type, entity_id, action, event_category,
        old_values, new_values, details, ip_address,
        performed_by, created_at,
        performer:employees!audit_trails_performed_by_fkey (
          full_name, employee_number
        )
      ''')
      .eq('entity_type', entityType)
      .eq('entity_id', entityId)
      .eq('organization_id', auth.orgId)
      .order('created_at', ascending: true);

  if (format == 'csv') {
    final csv = _generateAuditCsv(trails, entityType, entityId);
    
    // Log export in audit trail (audit of audit)
    await supabase.from('audit_trails').insert({
      'entity_type': 'audit_export',
      'entity_id': entityId,
      'action': 'AUDIT_EXPORTED',
      'event_category': 'COMPLIANCE',
      'performed_by': auth.employeeId,
      'organization_id': auth.orgId,
      'details': jsonEncode({
        'exported_entity_type': entityType,
        'exported_entity_id': entityId,
        'format': format,
        'records_count': trails.length,
      }),
    });

    return Response(
      200,
      body: Body.fromString(
        csv,
        mimeType: MimeType('text', 'csv'),
      ),
      headers: Headers.build((h) {
        h['content-disposition'] = [
          'attachment; filename="audit_${entityType}_${entityId}_${DateTime.now().millisecondsSinceEpoch}.csv"'
        ];
      }),
    );
  } else {
    // PDF generation via Edge Function
    final pdfUrl = await _generateAuditPdf(supabase, trails, entityType, entityId, auth);
    
    return ApiResponse.ok({
      'download_url': pdfUrl,
      'expires_in': 3600,
      'format': 'pdf',
      'records_count': trails.length,
    }).toResponse();
  }
}

String _generateAuditCsv(List<dynamic> trails, String entityType, String entityId) {
  final buffer = StringBuffer();
  
  // Header
  buffer.writeln('PharmaLearn Audit Trail Export');
  buffer.writeln('Entity Type,$entityType');
  buffer.writeln('Entity ID,$entityId');
  buffer.writeln('Export Date,${DateTime.now().toUtc().toIso8601String()}');
  buffer.writeln('21 CFR Part 11 Compliant,Yes');
  buffer.writeln('');
  buffer.writeln('ID,Timestamp,Action,Category,Performed By,Employee Number,Details,IP Address');
  
  // Data rows
  for (final trail in trails) {
    final performer = trail['performer'] as Map<String, dynamic>?;
    final details = trail['details']?.toString().replaceAll(',', ';') ?? '';
    
    buffer.writeln([
      trail['id'],
      trail['created_at'],
      trail['action'],
      trail['event_category'],
      performer?['full_name'] ?? 'Unknown',
      performer?['employee_number'] ?? 'N/A',
      '"$details"',
      trail['ip_address'] ?? 'N/A',
    ].join(','));
  }
  
  return buffer.toString();
}

Future<String> _generateAuditPdf(
  dynamic supabase,
  List<dynamic> trails,
  String entityType,
  String entityId,
  AuthContext auth,
) async {
  // Call Edge Function to generate PDF
  final response = await supabase.functions.invoke(
    'generate-audit-pdf',
    body: {
      'entity_type': entityType,
      'entity_id': entityId,
      'trails': trails,
      'generated_by': auth.employeeId,
      'organization_id': auth.orgId,
    },
  );
  
  if (response.status != 200) {
    throw Exception('Failed to generate PDF');
  }
  
  return response.data['download_url'] as String;
}
