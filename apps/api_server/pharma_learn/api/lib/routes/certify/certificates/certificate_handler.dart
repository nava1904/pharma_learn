import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/certify/certificates/:id - Get certificate by ID
Future<Response> certificateGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('certificates')
      .select('''
        *,
        employee:employees(id, employee_number, full_name),
        course:courses(id, code, name),
        training_record:training_records(id)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Certificate not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/certify/certificates/:id/revoke - Revoke certificate [esig]
/// Reference: Alfa §4.2.1.13 — certificate revocation with e-signature
Future<Response> certificateRevokeHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to revoke certificate').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'certificates.revoke',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('certificates')
      .select('id, status, employee_id')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Certificate not found').toResponse();
  }

  if (existing['status'] == 'revoked') {
    return ErrorResponse.conflict('Certificate already revoked').toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'certificates',
    'entity_id': id,
    'meaning': 'REVOKE_CERTIFICATE',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  final result = await supabase
      .from('certificates')
      .update({
        'status': 'revoked',
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
        'revoked_by': auth.employeeId,
        'revocation_reason': esig.reason,
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  // Invalidate competency
  await supabase
      .from('employee_competencies')
      .update({
        'status': 'invalidated',
        'invalidated_at': DateTime.now().toUtc().toIso8601String(),
        'invalidated_by': auth.employeeId,
        'invalidation_reason': 'Certificate revoked',
      })
      .eq('certificate_id', id);

  await supabase.from('audit_trails').insert({
    'entity_type': 'certificates',
    'entity_id': id,
    'action': 'REVOKE',
    'performed_by': auth.employeeId,
    'changes': {'reason': esig.reason, 'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// GET /v1/certify/certificates/:id/pdf - Download certificate PDF
Future<Response> certificatePdfHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('certificates')
      .select('id, pdf_url, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Certificate not found').toResponse();
  }

  if (result['status'] == 'revoked') {
    return ErrorResponse.conflict('Cannot download revoked certificate').toResponse();
  }

  final pdfUrl = result['pdf_url'] as String?;
  if (pdfUrl == null) {
    return ErrorResponse.notFound('Certificate PDF not yet generated').toResponse();
  }

  // Generate signed URL for download
  final signedUrl = supabase.storage.from('certificates').createSignedUrl(pdfUrl, 3600);

  return ApiResponse.ok({'download_url': signedUrl, 'expires_in': 3600}).toResponse();
}
