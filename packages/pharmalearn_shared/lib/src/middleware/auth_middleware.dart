import 'dart:convert';
import 'dart:io';

import 'package:relic/relic.dart';

import '../client/supabase_client.dart';
import '../context/request_context.dart';
import '../models/auth_context.dart';
import '../models/error_response.dart';
import '../services/jwt_service.dart';
import '../utils/constants.dart';

// ---------------------------------------------------------------------------
// Auth Middleware — 21 CFR §11 Session Management (Relic)
// ---------------------------------------------------------------------------

/// Validates the Bearer JWT, checks the `user_sessions` table, enforces
/// idle-timeout, and stores [AuthContext] in the Zone for handlers.
///
/// Usage:
/// ```dart
/// app.use('/', authMiddleware());
/// ```
Handler Function(Handler) authMiddleware() {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.url.path;

      // Step 1 — skip public paths.
      if (_isPublicPath(path)) {
        return innerHandler(request);
      }

      // Step 2 — extract Bearer token.
      final authHeader = request.headers.authorization;
      if (authHeader == null || authHeader is! BearerAuthorizationHeader) {
        return _unauthorizedResponse('Missing or malformed Authorization header.');
      }
      final token = authHeader.token;

      // Step 3 — decode JWT.
      final Map<String, dynamic> claims;
      try {
        claims = JwtService.decode(token);
      } catch (_) {
        return _unauthorizedResponse('Invalid JWT format.');
      }

      if (JwtService.isExpired(claims)) {
        return _sessionTimeoutResponse();
      }

      final sub = claims['sub'] as String?;
      final jti = claims['jti'] as String?;
      final appMetadata =
          claims['app_metadata'] as Map<String, dynamic>? ?? {};

      if (sub == null || jti == null) {
        return _unauthorizedResponse('JWT missing required claims (sub, jti).');
      }

      final supabase = SupabaseService.client;

      // Step 4 — load user_sessions row.
      final Map<String, dynamic>? sessionRow = await supabase
          .from('user_sessions')
          .select()
          .eq('id', jti)
          .maybeSingle();

      if (sessionRow == null) {
        return _sessionTimeoutResponse();
      }
      if (sessionRow['revoked_at'] != null) {
        return _sessionTimeoutResponse();
      }

      final expiresAtRaw = sessionRow['expires_at'] as String?;
      if (expiresAtRaw != null) {
        final expiresAt = DateTime.parse(expiresAtRaw).toUtc();
        if (DateTime.now().toUtc().isAfter(expiresAt)) {
          return _sessionTimeoutResponse();
        }
      }

      // Step 5 — idle-timeout check.
      final idleTimeoutSeconds = int.tryParse(
              Platform.environment['SESSION_IDLE_TIMEOUT_SECONDS'] ?? '') ??
          1800;

      final lastActivityRaw = sessionRow['last_activity_at'] as String?;
      if (lastActivityRaw != null) {
        final lastActivity = DateTime.parse(lastActivityRaw).toUtc();
        final idleFor =
            DateTime.now().toUtc().difference(lastActivity).inSeconds;
        if (idleFor > idleTimeoutSeconds) {
          // Revoke the session and return timeout.
          await supabase.rpc(
            'revoke_user_session',
            params: {'p_session_id': jti},
          );
          return _sessionTimeoutResponse();
        }
      }

      // Step 6 — update last_activity_at (fire and forget).
      _unawaited(
        supabase
            .from('user_sessions')
            .update(
                {'last_activity_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', jti),
      );

      // Step 7 — induction gate.
      final inductionCompleted =
          appMetadata['induction_completed'] as bool? ?? false;
      if (!inductionCompleted && !_isInductionAllowed(path)) {
        return _inductionRequiredResponse();
      }

      // Step 8 — build AuthContext.
      final permissions = (appMetadata['permissions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      final authContext = AuthContext(
        userId: sub,
        employeeId: appMetadata['employee_id'] as String? ?? '',
        orgId: appMetadata['organization_id'] as String? ?? '',
        plantId: appMetadata['plant_id'] as String? ?? '',
        permissions: permissions,
        inductionCompleted: inductionCompleted,
        sessionId: jti,
      );

      // Step 9 — run handler in zone with auth context.
      return RequestContext.withAll(
        auth: authContext,
        supabase: supabase,
        callback: () async => innerHandler(request),
      );
    };
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

bool _isPublicPath(String path) {
  if (PublicPaths.skipAuth.contains(path)) return true;
  // Any path ending in /verify (e.g. /v1/certificates/:id/verify)
  if (path.endsWith('/verify')) return true;
  return false;
}

/// Returns true if [path] is allowed even when induction is not yet complete.
bool _isInductionAllowed(String path) {
  if (path == '/health') return true;
  if (path.startsWith('/v1/auth')) return true;
  if (path.startsWith('/v1/induction')) return true;
  if (path.startsWith('/v1/reauth')) return true;  // needed for induction esig
  return false;
}

Response _unauthorizedResponse(String detail) {
  return Response.unauthorized(
    body: Body.fromString(
      jsonEncode(ErrorResponse.unauthorized(detail).toJson()),
      mimeType: MimeType.json,
    ),
  );
}

Response _sessionTimeoutResponse() {
  return Response.unauthorized(
    body: Body.fromString(
      jsonEncode(ErrorResponse.sessionTimeout().toJson()),
      mimeType: MimeType.json,
    ),
  );
}

Response _inductionRequiredResponse() {
  return Response.forbidden(
    body: Body.fromString(
      jsonEncode(ErrorResponse.inductionRequired(
        'Induction training must be completed before accessing this resource.',
      ).toJson()),
      mimeType: MimeType.json,
    ),
  );
}

/// Runs [future] without awaiting — explicit fire-and-forget.
void _unawaited(Future<dynamic> future) {
  future.ignore();
}
