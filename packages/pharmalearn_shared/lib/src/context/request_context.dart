import 'dart:async';

import '../models/auth_context.dart';
import '../client/supabase_client.dart';
import 'package:supabase/supabase.dart';

// ---------------------------------------------------------------------------
// Request Context Storage
// ---------------------------------------------------------------------------
// Since Relic doesn't have a built-in context dictionary, we use Dart Zones
// to store request-scoped data. This is a common pattern for request context.
// ---------------------------------------------------------------------------

/// Zone keys for request-scoped data.
final _authContextKey = Object();
final _supabaseClientKey = Object();
final _bodyKey = Object();
final _esigContextKey = Object();

/// Stores request-scoped data using Dart Zones.
class RequestContext {
  /// Gets the [AuthContext] for the current request.
  /// Throws if no auth context is available.
  static AuthContext get auth {
    final ctx = Zone.current[_authContextKey] as AuthContext?;
    if (ctx == null) {
      throw StateError('No AuthContext available in current zone. '
          'Ensure authMiddleware is applied.');
    }
    return ctx;
  }

  /// Gets the [AuthContext] for the current request, or null if not available.
  static AuthContext? get authOrNull {
    return Zone.current[_authContextKey] as AuthContext?;
  }

  /// Gets the [SupabaseClient] for the current request.
  static SupabaseClient get supabase {
    final client = Zone.current[_supabaseClientKey] as SupabaseClient?;
    return client ?? SupabaseService.client;
  }

  /// Gets the cached request body (for e-sig middleware).
  static Map<String, dynamic>? get body {
    return Zone.current[_bodyKey] as Map<String, dynamic>?;
  }

  /// Gets the [EsigContext] for the current request, if available.
  static EsigContext? get esig {
    return Zone.current[_esigContextKey] as EsigContext?;
  }

  /// Runs a callback with the given [AuthContext] in a new zone.
  static Future<T> withAuth<T>(
    AuthContext auth,
    Future<T> Function() callback,
  ) {
    return runZoned(callback, zoneValues: {_authContextKey: auth});
  }

  /// Runs a callback with the given [SupabaseClient] in a new zone.
  static Future<T> withSupabase<T>(
    SupabaseClient client,
    Future<T> Function() callback,
  ) {
    return runZoned(callback, zoneValues: {_supabaseClientKey: client});
  }

  /// Runs a callback with the given body in a new zone.
  static Future<T> withBody<T>(
    Map<String, dynamic> body,
    Future<T> Function() callback,
  ) {
    return runZoned(callback, zoneValues: {_bodyKey: body});
  }

  /// Runs a callback with the given [EsigContext] in a new zone.
  static Future<T> withEsig<T>(
    EsigContext esig,
    Future<T> Function() callback,
  ) {
    return runZoned(callback, zoneValues: {_esigContextKey: esig});
  }

  /// Runs a callback with all context values in a new zone.
  static Future<T> withAll<T>({
    AuthContext? auth,
    SupabaseClient? supabase,
    Map<String, dynamic>? body,
    EsigContext? esig,
    required Future<T> Function() callback,
  }) {
    final values = <Object, Object?>{};
    if (auth != null) values[_authContextKey] = auth;
    if (supabase != null) values[_supabaseClientKey] = supabase;
    if (body != null) values[_bodyKey] = body;
    if (esig != null) values[_esigContextKey] = esig;
    return runZoned(callback, zoneValues: values);
  }
}

/// E-signature context for the current request.
class EsigContext {
  final String reauthSessionId;
  final String employeeId;
  final String meaning;
  final String? reason;
  final bool isFirstInSession;
  final DateTime expiresAt;

  const EsigContext({
    required this.reauthSessionId,
    required this.employeeId,
    required this.meaning,
    this.reason,
    required this.isFirstInSession,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'reauth_session_id': reauthSessionId,
        'employee_id': employeeId,
        'meaning': meaning,
        'reason': reason,
        'is_first_in_session': isFirstInSession,
        'expires_at': expiresAt.toIso8601String(),
      };
}
