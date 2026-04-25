import 'package:pharmalearn_shared/pharmalearn_shared.dart';
import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart';

/// Convenience extension on [Request] that delegates to the Zone-based
/// [RequestContext] populated by auth_middleware and esig_middleware.
///
/// Use these getters inside handlers instead of calling [RequestContext]
/// directly for cleaner handler code.
extension RequestContextExt on Request {
  /// The authenticated user's context. Throws if not set (i.e., on a public path).
  AuthContext get auth => RequestContext.auth;

  /// The service-role [SupabaseClient] injected by auth_middleware.
  SupabaseClient get supabase => RequestContext.supabase;

  /// The e-signature context, set by [withEsig] middleware. Null on non-esig routes.
  EsigContext? get esig => RequestContext.esig;

  /// The parsed request body cached by [withEsig]. Null if esig middleware not applied.
  Map<String, dynamic>? get cachedBody => RequestContext.body;
}
