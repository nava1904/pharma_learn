import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/logout
///
/// Logs out the current user by revoking their session and signing out of GoTrue.
///
/// Request headers:
/// - Authorization: Bearer {access_token}
///
/// Response:
/// - 204: Logout successful
/// - 401: Unauthorized
Future<Response> logoutHandler(Request req) async {
  final auth = RequestContext.authOrNull;
  if (auth == null) {
    return ErrorResponse.unauthorized('Not authenticated').toResponse();
  }

  final supabase = RequestContext.supabase;

  try {
    // 1. Revoke the session in user_sessions table
    await supabase.rpc('revoke_user_session', params: {
      'p_session_id': auth.sessionId,
    });

    // 2. Sign out from GoTrue
    await supabase.auth.signOut();

    return ApiResponse.noContent().toResponse();
  } catch (e) {
    // Even if there's an error, still return success
    // The session will eventually expire
    return ApiResponse.noContent().toResponse();
  }
}
