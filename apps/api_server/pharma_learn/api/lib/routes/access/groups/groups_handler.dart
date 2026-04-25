import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/groups
///
/// Lists employee groups.
Future<Response> groupsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;

  // Count
  final countResult = await supabase.from('employee_groups').select('id');
  final total = countResult.length;

  // Data
  final groups = await supabase
      .from('employee_groups')
      .select('''
        id, name, description, group_type, is_active, created_at,
        employee_group_members(count)
      ''')
      .order('name', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  // Transform to include member count
  final data = groups.map((g) {
    final members = g['employee_group_members'] as List? ?? [];
    return {
      ...Map<String, dynamic>.from(g as Map)..remove('employee_group_members'),
      'member_count': members.isEmpty ? 0 : (members[0]['count'] ?? 0),
    };
  }).toList();

  return ApiResponse.paginated(
    data,
    Pagination.compute(page: page, perPage: perPage, total: total),
  ).toResponse();
}

/// GET /v1/groups/:id
///
/// Gets a specific group with members.
Future<Response> groupGetHandler(Request req) async {
  final groupId = req.rawPathParameters[#id];
  final supabase = RequestContext.supabase;

  if (groupId == null || groupId.isEmpty) {
    throw ValidationException({'id': 'Group ID is required'});
  }

  final group = await supabase
      .from('employee_groups')
      .select('''
        *,
        employee_group_members(
          id, joined_at,
          employees(id, first_name, last_name, email)
        )
      ''')
      .eq('id', groupId)
      .maybeSingle();

  if (group == null) {
    throw NotFoundException('Group not found');
  }

  return ApiResponse.ok(group).toResponse();
}

/// POST /v1/groups
///
/// Creates a new employee group.
/// Body: { name, description?, group_type }
Future<Response> groupCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to create groups');
  }

  final name = requireString(body, 'name');
  final groupType = requireString(body, 'group_type');

  // Check name uniqueness
  final existing = await supabase
      .from('employee_groups')
      .select('id')
      .eq('name', name)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('A group with this name already exists');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final group = await supabase
      .from('employee_groups')
      .insert({
        'name': name,
        'description': body['description'],
        'group_type': groupType,
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(group).toResponse();
}

/// PATCH /v1/groups/:id
///
/// Updates a group.
Future<Response> groupUpdateHandler(Request req) async {
  final groupId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (groupId == null || groupId.isEmpty) {
    throw ValidationException({'id': 'Group ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to update groups');
  }

  final existing = await supabase
      .from('employee_groups')
      .select('id')
      .eq('id', groupId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Group not found');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = ['name', 'description', 'group_type', 'is_active'];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('employee_groups')
      .update(updateData)
      .eq('id', groupId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/groups/:id
///
/// Deletes a group (if empty).
Future<Response> groupDeleteHandler(Request req) async {
  final groupId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (groupId == null || groupId.isEmpty) {
    throw ValidationException({'id': 'Group ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to delete groups');
  }

  // Check if group has members
  final members = await supabase
      .from('employee_group_members')
      .select('id')
      .eq('group_id', groupId)
      .limit(1);

  if (members.isNotEmpty) {
    throw ConflictException('Cannot delete a group with members. Remove all members first.');
  }

  await supabase.from('employee_groups').delete().eq('id', groupId);

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/groups/:id/members
///
/// Adds members to a group.
/// Body: { employee_ids: [uuid, ...] }
Future<Response> groupAddMembersHandler(Request req) async {
  final groupId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (groupId == null || groupId.isEmpty) {
    throw ValidationException({'id': 'Group ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to manage group members');
  }

  final employeeIds = body['employee_ids'] as List?;
  if (employeeIds == null || employeeIds.isEmpty) {
    throw ValidationException({'employee_ids': 'At least one employee ID is required'});
  }

  // Verify group exists
  final group = await supabase
      .from('employee_groups')
      .select('id')
      .eq('id', groupId)
      .maybeSingle();

  if (group == null) {
    throw NotFoundException('Group not found');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Insert members (ignore duplicates)
  for (final empId in employeeIds) {
    await supabase.from('employee_group_members').upsert(
      {
        'group_id': groupId,
        'employee_id': empId,
        'joined_at': now,
        'added_by': auth.employeeId,
      },
      onConflict: 'group_id,employee_id',
    );
  }

  return ApiResponse.ok({'message': 'Members added successfully'}).toResponse();
}

/// DELETE /v1/groups/:id/members/:employeeId
///
/// Removes a member from a group.
Future<Response> groupRemoveMemberHandler(Request req) async {
  final groupId = req.rawPathParameters[#id];
  final employeeId = req.rawPathParameters[#employeeId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (groupId == null || employeeId == null) {
    throw ValidationException({'id': 'Group ID and Employee ID are required'});
  }

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to manage group members');
  }

  await supabase
      .from('employee_group_members')
      .delete()
      .eq('group_id', groupId)
      .eq('employee_id', employeeId);

  return ApiResponse.noContent().toResponse();
}
