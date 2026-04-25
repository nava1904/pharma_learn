import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/employees/:id/roles
Future<Response> employeeRolesListHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewRoles,
    jwtPermissions: auth.permissions,
  );

  final rows = await supabase
      .from('employee_roles')
      .select('roles ( id, name, description ), assigned_at, assigned_by')
      .eq('employee_id', employeeId);

  return ApiResponse.ok({
    'employee_id': employeeId,
    'roles': (rows as List).map((r) {
      final role = r['roles'] as Map<String, dynamic>? ?? {};
      return {
        ...role,
        'assigned_at': r['assigned_at'],
        'assigned_by': r['assigned_by'],
      };
    }).toList(),
  }).toResponse();
}

/// POST /v1/employees/:id/roles — assign a role
///
/// Body: `{"role_id": "UUID"}`
Future<Response> employeeRolesAssignHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final roleId = body['role_id'] as String?;
  if (roleId == null || roleId.isEmpty) {
    throw ValidationException({'role_id': 'Required'});
  }

  await supabase.from('employee_roles').upsert({
    'employee_id': employeeId,
    'role_id': roleId,
    'assigned_by': auth.employeeId,
    'assigned_at': DateTime.now().toUtc().toIso8601String(),
  }, onConflict: 'employee_id,role_id');

  return ApiResponse.created({
    'employee_id': employeeId,
    'role_id': roleId,
  }).toResponse();
}

/// DELETE /v1/employees/:id/roles/:roleId — remove a role
Future<Response> employeeRolesRemoveHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final roleId = parsePathUuid(req.rawPathParameters[#roleId]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  await supabase
      .from('employee_roles')
      .delete()
      .eq('employee_id', employeeId)
      .eq('role_id', roleId);

  return ApiResponse.noContent().toResponse();
}
