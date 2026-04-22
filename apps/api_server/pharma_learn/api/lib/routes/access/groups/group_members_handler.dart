import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/access/groups/:id/members - List group members
Future<Response> groupMembersListHandler(Request req, String groupId) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final q = QueryParams.fromRequest(req);
  final offset = (q.page - 1) * q.perPage;

  final response = await supabase
      .from('group_members')
      .select('*, employees(id, employee_number, full_name, email, department_id, role_id)')
      .eq('group_id', groupId)
      .eq('org_id', auth.orgId)
      .order('created_at', ascending: false)
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  final pagination = Pagination(
    page: q.page,
    perPage: q.perPage,
    total: response.count,
    totalPages: response.count == 0 ? 1 : (response.count / q.perPage).ceil(),
  );

  return ApiResponse.paginated(response.data, pagination).toResponse();
}

/// POST /v1/access/groups/:id/members - Add members to group
Future<Response> groupMembersAddHandler(Request req, String groupId) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'groups.manage_members',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;
  final employeeIds = (body['employee_ids'] as List?)?.cast<String>() ?? [];

  if (employeeIds.isEmpty) {
    return ErrorResponse.validation({'employee_ids': 'employee_ids is required and must not be empty'}).toResponse();
  }

  // Insert members (ON CONFLICT DO NOTHING for idempotency)
  final insertData = employeeIds.map((empId) => {
    'group_id': groupId,
    'employee_id': empId,
    'added_by': auth.employeeId,
    'org_id': auth.orgId,
  }).toList();

  await supabase.from('group_members').upsert(
    insertData,
    onConflict: 'group_id,employee_id',
    ignoreDuplicates: true,
  );

  await supabase.from('audit_trails').insert({
    'entity_type': 'group_members',
    'entity_id': groupId,
    'action': 'ADD_MEMBERS',
    'performed_by': auth.employeeId,
    'changes': {'added_employee_ids': employeeIds},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok({
    'group_id': groupId,
    'added_count': employeeIds.length,
  }).toResponse();
}

/// DELETE /v1/access/groups/:id/members/:employeeId - Remove member from group
Future<Response> groupMemberRemoveHandler(Request req, String groupId, String employeeId) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'groups.manage_members',
    jwtPermissions: auth.permissions,
  );

  await supabase
      .from('group_members')
      .delete()
      .eq('group_id', groupId)
      .eq('employee_id', employeeId)
      .eq('org_id', auth.orgId);

  await supabase.from('audit_trails').insert({
    'entity_type': 'group_members',
    'entity_id': groupId,
    'action': 'REMOVE_MEMBER',
    'performed_by': auth.employeeId,
    'changes': {'removed_employee_id': employeeId},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok({
    'group_id': groupId,
    'removed_employee_id': employeeId,
  }).toResponse();
}
