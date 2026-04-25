import 'package:supabase/supabase.dart';

/// Service for creating and validating electronic signatures per 21 CFR §11.
///
/// Wraps the `create_esignature`, `validate_reauth_session`,
/// `create_reauth_session`, and `consume_reauth_session` DB RPCs.
class EsigService {
  final SupabaseClient _supabase;

  EsigService(this._supabase);

  /// Creates an electronic signature via the `create_esignature` DB function.
  ///
  /// When [reauthSessionId] is provided the DB function validates the session
  /// itself and then consumes it — **do NOT call [consumeReauthSession]**
  /// separately in the handler.
  ///
  /// Parameters match the DB function signature in `07_esig_reauth.sql`:
  /// ```sql
  /// create_esignature(
  ///   p_employee_id, p_meaning, p_entity_type, p_entity_id,
  ///   p_reason, p_password_verified, p_biometric_verified,
  ///   p_data_snapshot, p_reauth_session_id,
  ///   p_hash_schema_version, p_canonical_payload
  /// )
  /// ```
  Future<String> createEsignature({
    required String employeeId,
    required String meaning,         // signature_meaning enum value
    required String entityType,
    required String entityId,
    String? reason,
    bool passwordVerified = false,
    bool biometricVerified = false,
    Map<String, dynamic>? dataSnapshot,
    String? reauthSessionId,         // preferred — validates + consumes session
    int hashSchemaVersion = 1,
  }) async {
    final result = await _supabase.rpc(
      'create_esignature',
      params: {
        'p_employee_id': employeeId,
        'p_meaning': meaning,
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_reason': reason,
        'p_password_verified': passwordVerified,
        'p_biometric_verified': biometricVerified,
        'p_data_snapshot': dataSnapshot,
        'p_reauth_session_id': reauthSessionId,
        'p_hash_schema_version': hashSchemaVersion,
      },
    );

    return result as String;
  }

  /// Validates a reauth session without consuming it.
  ///
  /// DB signature: `validate_reauth_session(p_session_id UUID, p_employee_id UUID) RETURNS BOOLEAN`
  Future<bool> validateReauthSession(
    String sessionId,
    String employeeId,
  ) async {
    final result = await _supabase.rpc(
      'validate_reauth_session',
      params: {
        'p_session_id': sessionId,
        'p_employee_id': employeeId,
      },
    );

    return result as bool? ?? false;
  }

  /// Creates a new re-auth session after the caller has verified the password.
  ///
  /// Returns the session UUID to store and later pass to [createEsignature].
  Future<String> createReauthSession(
    String employeeId, {
    String? ipAddress,
    String? userAgent,
  }) async {
    final result = await _supabase.rpc(
      'create_reauth_session',
      params: {
        'p_employee_id': employeeId,
        'p_ip_address': ipAddress,
        'p_user_agent': userAgent,
      },
    );

    return result as String;
  }

  /// Marks a reauth session as consumed.
  ///
  /// Normally called automatically by [createEsignature] when
  /// [reauthSessionId] is provided. Only call this manually when you need
  /// to consume a session WITHOUT creating a signature (rare edge case).
  Future<void> consumeReauthSession(
    String sessionId,
    String esigId,
  ) async {
    await _supabase.rpc(
      'consume_reauth_session',
      params: {
        'p_session_id': sessionId,
        'p_esig_id': esigId,
      },
    );
  }
}
