import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/biometric/verify - Verify biometric credentials
/// Used for session check-in and e-signature reauth
Future<Response> biometricVerifyHandler(Request req) async {
  final supabase = RequestContext.supabase;

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final deviceId = body['device_id'] as String?;
  final signature = body['signature'] as String?;
  final challenge = body['challenge'] as String?;
  final employeeId = body['employee_id'] as String?;

  final errors = <String, String>{};
  if (deviceId == null || deviceId.isEmpty) {
    errors['device_id'] = 'device_id is required';
  }
  if (signature == null || signature.isEmpty) {
    errors['signature'] = 'signature is required';
  }
  if (challenge == null || challenge.isEmpty) {
    errors['challenge'] = 'challenge is required';
  }
  if (employeeId == null || employeeId.isEmpty) {
    errors['employee_id'] = 'employee_id is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  // Lookup biometric credential
  final credential = await supabase
      .from('biometric_credentials')
      .select('id, employee_id, public_key, is_active')
      .eq('device_id', deviceId!)
      .eq('employee_id', employeeId!)
      .eq('is_active', true)
      .maybeSingle();

  if (credential == null) {
    await supabase.from('audit_trails').insert({
      'entity_type': 'biometric_verification',
      'entity_id': employeeId,
      'action': 'VERIFY_FAILED',
      'performed_by': employeeId,
      'changes': {'reason': 'credential_not_found', 'device_id': deviceId},
    });

    return ErrorResponse.validation({'biometric': 'Biometric credential not found or inactive'}).toResponse();
  }

  // In production, verify the signature using the public key
  final isValid = _verifySignature(
    credential['public_key'] as String,
    challenge!,
    signature!,
  );

  if (!isValid) {
    await supabase.from('audit_trails').insert({
      'entity_type': 'biometric_verification',
      'entity_id': credential['id'],
      'action': 'VERIFY_FAILED',
      'performed_by': employeeId,
      'changes': {'reason': 'invalid_signature'},
    });

    return ErrorResponse.unauthorized('Biometric verification failed').toResponse();
  }

  // Update last used timestamp
  await supabase
      .from('biometric_credentials')
      .update({'last_used_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', credential['id']);

  await supabase.from('audit_trails').insert({
    'entity_type': 'biometric_verification',
    'entity_id': credential['id'],
    'action': 'VERIFY_SUCCESS',
    'performed_by': employeeId,
    'changes': {'device_id': deviceId},
  });

  return ApiResponse.ok({
    'verified': true,
    'credential_id': credential['id'],
    'employee_id': employeeId,
  }).toResponse();
}

/// Verify signature using public key
/// In production, this would use proper cryptographic verification
bool _verifySignature(String publicKey, String challenge, String signature) {
  // Placeholder - in production, use pointycastle or similar
  return publicKey.isNotEmpty && challenge.isNotEmpty && signature.isNotEmpty;
}
