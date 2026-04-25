/// Authenticated user context injected into `request.context['auth']`
/// by the auth middleware after JWT verification and session validation.
class AuthContext {
  /// GoTrue user UUID (JWT `sub` claim).
  final String userId;

  /// employees.id UUID, resolved from the JWT app_metadata.
  final String employeeId;

  /// organization_id the employee belongs to.
  final String orgId;

  /// plant_id the employee is associated with.
  final String plantId;

  /// Permission strings from JWT `app_metadata.permissions`.
  final List<String> permissions;

  /// Whether the employee has completed mandatory induction training.
  final bool inductionCompleted;

  /// `jti` claim value, which equals the `user_sessions.id` UUID.
  final String sessionId;

  const AuthContext({
    required this.userId,
    required this.employeeId,
    required this.orgId,
    required this.plantId,
    required this.permissions,
    required this.inductionCompleted,
    required this.sessionId,
  });

  /// Returns true if this context contains [permission].
  bool hasPermission(String permission) => permissions.contains(permission);

  @override
  String toString() =>
      'AuthContext(userId: $userId, employeeId: $employeeId, orgId: $orgId, '
      'plantId: $plantId, sessionId: $sessionId, '
      'inductionCompleted: $inductionCompleted)';
}
