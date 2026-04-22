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

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final esigSvc = EsigService(supabase);

  // Validate the session belongs to the current employee
  final isValid = await esigSvc.validateReauthSession(
    reauthSessionId,
    auth.employeeId,
  );

  if (!isValid) {
    return ApiResponse.ok({
      'is_valid': false,
      'reason': 'Session not found, expired, or already consumed',
    }).toResponse();
  }

  // Get session details from database for expiry info
  final session = await supabase
      .from('reauth_sessions')
      .select('expires_at, meaning')
      .eq('id', reauthSessionId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (session == null) {
    return ApiResponse.ok({
      'is_valid': false,
      'reason': 'Session not found',
    }).toResponse();
  }

  final expiresAt = session['expires_at'] as String?;
  if (expiresAt != null) {
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry != null && expiry.isBefore(DateTime.now().toUtc())) {
      return ApiResponse.ok({
        'is_valid': false,
        'reason': 'Session has expired',
      }).toResponse();
    }
  }

  return ApiResponse.ok({
    'is_valid': true,
    'expires_at': expiresAt,
    'meaning': session['meaning'],
    'employee_id': auth.employeeId,
  }).toResponse();
}
