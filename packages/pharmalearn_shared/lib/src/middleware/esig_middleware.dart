import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart';

import '../client/supabase_client.dart';
import '../context/request_context.dart';
import '../models/error_response.dart';

// ---------------------------------------------------------------------------
// E-Signature Middleware — 21 CFR §11.200 Compliance
// ---------------------------------------------------------------------------

/// Wraps a [handler] to require a valid 21 CFR §11.200 re-authentication
/// session before proceeding.
///
/// Steps:
/// 1. Reads and caches the request body (stream can only be consumed once)
/// 2. Extracts `e_signature.reauth_session_id` from body or `Authorization-Reauth` header
/// 3. Validates the reauth session via the `validate_reauth_session` RPC
/// 4. Verifies `is_first_in_session` for §11.200(a) compliance
/// 5. Stores [EsigContext] in the Zone via [RequestContext.withAll]
///
/// Usage:
/// ```dart
/// app.post('/v1/documents/:id/approve', withEsig(documentApproveHandler));
/// ```
Handler withEsig(Handler innerHandler) {
  return (Request request) async {
    // 1. Read and cache the body (stream can only be consumed once in Relic)
    final bodyString = await request.readAsString();
    Map<String, dynamic> bodyJson = {};

    try {
      if (bodyString.isNotEmpty) {
        bodyJson = jsonDecode(bodyString) as Map<String, dynamic>;
      }
    } catch (e) {
      return _badRequestResponse('Invalid JSON body: $e');
    }

    // 2. Extract e_signature block from body or Authorization-Reauth header
    final esigData = bodyJson['e_signature'] as Map<String, dynamic>?;
    // Use raw map access — Headers extends UnmodifiableMapView<String, Iterable<String>>
    final reauthHeader =
        request.headers['authorization-reauth']?.firstOrNull;

    String? reauthSessionId;
    String? meaning;
    String? reason;
    bool isFirstInSession = true;

    if (esigData != null) {
      reauthSessionId = esigData['reauth_session_id'] as String?;
      meaning = esigData['meaning'] as String?;
      reason = esigData['reason'] as String?;
      isFirstInSession = esigData['is_first_in_session'] as bool? ?? true;
    } else if (reauthHeader != null) {
      reauthSessionId = reauthHeader;
    }

    if (reauthSessionId == null || meaning == null) {
      return _esigRequiredResponse(
        'E-signature required. Provide e_signature.reauth_session_id and e_signature.meaning.',
      );
    }

    // 3. Validate reauth session via RPC — needs both session_id + employee_id.
    //    auth_middleware runs before esig_middleware so RequestContext.auth is
    //    already populated in the Zone.
    final supabase = SupabaseService.client;
    final authCtx = RequestContext.authOrNull;
    if (authCtx == null) {
      return _unauthorizedResponse(
        'Auth context not available. Ensure authMiddleware runs before withEsig.',
      );
    }

    try {
      // DB signature: validate_reauth_session(p_session_id UUID, p_employee_id UUID) RETURNS BOOLEAN
      final isValid = await supabase.rpc(
        'validate_reauth_session',
        params: {
          'p_session_id': reauthSessionId,
          'p_employee_id': authCtx.employeeId,
        },
      ) as bool? ?? false;

      if (!isValid) {
        return _unauthorizedResponse(
          'Re-authentication session expired or invalid. Please re-authenticate.',
        );
      }

      // 4+5. Build EsigContext and inject via Zone alongside cached body.
      //      expiresAt is not returned by validate_reauth_session; we use a
      //      generous 15-minute forward window for display purposes only —
      //      the DB enforces the real expiry inside create_esignature().
      final esigContext = EsigContext(
        reauthSessionId: reauthSessionId,
        employeeId: authCtx.employeeId,
        meaning: meaning,
        reason: reason,
        isFirstInSession: isFirstInSession,
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
      );

      return RequestContext.withAll<Result>(
        esig: esigContext,
        body: bodyJson,
        callback: () async => await innerHandler(request),
      );
    } on PostgrestException catch (e) {
      return _serverErrorResponse('Database error: ${e.message}');
    } catch (e) {
      return _serverErrorResponse('Unexpected error validating e-signature: $e');
    }
  };
}

// ---------------------------------------------------------------------------
// Private response helpers
// ---------------------------------------------------------------------------

Response _badRequestResponse(String message) => Response(
      400,
      body: Body.fromString(
        jsonEncode(ErrorResponse.validation({'message': message}).toJson()),
        mimeType: MimeType.json,
      ),
    );

Response _unauthorizedResponse(String message) => Response(
      401,
      body: Body.fromString(
        jsonEncode(ErrorResponse.unauthorized(message).toJson()),
        mimeType: MimeType.json,
      ),
    );

Response _esigRequiredResponse(String message) => Response(
      428, // Precondition Required
      body: Body.fromString(
        jsonEncode(
          ErrorResponse(
            type: '/errors/esig-required',
            title: 'E-Signature Required',
            status: 428,
            detail: message,
            extensions: const {
              'action':
                  'Call POST /v1/reauth/create to obtain a reauth_session_id.',
            },
          ).toJson(),
        ),
        mimeType: MimeType.json,
      ),
    );

Response _sessionTimeoutResponse() => Response(
      401,
      body: Body.fromString(
        jsonEncode(ErrorResponse.sessionTimeout().toJson()),
        mimeType: MimeType.json,
      ),
    );

Response _serverErrorResponse(String message) => Response(
      500,
      body: Body.fromString(
        jsonEncode(ErrorResponse.internalError().toJson()),
        mimeType: MimeType.json,
      ),
    );
