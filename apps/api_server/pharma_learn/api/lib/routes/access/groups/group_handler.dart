import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/access/groups/:id - Get group by ID
Future<Response> groupGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('groups')
      .select('*, group_members(employee_id, employees(id, employee_number, full_name))')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Group not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/access/groups/:id - Update group
Future<Response> groupUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'groups.update',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final updateData = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'updated_by': auth.employeeId,
  };

  if (body['name'] != null) updateData['name'] = body['name'];
  if (body['description'] != null) updateData['description'] = body['description'];
  if (body['is_active'] != null) updateData['is_active'] = body['is_active'];

  final result = await supabase
      .from('groups')
      .update(updateData)
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'groups',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
