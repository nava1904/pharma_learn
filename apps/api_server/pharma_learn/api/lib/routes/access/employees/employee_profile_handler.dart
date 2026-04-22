import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/access/employees/:id/profile
///
/// Gets the effective permission profile for an employee.
/// This aggregates permissions from roles, global profiles, and direct assignments.
Future<Response> employeeProfileGetHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Can view own profile, or need viewEmployees permission
  if (employeeId != auth.employeeId) {
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.viewEmployees,
      jwtPermissions: auth.permissions,
    );
  }

  // Get employee with roles
  final employee = await supabase
      .from('employees')
      .select('''
        id, full_name, employee_number, email, status,
        department:departments!employees_department_id_fkey (
          id, name
        ),
        roles:employee_roles (
          role:roles (
            id, name, code, hierarchy_level,
            profile:global_profiles!roles_global_profile_id_fkey (
              id, name, permissions
            )
          ),
          is_primary, effective_from, effective_to
        )
      ''')
      .eq('id', employeeId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  // Get direct permission overrides (if any)
  final directPermissions = await supabase
      .from('employee_permission_overrides')
      .select('permission, granted, granted_by, granted_at, expires_at, reason')
      .eq('employee_id', employeeId)
      .eq('is_active', true);

  // Calculate effective permissions
  final effectivePermissions = <String, dynamic>{};
  final permissionSources = <String, List<Map<String, dynamic>>>{};

  // Aggregate from roles
  for (final roleAssignment in employee['roles'] as List) {
    final role = roleAssignment['role'] as Map<String, dynamic>?;
    if (role == null) continue;
    
    final profile = role['profile'] as Map<String, dynamic>?;
    if (profile == null) continue;
    
    final permissions = profile['permissions'] as List? ?? [];
    for (final perm in permissions) {
      final permStr = perm.toString();
      effectivePermissions[permStr] = true;
      permissionSources.putIfAbsent(permStr, () => []);
      permissionSources[permStr]!.add({
        'source': 'role',
        'role_name': role['name'],
        'role_id': role['id'],
        'profile_name': profile['name'],
      });
    }
  }

  // Apply direct overrides
  for (final override in directPermissions as List) {
    final perm = override['permission'] as String;
    final granted = override['granted'] as bool;
    
    if (granted) {
      effectivePermissions[perm] = true;
      permissionSources.putIfAbsent(perm, () => []);
      permissionSources[perm]!.add({
        'source': 'direct_grant',
        'granted_by': override['granted_by'],
        'reason': override['reason'],
        'expires_at': override['expires_at'],
      });
    } else {
      // Explicit denial overrides role grants
      effectivePermissions[perm] = false;
      permissionSources[perm] = [{
        'source': 'direct_denial',
        'granted_by': override['granted_by'],
        'reason': override['reason'],
      }];
    }
  }

  return ApiResponse.ok({
    'employee': {
      'id': employee['id'],
      'full_name': employee['full_name'],
      'employee_number': employee['employee_number'],
      'email': employee['email'],
      'department': employee['department'],
    },
    'roles': employee['roles'],
    'direct_overrides': directPermissions,
    'effective_permissions': effectivePermissions.keys
        .where((k) => effectivePermissions[k] == true)
        .toList(),
    'permission_sources': permissionSources,
  }).toResponse();
}

/// PUT /v1/access/employees/:id/profile
///
/// Assigns a global profile to an employee's primary role.
Future<Response> employeeProfileAssignHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  final globalProfileId = requireString(body, 'global_profile_id');

  // Verify profile exists and is approved
  final profile = await supabase
      .from('global_profiles')
      .select('id, name, status')
      .eq('id', globalProfileId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (profile == null) {
    throw NotFoundException('Global profile not found');
  }
  if (profile['status'] != 'approved') {
    throw ValidationException({'global_profile_id': 'Profile must be approved before assignment'});
  }

  // Get employee's primary role
  final primaryRole = await supabase
      .from('employee_roles')
      .select('role_id')
      .eq('employee_id', employeeId)
      .eq('is_primary', true)
      .maybeSingle();

  if (primaryRole == null) {
    throw ValidationException({'employee': 'Employee has no primary role'});
  }

  // Update the role's global profile
  await supabase
      .from('roles')
      .update({
        'global_profile_id': globalProfileId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', primaryRole['role_id']);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_profile',
    'entity_id': employeeId,
    'action': 'PROFILE_ASSIGNED',
    'event_category': 'ACCESS_CONTROL',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': {
      'global_profile_id': globalProfileId,
      'profile_name': profile['name'],
    },
  });

  return ApiResponse.ok({
    'message': 'Profile assigned successfully',
    'profile': profile,
  }).toResponse();
}

/// POST /v1/access/employees/:id/permissions/grant
///
/// Grants a direct permission override to an employee.
Future<Response> employeePermissionGrantHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  final permission = requireString(body, 'permission');
  final reason = body['reason'] as String?;
  final expiresAt = body['expires_at'] as String?;

  // Verify employee exists
  final employee = await supabase
      .from('employees')
      .select('id')
      .eq('id', employeeId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Upsert the permission override
  await supabase
      .from('employee_permission_overrides')
      .upsert({
        'employee_id': employeeId,
        'permission': permission,
        'granted': true,
        'granted_by': auth.employeeId,
        'granted_at': now,
        'expires_at': expiresAt,
        'reason': reason,
        'is_active': true,
      }, onConflict: 'employee_id,permission');

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_permission',
    'entity_id': employeeId,
    'action': 'PERMISSION_GRANTED',
    'event_category': 'ACCESS_CONTROL',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': {
      'permission': permission,
      'reason': reason,
      'expires_at': expiresAt,
    },
  });

  return ApiResponse.ok({
    'message': 'Permission granted successfully',
    'permission': permission,
    'employee_id': employeeId,
  }).toResponse();
}

/// POST /v1/access/employees/:id/permissions/revoke
///
/// Revokes a direct permission from an employee.
Future<Response> employeePermissionRevokeHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  final permission = requireString(body, 'permission');
  final reason = body['reason'] as String?;

  final now = DateTime.now().toUtc().toIso8601String();

  // Update or insert a denial override
  await supabase
      .from('employee_permission_overrides')
      .upsert({
        'employee_id': employeeId,
        'permission': permission,
        'granted': false,
        'granted_by': auth.employeeId,
        'granted_at': now,
        'reason': reason,
        'is_active': true,
      }, onConflict: 'employee_id,permission');

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_permission',
    'entity_id': employeeId,
    'action': 'PERMISSION_REVOKED',
    'event_category': 'ACCESS_CONTROL',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': {
      'permission': permission,
      'reason': reason,
    },
  });

  return ApiResponse.ok({
    'message': 'Permission revoked successfully',
    'permission': permission,
    'employee_id': employeeId,
  }).toResponse();
}

/// DELETE /v1/access/employees/:id/permissions/:permission
///
/// Removes a direct permission override (returns to role-based).
Future<Response> employeePermissionRemoveHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final permission = req.rawPathParameters[#permission];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (permission == null || permission.isEmpty) {
    throw ValidationException({'permission': 'Permission is required'});
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  // Deactivate the override
  await supabase
      .from('employee_permission_overrides')
      .update({'is_active': false})
      .eq('employee_id', employeeId)
      .eq('permission', permission);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_permission',
    'entity_id': employeeId,
    'action': 'PERMISSION_OVERRIDE_REMOVED',
    'event_category': 'ACCESS_CONTROL',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': {'permission': permission},
  });

  return ApiResponse.noContent().toResponse();
}

/// GET /v1/access/employees/:id/permissions
///
/// Lists all direct permission overrides for an employee.
Future<Response> employeePermissionsListHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Can view own permissions, or need viewEmployees permission
  if (employeeId != auth.employeeId) {
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.viewEmployees,
      jwtPermissions: auth.permissions,
    );
  }

  final overrides = await supabase
      .from('employee_permission_overrides')
      .select('''
        id, permission, granted, granted_at, expires_at, reason, is_active,
        grantor:employees!employee_permission_overrides_granted_by_fkey (
          id, full_name
        )
      ''')
      .eq('employee_id', employeeId);

  // Also get permissions from roles
  final rolePermissions = await supabase.rpc(
    'get_employee_permissions',
    params: {'p_employee_id': employeeId},
  );

  return ApiResponse.ok({
    'direct_overrides': overrides,
    'role_permissions': rolePermissions,
  }).toResponse();
}

/// POST /v1/access/employees/:id/permissions/bulk
///
/// Bulk update permissions for an employee.
Future<Response> employeePermissionsBulkHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  final grants = body['grants'] as List? ?? [];
  final revokes = body['revokes'] as List? ?? [];
  final reason = body['reason'] as String?;

  final now = DateTime.now().toUtc().toIso8601String();
  var grantCount = 0;
  var revokeCount = 0;

  // Process grants
  for (final perm in grants) {
    await supabase
        .from('employee_permission_overrides')
        .upsert({
          'employee_id': employeeId,
          'permission': perm.toString(),
          'granted': true,
          'granted_by': auth.employeeId,
          'granted_at': now,
          'reason': reason,
          'is_active': true,
        }, onConflict: 'employee_id,permission');
    grantCount++;
  }

  // Process revokes
  for (final perm in revokes) {
    await supabase
        .from('employee_permission_overrides')
        .upsert({
          'employee_id': employeeId,
          'permission': perm.toString(),
          'granted': false,
          'granted_by': auth.employeeId,
          'granted_at': now,
          'reason': reason,
          'is_active': true,
        }, onConflict: 'employee_id,permission');
    revokeCount++;
  }

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_permission',
    'entity_id': employeeId,
    'action': 'PERMISSIONS_BULK_UPDATE',
    'event_category': 'ACCESS_CONTROL',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': {
      'grants': grants,
      'revokes': revokes,
      'reason': reason,
    },
  });

  return ApiResponse.ok({
    'message': 'Permissions updated successfully',
    'grants_processed': grantCount,
    'revokes_processed': revokeCount,
  }).toResponse();
}
