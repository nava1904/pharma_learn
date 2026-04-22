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

  /// The authenticated user's context, or null if not set.
  AuthContext? get authOrNull => RequestContext.authOrNull;

  /// The service-role [SupabaseClient] injected by auth_middleware.
  SupabaseClient get supabase => RequestContext.supabase;

  /// The e-signature context, set by [withEsig] middleware. Null on non-esig routes.
  EsigContext? get esig => RequestContext.esig;

  /// The parsed request body cached by [withEsig]. Null if esig middleware not applied.
  Map<String, dynamic>? get cachedBody => RequestContext.body;

  /// The audit context for the current request.
  AuditContext? get audit => getAuditContext();

  /// Check if user has a specific permission.
  bool hasPermission(String permission) => auth.hasPermission(permission);

  /// Check if user has any of the given permissions.
  bool hasAnyPermission(List<String> permissions) => auth.hasAnyPermission(permissions);

  /// Check if user has all of the given permissions.
  bool hasAllPermissions(List<String> permissions) => auth.hasAllPermissions(permissions);

  /// Check if user is admin (super_admin, org_admin, or plant_admin).
  bool get isAdmin => auth.isAdmin;

  /// Check if user can manage training.
  bool get canManageTraining => auth.canManageTraining;

  /// Check if user can conduct training sessions.
  bool get canConductTraining => auth.canConductTraining;

  /// The employee ID of the authenticated user.
  String get employeeId => auth.employeeId;

  /// The organization ID of the authenticated user.
  String get orgId => auth.orgId;

  /// The plant ID of the authenticated user.
  String get plantId => auth.plantId;
}
