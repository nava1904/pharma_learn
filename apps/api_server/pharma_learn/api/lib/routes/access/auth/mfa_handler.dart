import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show FactorType;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/mfa/verify — verify a TOTP code (during login step-up)
///
/// Body: `{"factor_id": "UUID", "totp_code": "123456"}`
Future<Response> mfaVerifyHandler(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final factorId = body['factor_id'] as String?;
  final totpCode = body['totp_code'] as String?;

  final errors = <String, dynamic>{};
  if (factorId == null || factorId.isEmpty) errors['factor_id'] = 'Required';
  if (totpCode == null || totpCode.isEmpty) errors['totp_code'] = 'Required';
  if (errors.isNotEmpty) throw ValidationException(errors);

  final supabase = RequestContext.supabase;

  try {
    final response = await supabase.auth.mfa.challengeAndVerify(
      factorId: factorId!,
      code: totpCode!,
    );
    // AuthMFAVerifyResponse has accessToken and refreshToken (not .session)
    return ApiResponse.ok({
      'access_token': response.accessToken,
      'refresh_token': response.refreshToken,
    }).toResponse();
  } catch (e) {
    return ErrorResponse.unauthorized('Invalid MFA code').toResponse();
  }
}

/// POST /v1/auth/mfa/enable — start TOTP enrollment
///
/// Response: `{data: {factor_id, qr_code, secret}}`
Future<Response> mfaEnableHandler(Request req) async {
  final supabase = RequestContext.supabase;

  try {
    final response = await supabase.auth.mfa.enroll(
      factorType: FactorType.totp,
      issuer: 'PharmaLearn',
      friendlyName: 'Authenticator',
    );

    await supabase
        .from('user_credentials')
        .update({'mfa_enabled': false}) // not yet confirmed
        .eq('employee_id', RequestContext.auth.employeeId);

    return ApiResponse.ok({
      'factor_id': response.id,
      'qr_code': response.totp?.qrCode,
      'secret': response.totp?.secret,
    }).toResponse();
  } catch (e) {
    throw AuthException('Failed to start MFA enrollment: $e');
  }
}

/// POST /v1/auth/mfa/verify-setup — confirm enrollment with a TOTP code
///
/// Body: `{"factor_id": "…", "totp_code": "123456"}`
Future<Response> mfaVerifySetupHandler(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final factorId = body['factor_id'] as String?;
  final totpCode = body['totp_code'] as String?;

  final errors = <String, dynamic>{};
  if (factorId == null) errors['factor_id'] = 'Required';
  if (totpCode == null) errors['totp_code'] = 'Required';
  if (errors.isNotEmpty) throw ValidationException(errors);

  final supabase = RequestContext.supabase;

  try {
    await supabase.auth.mfa.challengeAndVerify(
      factorId: factorId!,
      code: totpCode!,
    );

    await supabase
        .from('user_credentials')
        .update({'mfa_enabled': true})
        .eq('employee_id', RequestContext.auth.employeeId);

    return ApiResponse.ok({'mfa_enabled': true}).toResponse();
  } catch (e) {
    return ErrorResponse.unauthorized('Invalid verification code').toResponse();
  }
}

/// POST /v1/auth/mfa/disable — remove TOTP factor
///
/// Body: `{"factor_id": "…"}`
Future<Response> mfaDisableHandler(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final factorId = body['factor_id'] as String?;
  if (factorId == null) {
    throw ValidationException({'factor_id': 'Required'});
  }

  final supabase = RequestContext.supabase;

  try {
    await supabase.auth.mfa.unenroll(factorId);

    await supabase
        .from('user_credentials')
        .update({'mfa_enabled': false})
        .eq('employee_id', RequestContext.auth.employeeId);

    return ApiResponse.ok({'mfa_enabled': false}).toResponse();
  } catch (e) {
    throw AuthException('Failed to disable MFA: $e');
  }
}
