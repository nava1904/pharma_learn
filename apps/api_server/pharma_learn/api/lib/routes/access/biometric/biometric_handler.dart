import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/biometric/register
///
/// Registers biometric credentials for an employee.
/// Body: { device_id, biometric_type, public_key }
Future<Response> biometricRegisterHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final deviceId = requireString(body, 'device_id');
  final biometricType = requireString(body, 'biometric_type');
  final publicKey = requireString(body, 'public_key');

  // Check if device already registered
  final existing = await supabase
      .from('biometric_credentials')
      .select('id')
      .eq('employee_id', auth.employeeId)
      .eq('device_id', deviceId)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Device already registered for biometric login');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final credential = await supabase
      .from('biometric_credentials')
      .insert({
        'employee_id': auth.employeeId,
        'device_id': deviceId,
        'biometric_type': biometricType,
        'public_key': publicKey,
        'is_active': true,
        'created_at': now,
      })
      .select()
      .single();

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'biometric.registered',
    'entity_type': 'biometric_credentials',
    'entity_id': credential['id'],
    'details': {'device_id': deviceId, 'biometric_type': biometricType},
    'created_at': now,
  });

  return ApiResponse.created({
    'id': credential['id'],
    'device_id': deviceId,
    'biometric_type': biometricType,
    'registered_at': now,
  }).toResponse();
}

/// POST /v1/auth/biometric/login
///
/// Authenticates using biometric credentials.
/// Body: { device_id, signature, challenge }
Future<Response> biometricLoginHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final deviceId = requireString(body, 'device_id');
  final signature = requireString(body, 'signature');
  final challenge = requireString(body, 'challenge');

  // Find credential
  final credential = await supabase
      .from('biometric_credentials')
      .select('*, employees!inner(id, email, status, induction_completed)')
      .eq('device_id', deviceId)
      .eq('is_active', true)
      .maybeSingle();

  if (credential == null) {
    throw NotFoundException('Biometric credential not found or inactive');
  }

  final employee = credential['employees'] as Map<String, dynamic>;

  if (employee['status'] != 'active') {
    throw PermissionDeniedException('Employee account is not active');
  }

  // Verify signature against public key and challenge
  // In production, this would use crypto verification
  final isValid = await _verifyBiometricSignature(
    publicKey: credential['public_key'] as String,
    signature: signature,
    challenge: challenge,
  );

  if (!isValid) {
    throw AuthException('Invalid biometric signature');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Update last used
  await supabase
      .from('biometric_credentials')
      .update({'last_used_at': now})
      .eq('id', credential['id']);

  // Create session via Supabase Auth (service role)
  // This would typically call a custom RPC or Edge Function
  final session = await supabase.rpc('create_biometric_session', params: {
    'p_employee_id': employee['id'],
    'p_device_id': deviceId,
  });

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': employee['id'],
    'event_type': EventTypes.authLogin,
    'entity_type': 'biometric_credentials',
    'entity_id': credential['id'],
    'details': {'method': 'biometric', 'device_id': deviceId},
    'created_at': now,
  });

  return ApiResponse.ok({
    'session': session,
    'employee': {
      'id': employee['id'],
      'email': employee['email'],
      'induction_completed': employee['induction_completed'],
    },
  }).toResponse();
}

/// DELETE /v1/auth/biometric/:id
///
/// Revokes a biometric credential.
Future<Response> biometricRevokeHandler(Request req) async {
  final credentialId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (credentialId == null || credentialId.isEmpty) {
    throw ValidationException({'id': 'Credential ID is required'});
  }

  // Check ownership
  final credential = await supabase
      .from('biometric_credentials')
      .select('id, employee_id')
      .eq('id', credentialId)
      .maybeSingle();

  if (credential == null) {
    throw NotFoundException('Biometric credential not found');
  }

  if (credential['employee_id'] != auth.employeeId &&
      !auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('Cannot revoke another user\'s credential');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('biometric_credentials')
      .update({
        'is_active': false,
        'revoked_at': now,
        'revoked_by': auth.employeeId,
      })
      .eq('id', credentialId);

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'biometric.revoked',
    'entity_type': 'biometric_credentials',
    'entity_id': credentialId,
    'created_at': now,
  });

  return ApiResponse.noContent().toResponse();
}

/// GET /v1/auth/biometric
///
/// Lists biometric credentials for the current user.
Future<Response> biometricListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final credentials = await supabase
      .from('biometric_credentials')
      .select('id, device_id, biometric_type, is_active, created_at, last_used_at')
      .eq('employee_id', auth.employeeId)
      .order('created_at', ascending: false);

  return ApiResponse.ok(credentials).toResponse();
}

// Helper to verify biometric signature
Future<bool> _verifyBiometricSignature({
  required String publicKey,
  required String signature,
  required String challenge,
}) async {
  // In production, implement proper crypto verification
  // This is a placeholder that would use dart:crypto or a native bridge
  return signature.isNotEmpty && challenge.isNotEmpty;
}
