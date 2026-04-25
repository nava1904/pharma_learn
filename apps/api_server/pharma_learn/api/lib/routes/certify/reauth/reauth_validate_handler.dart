import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/reauth/validate
///
/// Checks whether a `reauth_session_id` is still valid without consuming it.
/// Used by the Flutter client to verify the session hasn't expired before
/// displaying the e-signature confirmation dialog.
///
/// Body: `{"reauth_session_id": "UUID"}`
/// Response 200: `{data: {is_valid: bool, expires_at: ISO8601, meaning: string}}`
Future<Response> reauthValidateHandler(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final reauthSessionId = body['reauth_session_id'] as String?;

  if (reauthSessionId == null || reauthSessionId.isEmpty) {
    throw ValidationException({'reauth_session_id': 'Required'});
  }

  final supabase = RequestContext.supabase;
  final esigSvc = EsigService(supabase);

  final result = await esigSvc.validateReauthSessionFull(reauthSessionId);

  if (result == null || result['is_valid'] != true) {
    return ApiResponse.ok({
      'is_valid': false,
      'reason': 'Session not found or already consumed',
    }).toResponse();
  }

  final expiresAt = DateTime.tryParse(result['expires_at'] as String? ?? '');
  if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
    return ApiResponse.ok({
      'is_valid': false,
      'reason': 'Session has expired',
    }).toResponse();
  }

  return ApiResponse.ok({
    'is_valid': true,
    'expires_at': result['expires_at'],
    'meaning': result['meaning'],
    'employee_id': result['employee_id'],
  }).toResponse();
}
