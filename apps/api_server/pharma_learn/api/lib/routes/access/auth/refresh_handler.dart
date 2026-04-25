import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/refresh — public path (no auth middleware check)
///
/// Exchanges a Supabase refresh token for a new access/refresh token pair.
///
/// Request body: `{"refresh_token": "…"}`
/// Response 200: `{data: {access_token, refresh_token, expires_at, token_type}}`
Future<Response> refreshHandler(Request req) async {
  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'})
        .toResponse();
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(bodyStr) as Map<String, dynamic>;
  } catch (_) {
    return ErrorResponse.validation({'body': 'Invalid JSON'}).toResponse();
  }

  final refreshToken = body['refresh_token'] as String?;
  if (refreshToken == null || refreshToken.isEmpty) {
    return ErrorResponse.validation(
      {'refresh_token': 'refresh_token is required'},
    ).toResponse();
  }

  final supabase = RequestContext.supabase;

  try {
    final authResponse = await supabase.auth.setSession(refreshToken);

    if (authResponse.session == null) {
      return ErrorResponse.unauthorized('Invalid or expired refresh token')
          .toResponse();
    }

    final newSession = authResponse.session!;

    // Update user_sessions with new expiry
    final claims = JwtService.decode(newSession.accessToken);
    final jti = claims['jti'] as String?;
    if (jti != null) {
      await supabase.from('user_sessions').update({
        'expires_at': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 8))
            .toIso8601String(),
        'last_activity_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', jti);
    }

    return ApiResponse.ok({
      'access_token': newSession.accessToken,
      'refresh_token': newSession.refreshToken,
      'expires_at': newSession.expiresAt,
      'token_type': 'Bearer',
    }).toResponse();
  } catch (e) {
    return ErrorResponse.unauthorized('Invalid or expired refresh token')
        .toResponse();
  }
}
