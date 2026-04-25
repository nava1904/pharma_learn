import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/reauth/create — 21 CFR §11.200 re-authentication session
///
/// The employee proves their identity (password) to obtain a 30-minute
/// single-use reauth_session_id. This ID is passed as `e_signature.reauth_session_id`
/// in any subsequent e-signature action (approve, submit, revoke, etc.).
///
/// Body: `{"password": "…", "meaning": "APPROVE|SUBMIT|REVOKE|SIGN|WITNESS"}`
///
/// Response 200:
/// ```json
/// {
///   "data": {
///     "reauth_session_id": "UUID",
///     "expires_at": "ISO8601",
///     "meaning": "APPROVE"
///   }
/// }
/// ```
///
/// Errors:
/// - 400 missing fields
/// - 401 invalid password
/// - 422 invalid meaning value
Future<Response> reauthCreateHandler(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  final password = body['password'] as String?;
  final meaning = body['meaning'] as String?;

  final errors = <String, dynamic>{};
  if (password == null || password.isEmpty) errors['password'] = 'Required';
  if (meaning == null || meaning.isEmpty) errors['meaning'] = 'Required';
  if (errors.isNotEmpty) throw ValidationException(errors);

  if (!kValidEsigMeanings.contains(meaning)) {
    throw ValidationException({
      'meaning': 'Must be one of: ${kValidEsigMeanings.join(', ')}',
    });
  }

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // 1. Validate password via DB RPC (checks lockout + credential hash)
  final valid = await supabase.rpc(
    'validate_credential',
    params: {
      'p_employee_id': auth.employeeId,
      'p_input_hash': password,
      'p_policy_threshold': 5,
    },
  ) as bool? ?? false;

  if (!valid) {
    return ErrorResponse.unauthorized(
      'Password is incorrect. Please re-enter your password.',
    ).toResponse();
  }

  // 2. Read reauth window from system_settings (default 30 min)
  int reauthWindowMinutes = 30;
  try {
    final setting = await supabase
        .from('system_settings')
        .select('value')
        .eq('key', 'security.password_reauth_window_min')
        .maybeSingle();
    if (setting != null) {
      reauthWindowMinutes =
          int.tryParse(setting['value'].toString()) ?? 30;
    }
  } catch (_) {}

  // 3. Create reauth session via RPC
  final result = await supabase.rpc(
    'create_reauth_session',
    params: {
      'p_employee_id': auth.employeeId,
      'p_meaning': meaning,
      'p_window_minutes': reauthWindowMinutes,
    },
  ) as Map<String, dynamic>;

  return ApiResponse.ok({
    'reauth_session_id': result['reauth_session_id'],
    'expires_at': result['expires_at'],
    'meaning': meaning,
  }).toResponse();
}
