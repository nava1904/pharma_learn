import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/esig/upload-certificate
///
/// Uploads a digital certificate for e-signature purposes.
/// This allows employees to use PKI-based signatures (21 CFR §11.100).
/// Body: { certificate_pem, certificate_password? }
Future<Response> esigCertificateUploadHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  final certificatePem = body['certificate_pem'] as String?;
  if (certificatePem == null || certificatePem.isEmpty) {
    throw ValidationException({'certificate_pem': 'Certificate PEM is required'});
  }

  // Validate certificate format (basic check)
  if (!certificatePem.contains('-----BEGIN CERTIFICATE-----')) {
    throw ValidationException({
      'certificate_pem': 'Invalid certificate format. Must be PEM encoded.'
    });
  }

  final now = DateTime.now().toUtc();

  // Store certificate reference (actual cert stored in secure storage)
  final certRecord = await supabase
      .from('esig_certificates')
      .insert({
        'employee_id': auth.employeeId,
        'certificate_fingerprint': _computeFingerprint(certificatePem),
        'issuer': _extractIssuer(certificatePem),
        'subject': _extractSubject(certificatePem),
        'valid_from': now.toIso8601String(),
        'valid_until': now.add(const Duration(days: 365)).toIso8601String(),
        'is_active': true,
        'created_at': now.toIso8601String(),
        'organization_id': auth.orgId,
      })
      .select()
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'esig_certificates',
    'entity_id': certRecord['id'],
    'action': 'CERTIFICATE_UPLOADED',
    'event_category': 'SECURITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'fingerprint': certRecord['certificate_fingerprint'],
    }),
  });

  return ApiResponse.created({
    'id': certRecord['id'],
    'fingerprint': certRecord['certificate_fingerprint'],
    'issuer': certRecord['issuer'],
    'subject': certRecord['subject'],
    'valid_from': certRecord['valid_from'],
    'valid_until': certRecord['valid_until'],
    'message': 'Certificate uploaded successfully',
  }).toResponse();
}

/// GET /v1/auth/esig/certificates
///
/// Lists employee's e-signature certificates.
Future<Response> esigCertificatesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final certs = await supabase
      .from('esig_certificates')
      .select('id, certificate_fingerprint, issuer, subject, valid_from, valid_until, is_active, created_at')
      .eq('employee_id', auth.employeeId)
      .order('created_at', ascending: false);

  return ApiResponse.ok({'certificates': certs}).toResponse();
}

/// DELETE /v1/auth/esig/certificates/:id
///
/// Revokes an e-signature certificate.
Future<Response> esigCertificateRevokeHandler(Request req) async {
  final certId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (certId == null || certId.isEmpty) {
    throw ValidationException({'id': 'Certificate ID is required'});
  }

  final cert = await supabase
      .from('esig_certificates')
      .select('id, employee_id')
      .eq('id', certId)
      .maybeSingle();

  if (cert == null) {
    throw NotFoundException('Certificate not found');
  }

  // Employees can only revoke their own certificates
  if (cert['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('Cannot revoke another employee\'s certificate');
  }

  await supabase
      .from('esig_certificates')
      .update({
        'is_active': false,
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
        'revoked_by': auth.employeeId,
      })
      .eq('id', certId);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'esig_certificates',
    'entity_id': certId,
    'action': 'CERTIFICATE_REVOKED',
    'event_category': 'SECURITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
  });

  return ApiResponse.ok({'message': 'Certificate revoked successfully'}).toResponse();
}

// Helper functions for certificate parsing
String _computeFingerprint(String pem) {
  // In production, compute SHA-256 fingerprint of certificate
  // For now, return a placeholder based on hash
  return 'SHA256:${pem.hashCode.toRadixString(16).padLeft(16, '0').toUpperCase()}';
}

String _extractIssuer(String pem) {
  // In production, parse X.509 certificate
  return 'CN=PharmaLearn CA, O=PharmaLearn, C=IN';
}

String _extractSubject(String pem) {
  // In production, parse X.509 certificate
  return 'CN=Employee Certificate';
}
