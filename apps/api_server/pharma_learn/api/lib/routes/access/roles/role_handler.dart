import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/roles/:id
Future<Response> roleGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewRoles,
    jwtPermissions: auth.permissions,
  );

  final role = await supabase
      .from('roles')
      .select('*, role_permissions ( permission )')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (role == null) throw NotFoundException('Role not found');

  return ApiResponse.ok({'role': role}).toResponse();
}

/// PATCH /v1/roles/:id
Future<Response> rolePatchHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final updates = <String, dynamic>{};

  if (body.containsKey('name')) updates['name'] = body['name'];
  if (body.containsKey('description')) {
    updates['description'] = body['description'];
  }

  if (updates.isNotEmpty) {
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await supabase
        .from('roles')
        .update(updates)
        .eq('id', id)
        .eq('organization_id', auth.orgId);
  }

  if (body.containsKey('permissions')) {
    final perms = (body['permissions'] as List)
        .map((e) => e.toString())
        .toList();

    await supabase.from('role_permissions').delete().eq('role_id', id);
    if (perms.isNotEmpty) {
      await supabase.from('role_permissions').insert(
        perms
            .map((p) => {
                  'role_id': id,
                  'permission': p,
                  'granted_by': auth.employeeId,
                })
            .toList(),
      );
    }
  }

  final updated = await supabase
      .from('roles')
      .select('*, role_permissions ( permission )')
      .eq('id', id)
      .single();

  return ApiResponse.ok({'role': updated}).toResponse();
}

/// DELETE /v1/roles/:id
Future<Response> roleDeleteHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageRoles,
    jwtPermissions: auth.permissions,
  );

  // Check if any employees still hold this role
  final countResult = await supabase
      .from('employee_roles')
      .select('id')
      .eq('role_id', id)
      .count(CountOption.exact);

  if (countResult.count > 0) {
    throw ConflictException(
      'Cannot delete role while it is assigned to employees. '
      'Remove all role assignments first.',
    );
  }

  await supabase
      .from('roles')
      .delete()
      .eq('id', id)
      .eq('organization_id', auth.orgId);

  return ApiResponse.noContent().toResponse();
}
