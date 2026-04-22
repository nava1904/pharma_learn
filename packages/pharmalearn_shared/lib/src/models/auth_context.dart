/// Authenticated user context injected into `request.context['auth']`
/// by the auth middleware after JWT verification and session validation.
/// 
/// Contains all identity and authorization data needed by handlers to:
/// - Enforce RLS and permission checks
/// - Track audit trails
/// - Enforce induction gate
/// - Handle delegation scenarios
class AuthContext {
  /// GoTrue user UUID (JWT `sub` claim).
  final String userId;

  /// employees.id UUID, resolved from the JWT app_metadata.
  final String employeeId;

  /// organization_id the employee belongs to.
  final String orgId;

  /// plant_id the employee is associated with.
  final String plantId;

  /// department_id the employee belongs to.
  final String? departmentId;

  /// Role ID for RBAC checks.
  final String? roleId;

  /// Role name for display/logging.
  final String? roleName;

  /// Permission strings from JWT `app_metadata.permissions`.
  final List<String> permissions;

  /// Whether the employee has completed mandatory induction training.
  final bool inductionCompleted;

  /// `jti` claim value, which equals the `user_sessions.id` UUID.
  final String sessionId;

  /// Employee number for display/audit.
  final String? employeeNumber;

  /// Employee's full name for display.
  final String? fullName;

  /// Email for notifications.
  final String? email;

  /// Manager's employee ID (for escalation chains).
  final String? managerId;

  /// Whether the employee is a training coordinator.
  final bool isTrainingCoordinator;

  /// Whether the employee is a trainer.
  final bool isTrainer;

  /// Active delegation IDs (delegator → delegatee).
  /// If non-empty, this user is acting on behalf of delegators.
  final List<String> activeDelegationIds;

  /// JWT expiration time.
  final DateTime? tokenExpiresAt;

  const AuthContext({
    required this.userId,
    required this.employeeId,
    required this.orgId,
    required this.plantId,
    this.departmentId,
    this.roleId,
    this.roleName,
    required this.permissions,
    required this.inductionCompleted,
    required this.sessionId,
    this.employeeNumber,
    this.fullName,
    this.email,
    this.managerId,
    this.isTrainingCoordinator = false,
    this.isTrainer = false,
    this.activeDelegationIds = const [],
    this.tokenExpiresAt,
  });

  /// Returns true if this context contains [permission].
  bool hasPermission(String permission) => permissions.contains(permission);

  /// Returns true if this context contains ANY of the given [permissions].
  bool hasAnyPermission(List<String> perms) {
    return perms.any((p) => permissions.contains(p));
  }

  /// Returns true if this context contains ALL of the given [permissions].
  bool hasAllPermissions(List<String> perms) {
    return perms.every((p) => permissions.contains(p));
  }

  /// Returns true if the user has admin-level access.
  bool get isAdmin => hasAnyPermission([
    'super_admin',
    'org_admin', 
    'plant_admin',
  ]);

  /// Returns true if the user can manage training.
  bool get canManageTraining => hasAnyPermission([
    'training.manage',
    'training.coordinators.manage',
  ]) || isTrainingCoordinator;

  /// Returns true if the user can conduct training sessions.
  bool get canConductTraining => hasAnyPermission([
    'training.sessions.manage',
    'training.sessions.conduct',
  ]) || isTrainer;

  /// Returns true if the user has active delegations.
  bool get hasDelegations => activeDelegationIds.isNotEmpty;

  /// Creates a copy with updated fields.
  AuthContext copyWith({
    String? userId,
    String? employeeId,
    String? orgId,
    String? plantId,
    String? departmentId,
    String? roleId,
    String? roleName,
    List<String>? permissions,
    bool? inductionCompleted,
    String? sessionId,
    String? employeeNumber,
    String? fullName,
    String? email,
    String? managerId,
    bool? isTrainingCoordinator,
    bool? isTrainer,
    List<String>? activeDelegationIds,
    DateTime? tokenExpiresAt,
  }) {
    return AuthContext(
      userId: userId ?? this.userId,
      employeeId: employeeId ?? this.employeeId,
      orgId: orgId ?? this.orgId,
      plantId: plantId ?? this.plantId,
      departmentId: departmentId ?? this.departmentId,
      roleId: roleId ?? this.roleId,
      roleName: roleName ?? this.roleName,
      permissions: permissions ?? this.permissions,
      inductionCompleted: inductionCompleted ?? this.inductionCompleted,
      sessionId: sessionId ?? this.sessionId,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      managerId: managerId ?? this.managerId,
      isTrainingCoordinator: isTrainingCoordinator ?? this.isTrainingCoordinator,
      isTrainer: isTrainer ?? this.isTrainer,
      activeDelegationIds: activeDelegationIds ?? this.activeDelegationIds,
      tokenExpiresAt: tokenExpiresAt ?? this.tokenExpiresAt,
    );
  }

  /// Converts to JSON for logging/debugging.
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'employee_id': employeeId,
    'org_id': orgId,
    'plant_id': plantId,
    'department_id': departmentId,
    'role_id': roleId,
    'role_name': roleName,
    'permissions': permissions,
    'induction_completed': inductionCompleted,
    'session_id': sessionId,
    'employee_number': employeeNumber,
    'full_name': fullName,
    'email': email,
    'manager_id': managerId,
    'is_training_coordinator': isTrainingCoordinator,
    'is_trainer': isTrainer,
    'active_delegation_ids': activeDelegationIds,
    'token_expires_at': tokenExpiresAt?.toIso8601String(),
  };

  /// Creates from JWT claims (app_metadata).
  factory AuthContext.fromJwt(Map<String, dynamic> claims) {
    final appMetadata = claims['app_metadata'] as Map<String, dynamic>? ?? {};
    final userMetadata = claims['user_metadata'] as Map<String, dynamic>? ?? {};
    
    return AuthContext(
      userId: claims['sub'] as String,
      employeeId: appMetadata['employee_id'] as String? ?? '',
      orgId: appMetadata['organization_id'] as String? ?? '',
      plantId: appMetadata['plant_id'] as String? ?? '',
      departmentId: appMetadata['department_id'] as String?,
      roleId: appMetadata['role_id'] as String?,
      roleName: appMetadata['role_name'] as String?,
      permissions: List<String>.from(appMetadata['permissions'] ?? []),
      inductionCompleted: appMetadata['induction_completed'] as bool? ?? false,
      sessionId: claims['jti'] as String? ?? '',
      employeeNumber: appMetadata['employee_number'] as String?,
      fullName: userMetadata['full_name'] as String?,
      email: claims['email'] as String?,
      managerId: appMetadata['manager_id'] as String?,
      isTrainingCoordinator: appMetadata['is_training_coordinator'] as bool? ?? false,
      isTrainer: appMetadata['is_trainer'] as bool? ?? false,
      activeDelegationIds: List<String>.from(appMetadata['active_delegation_ids'] ?? []),
      tokenExpiresAt: claims['exp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch((claims['exp'] as int) * 1000)
          : null,
    );
  }

  @override
  String toString() =>
      'AuthContext(userId: $userId, employeeId: $employeeId, orgId: $orgId, '
      'plantId: $plantId, departmentId: $departmentId, roleId: $roleId, '
      'sessionId: $sessionId, inductionCompleted: $inductionCompleted, '
      'isCoordinator: $isTrainingCoordinator, isTrainer: $isTrainer)';
}
