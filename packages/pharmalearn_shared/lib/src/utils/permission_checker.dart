import 'package:supabase/supabase.dart';

import 'error_handler.dart';

/// Checks that an employee has a required permission, first inspecting the
/// JWT-embedded [jwtPermissions] list and falling back to the
/// `check_permission` database RPC.
class PermissionChecker {
  final SupabaseClient _supabase;

  PermissionChecker(this._supabase);

  /// Asserts that [employeeId] has [permission].
  ///
  /// If [jwtPermissions] is provided and already contains [permission], the
  /// database is not queried.  Otherwise the `check_permission` Postgres RPC
  /// is called.
  ///
  /// Throws [PermissionDeniedException] when the check fails.
  Future<void> require(
    String employeeId,
    String permission, {
    List<String>? jwtPermissions,
  }) async {
    // Fast path: permission is embedded in the JWT.
    if (jwtPermissions != null && jwtPermissions.contains(permission)) return;

    // Slow path: ask the database.
    final allowed = await _supabase.rpc(
      'check_permission',
      params: {
        'p_employee_id': employeeId,
        'p_permission': permission,
      },
    ) as bool;

    if (!allowed) {
      throw PermissionDeniedException('Missing permission: $permission');
    }
  }

  /// Returns true if [employeeId] has [permission] without throwing.
  Future<bool> has(
    String employeeId,
    String permission, {
    List<String>? jwtPermissions,
  }) async {
    if (jwtPermissions != null && jwtPermissions.contains(permission)) {
      return true;
    }

    final result = await _supabase.rpc(
      'check_permission',
      params: {
        'p_employee_id': employeeId,
        'p_permission': permission,
      },
    );

    return result as bool? ?? false;
  }
}
