import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/certify/certificates
///
/// Returns the current employee's certificates.
/// Query params:
/// - status: active|revoked|expired (optional)
/// - page, per_page: pagination
Future<Response> certificatesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final status = req.url.queryParameters['status'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;

  var query = supabase
      .from('certificates')
      .select('''
        id, certificate_number, issued_at, expires_at, status,
        courses!inner(id, title, course_code),
        electronic_signatures(id, meaning, signed_at)
      ''')
      .eq('employee_id', auth.employeeId);

  if (status != null) {
    query = query.eq('status', status);
  }

  final response = await query
      .order('issued_at', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  return ApiResponse.ok(response).toResponse();
}

/// GET /v1/certify/certificates/:id
///
/// Returns certificate details.
Future<Response> certificateGetHandler(Request req) async {
  final certId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final certificate = await supabase
      .from('certificates')
      .select('''
        id, certificate_number, issued_at, expires_at, status,
        certificate_url, metadata,
        courses!inner(id, title, course_code, description),
        employees!inner(id, first_name, last_name, employee_number),
        electronic_signatures(id, meaning, signed_at, signer_name),
        certificate_revocation_requests(
          id, status, initiated_at, initiation_reason,
          employees!initiated_by(first_name, last_name)
        )
      ''')
      .eq('id', certId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (certificate == null) {
    throw NotFoundException('Certificate not found');
  }

  return ApiResponse.ok(certificate).toResponse();
}

/// GET /v1/certify/certificates/:id/download
///
/// Returns the certificate PDF download URL.
Future<Response> certificateDownloadHandler(Request req) async {
  final certId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final certificate = await supabase
      .from('certificates')
      .select('id, certificate_url, status')
      .eq('id', certId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (certificate == null) {
    throw NotFoundException('Certificate not found');
  }

  if (certificate['status'] == 'revoked') {
    throw ConflictException('Cannot download a revoked certificate');
  }

  final url = certificate['certificate_url'] as String?;
  if (url == null || url.isEmpty) {
    throw NotFoundException('Certificate file not available');
  }

  // Generate signed URL for download (valid for 5 minutes)
  final signedUrl = await supabase.storage
      .from('certificates')
      .createSignedUrl(url, 300);

  return ApiResponse.ok({
    'download_url': signedUrl,
    'expires_in': 300,
  }).toResponse();
}

/// POST /v1/certify/certificates/:id/revoke/initiate
///
/// Initiates a two-person revocation request (first person).
/// Requires e-signature.
///
/// Body:
/// ```json
/// {
///   "reason": "string",
///   "esignature": {
///     "reauth_session_id": "uuid",
///     "meaning": "REVOKE"
///   }
/// }
/// ```
Future<Response> certificateRevokeInitiateHandler(Request req) async {
  final certId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final reason = body['reason'] as String?;
  final esigData = body['esignature'] as Map<String, dynamic>?;

  if (reason == null || reason.trim().isEmpty) {
    throw ValidationException({'reason': 'Revocation reason is required'});
  }

  if (esigData == null || esigData['reauth_session_id'] == null) {
    throw ValidationException({'esignature': 'E-signature is required for revocation'});
  }

  // Verify user has permission to revoke certificates
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.revokeCertificates,
    jwtPermissions: auth.permissions,
  );

  // Verify certificate exists and is active
  final certificate = await supabase
      .from('certificates')
      .select('id, status, employee_id')
      .eq('id', certId)
      .maybeSingle();

  if (certificate == null) {
    throw NotFoundException('Certificate not found');
  }

  if (certificate['status'] != 'active') {
    throw ConflictException('Certificate is not active');
  }

  // Check for existing pending revocation
  final existingRequest = await supabase
      .from('certificate_revocation_requests')
      .select('id')
      .eq('certificate_id', certId)
      .eq('status', 'pending')
      .maybeSingle();

  if (existingRequest != null) {
    throw ConflictException('A revocation request is already pending for this certificate');
  }

  // Create e-signature
  final esig = await supabase.rpc(
    'create_esignature_from_reauth',
    params: {
      'p_reauth_session_id': esigData['reauth_session_id'],
      'p_employee_id': auth.employeeId,
      'p_meaning': 'REVOKE',
      'p_context_type': 'certificate_revocation_initiate',
      'p_context_id': certId,
    },
  ) as Map<String, dynamic>;

  // Create revocation request
  final request = await supabase.from('certificate_revocation_requests').insert({
    'certificate_id': certId,
    'initiated_by': auth.employeeId,
    'initiated_at': DateTime.now().toUtc().toIso8601String(),
    'initiation_reason': reason.trim(),
    'initiation_esignature_id': esig['esignature_id'],
    'status': 'pending',
  }).select().single();

  return ApiResponse.created({
    'revocation_request_id': request['id'],
    'status': 'pending',
    'message': 'Revocation initiated. Requires confirmation by another authorized user.',
  }).toResponse();
}

/// POST /v1/certify/certificates/:id/revoke/confirm
///
/// Confirms a revocation request (second person).
/// Must be different from initiator per two-person rule.
///
/// Body:
/// ```json
/// {
///   "esignature": {
///     "reauth_session_id": "uuid",
///     "meaning": "REVOKE"
///   }
/// }
/// ```
Future<Response> certificateRevokeConfirmHandler(Request req) async {
  final certId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final esigData = body['esignature'] as Map<String, dynamic>?;

  if (esigData == null || esigData['reauth_session_id'] == null) {
    throw ValidationException({'esignature': 'E-signature is required for confirmation'});
  }

  // Verify user has permission to revoke certificates
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.revokeCertificates,
    jwtPermissions: auth.permissions,
  );

  // Get pending revocation request
  final request = await supabase
      .from('certificate_revocation_requests')
      .select('id, initiated_by, certificate_id')
      .eq('certificate_id', certId)
      .eq('status', 'pending')
      .maybeSingle();

  if (request == null) {
    throw NotFoundException('No pending revocation request found');
  }

  // Two-person rule: confirmer must be different from initiator
  if (request['initiated_by'] == auth.employeeId) {
    throw ConflictException('Cannot confirm your own revocation request. Another authorized user must confirm.');
  }

  // Create e-signature
  final esig = await supabase.rpc(
    'create_esignature_from_reauth',
    params: {
      'p_reauth_session_id': esigData['reauth_session_id'],
      'p_employee_id': auth.employeeId,
      'p_meaning': 'REVOKE',
      'p_context_type': 'certificate_revocation_confirm',
      'p_context_id': certId,
    },
  ) as Map<String, dynamic>;

  final now = DateTime.now().toUtc().toIso8601String();

  // Update revocation request
  await supabase.from('certificate_revocation_requests').update({
    'confirmed_by': auth.employeeId,
    'confirmed_at': now,
    'confirmation_esignature_id': esig['esignature_id'],
    'status': 'confirmed',
  }).eq('id', request['id']);

  // Revoke the certificate
  await supabase.from('certificates').update({
    'status': 'revoked',
    'revoked_at': now,
    'revoked_by': auth.employeeId,
  }).eq('id', certId);

  return ApiResponse.ok({
    'certificate_id': certId,
    'status': 'revoked',
    'revoked_at': now,
    'message': 'Certificate has been revoked with two-person authorization.',
  }).toResponse();
}

/// POST /v1/certify/certificates/:id/revoke/cancel
///
/// Cancels a pending revocation request.
/// No e-signature required, just audit log (per design decision F4).
///
/// Body:
/// ```json
/// {
///   "reason": "optional cancellation reason"
/// }
/// ```
Future<Response> certificateRevokeCancelHandler(Request req) async {
  final certId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final reason = body['reason'] as String?;

  // Verify user has permission to revoke certificates
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.revokeCertificates,
    jwtPermissions: auth.permissions,
  );

  // Get pending revocation request
  final request = await supabase
      .from('certificate_revocation_requests')
      .select('id, initiated_by')
      .eq('certificate_id', certId)
      .eq('status', 'pending')
      .maybeSingle();

  if (request == null) {
    throw NotFoundException('No pending revocation request found');
  }

  // Update revocation request
  await supabase.from('certificate_revocation_requests').update({
    'cancelled_by': auth.employeeId,
    'cancelled_at': DateTime.now().toUtc().toIso8601String(),
    'cancellation_reason': reason,
    'status': 'cancelled',
  }).eq('id', request['id']);

  return ApiResponse.ok({
    'certificate_id': certId,
    'status': 'cancelled',
    'message': 'Revocation request has been cancelled.',
  }).toResponse();
}

/// GET /v1/certify/certificates/verify/:certificateNumber
///
/// Public endpoint to verify a certificate by its number.
Future<Response> certificateVerifyHandler(Request req) async {
  final certNumber = req.rawPathParameters[#certificateNumber];
  final supabase = RequestContext.supabase;

  if (certNumber == null || certNumber.isEmpty) {
    throw ValidationException({'certificateNumber': 'Required'});
  }

  final certificate = await supabase
      .from('certificates')
      .select('''
        certificate_number, issued_at, expires_at, status,
        courses!inner(title, course_code),
        employees!inner(first_name, last_name)
      ''')
      .eq('certificate_number', certNumber)
      .maybeSingle();

  if (certificate == null) {
    return ApiResponse.ok({
      'valid': false,
      'message': 'Certificate not found',
    }).toResponse();
  }

  final isActive = certificate['status'] == 'active';
  final isExpired = certificate['expires_at'] != null &&
      DateTime.parse(certificate['expires_at'] as String).isBefore(DateTime.now());

  return ApiResponse.ok({
    'valid': isActive && !isExpired,
    'certificate_number': certificate['certificate_number'],
    'holder': '${certificate['employees']['first_name']} ${certificate['employees']['last_name']}',
    'course': certificate['courses']['title'],
    'issued_at': certificate['issued_at'],
    'expires_at': certificate['expires_at'],
    'status': isExpired ? 'expired' : certificate['status'],
  }).toResponse();
}
