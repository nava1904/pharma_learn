import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/biometric/register - Register biometric credentials
/// Reference: Alfa §4.5.9 — biometric login support
Future<Response> biometricRegisterHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final biometricType = body['biometric_type'] as String?;
  final publicKey = body['public_key'] as String?;
  final deviceId = body['device_id'] as String?;
  final deviceName = body['device_name'] as String?;

  final errors = <String, String>{};
  if (biometricType == null || !['fingerprint', 'face', 'iris'].contains(biometricType)) {
    errors['biometric_type'] = 'biometric_type must be fingerprint, face, or iris';
  }
  if (publicKey == null || publicKey.isEmpty) {
    errors['public_key'] = 'public_key is required';
  }
  if (deviceId == null || deviceId.isEmpty) {
    errors['device_id'] = 'device_id is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  // Check for existing registration for this device
  final existing = await supabase
      .from('biometric_credentials')
      .select('id')
      .eq('employee_id', auth.employeeId)
      .eq('device_id', deviceId!)
      .maybeSingle();

  if (existing != null) {
    // Update existing registration
    final result = await supabase
        .from('biometric_credentials')
        .update({
          'biometric_type': biometricType,
          'public_key': publicKey,
          'device_name': deviceName,
          'is_active': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', existing['id'])
        .select()
        .single();

    await supabase.from('audit_trails').insert({
      'entity_type': 'biometric_credentials',
      'entity_id': result['id'],
      'action': 'UPDATE',
      'performed_by': auth.employeeId,
      'changes': {'device_id': deviceId, 'biometric_type': biometricType},
      'org_id': auth.orgId,
    });

    return ApiResponse.ok({
      'credential_id': result['id'],
      'registered': true,
      'updated': true,
    }).toResponse();
  }

  // Create new registration
  final result = await supabase.from('biometric_credentials').insert({
    'employee_id': auth.employeeId,
    'biometric_type': biometricType,
    'public_key': publicKey,
    'device_id': deviceId,
    'device_name': deviceName,
    'is_active': true,
    'org_id': auth.orgId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'biometric_credentials',
    'entity_id': result['id'],
    'action': 'REGISTER',
    'performed_by': auth.employeeId,
    'changes': {'device_id': deviceId, 'biometric_type': biometricType},
    'org_id': auth.orgId,
  });

  return ApiResponse.created({
    'credential_id': result['id'],
    'registered': true,
  }).toResponse();
}
