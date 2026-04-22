import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/access/subgroups
///
/// Lists all subgroups (functional role groups) in the organization.
Future<Response> subgroupsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final query = req.url.queryParameters;

  var builder = supabase
      .from('subgroups')
      .select('''
        id, name, unique_code, description,
        job_responsibility_template, default_training_types,
        mandatory_courses, status, revision_no, is_active,
        created_at, updated_at
      ''')
      .eq('organization_id', auth.orgId);

  if (query['status'] != null) {
    builder = builder.eq('status', query['status']!);
  }
  if (query['is_active'] != null) {
    builder = builder.eq('is_active', query['is_active'] == 'true');
  }
  if (query['search'] != null) {
    final search = '%${query['search']}%';
    builder = builder.or('name.ilike.$search,unique_code.ilike.$search');
  }

  final page = int.tryParse(query['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(query['per_page'] ?? '50') ?? 50;
  final from = (page - 1) * perPage;

  final result = await builder
      .order('name')
      .range(from, from + perPage - 1);

  return ApiResponse.ok({
    'subgroups': result,
    'page': page,
    'per_page': perPage,
  }).toResponse();
}

/// POST /v1/access/subgroups
///
/// Creates a new subgroup.
Future<Response> subgroupCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to create subgroups');
  }

  final name = requireString(body, 'name');
  final uniqueCode = requireString(body, 'unique_code');
  final description = body['description'] as String?;
  final jobRespTemplate = body['job_responsibility_template'] as String?;
  final defaultTrainingTypes = body['default_training_types'] as List?;
  final mandatoryCourses = body['mandatory_courses'] as List?;

  // Check unique code
  final existing = await supabase
      .from('subgroups')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('unique_code', uniqueCode)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Subgroup with code $uniqueCode already exists');
  }

  final result = await supabase
      .from('subgroups')
      .insert({
        'organization_id': auth.orgId,
        'name': name,
        'unique_code': uniqueCode,
        'description': description,
        'job_responsibility_template': jobRespTemplate,
        'default_training_types': defaultTrainingTypes,
        'mandatory_courses': mandatoryCourses,
        'status': 'initiated',
        'is_active': true,
        'created_by': auth.employeeId,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'subgroup',
    aggregateId: result['id'] as String,
    eventType: 'subgroup.created',
    payload: {'name': name},
  );

  return ApiResponse.created({
    'subgroup': result,
    'message': 'Subgroup created successfully',
  }).toResponse();
}

/// GET /v1/access/subgroups/:id
Future<Response> subgroupGetHandler(Request req) async {
  final subgroupId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (subgroupId == null || subgroupId.isEmpty) {
    throw ValidationException({'id': 'Subgroup ID is required'});
  }

  final result = await supabase
      .from('subgroups')
      .select('''
        id, name, unique_code, description,
        job_responsibility_template, default_training_types,
        mandatory_courses, status, revision_no, is_active,
        created_at, updated_at
      ''')
      .eq('id', subgroupId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    throw NotFoundException('Subgroup not found');
  }

  // Get member count
  final memberCount = await supabase
      .from('employee_subgroups')
      .select('id')
      .eq('subgroup_id', subgroupId)
      .eq('is_active', true);

  return ApiResponse.ok({
    'subgroup': result,
    'member_count': (memberCount as List).length,
  }).toResponse();
}

/// PATCH /v1/access/subgroups/:id
Future<Response> subgroupUpdateHandler(Request req) async {
  final subgroupId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to update subgroups');
  }

  if (subgroupId == null || subgroupId.isEmpty) {
    throw ValidationException({'id': 'Subgroup ID is required'});
  }

  final existing = await supabase
      .from('subgroups')
      .select('id')
      .eq('id', subgroupId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Subgroup not found');
  }

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  if (body['name'] != null) updates['name'] = body['name'];
  if (body['description'] != null) updates['description'] = body['description'];
  if (body['job_responsibility_template'] != null) {
    updates['job_responsibility_template'] = body['job_responsibility_template'];
  }
  if (body['default_training_types'] != null) {
    updates['default_training_types'] = body['default_training_types'];
  }
  if (body['mandatory_courses'] != null) {
    updates['mandatory_courses'] = body['mandatory_courses'];
  }
  if (body['is_active'] != null) updates['is_active'] = body['is_active'];

  final result = await supabase
      .from('subgroups')
      .update(updates)
      .eq('id', subgroupId)
      .select()
      .single();

  return ApiResponse.ok({
    'subgroup': result,
    'message': 'Subgroup updated successfully',
  }).toResponse();
}

/// DELETE /v1/access/subgroups/:id
Future<Response> subgroupDeleteHandler(Request req) async {
  final subgroupId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to delete subgroups');
  }

  if (subgroupId == null || subgroupId.isEmpty) {
    throw ValidationException({'id': 'Subgroup ID is required'});
  }

  // Check for active members
  final members = await supabase
      .from('employee_subgroups')
      .select('id')
      .eq('subgroup_id', subgroupId)
      .eq('is_active', true)
      .limit(1);

  if ((members as List).isNotEmpty) {
    throw ConflictException('Cannot delete subgroup with active members');
  }

  await supabase
      .from('subgroups')
      .update({
        'is_active': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', subgroupId)
      .eq('organization_id', auth.orgId);

  return ApiResponse.ok({
    'message': 'Subgroup deactivated successfully',
  }).toResponse();
}

/// GET /v1/access/subgroups/:id/members
///
/// Lists employees assigned to this subgroup.
Future<Response> subgroupMembersListHandler(Request req) async {
  final subgroupId = req.rawPathParameters[#id];
  final supabase = RequestContext.supabase;

  if (subgroupId == null || subgroupId.isEmpty) {
    throw ValidationException({'id': 'Subgroup ID is required'});
  }

  final result = await supabase
      .from('employee_subgroups')
      .select('''
        id, is_primary, valid_from, valid_until, assigned_at, is_active,
        employee:employees(
          id, employee_number, first_name, last_name, email, designation
        )
      ''')
      .eq('subgroup_id', subgroupId)
      .eq('is_active', true)
      .order('is_primary', ascending: false);

  return ApiResponse.ok({
    'subgroup_id': subgroupId,
    'members': result,
    'count': (result as List).length,
  }).toResponse();
}

/// POST /v1/access/subgroups/:id/members
///
/// Adds an employee to a subgroup.
Future<Response> subgroupMemberAddHandler(Request req) async {
  final subgroupId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to manage subgroup members');
  }

  if (subgroupId == null || subgroupId.isEmpty) {
    throw ValidationException({'id': 'Subgroup ID is required'});
  }

  final employeeId = requireUuid(body, 'employee_id');
  final isPrimary = body['is_primary'] as bool? ?? false;
  final validFromStr = body['valid_from'] as String?;
  final validUntilStr = body['valid_until'] as String?;
  final assignedReason = body['assigned_reason'] as String?;

  // Check if already assigned
  final existing = await supabase
      .from('employee_subgroups')
      .select('id, is_active')
      .eq('employee_id', employeeId)
      .eq('subgroup_id', subgroupId)
      .maybeSingle();

  if (existing != null && existing['is_active'] == true) {
    throw ConflictException('Employee is already a member of this subgroup');
  }

  // If setting as primary, unset other primaries
  if (isPrimary) {
    await supabase
        .from('employee_subgroups')
        .update({'is_primary': false})
        .eq('employee_id', employeeId)
        .eq('is_primary', true);
  }

  final result = await supabase
      .from('employee_subgroups')
      .upsert({
        'employee_id': employeeId,
        'subgroup_id': subgroupId,
        'is_primary': isPrimary,
        'valid_from': validFromStr,
        'valid_until': validUntilStr,
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
        'assigned_by': auth.employeeId,
        'assigned_reason': assignedReason,
        'is_active': true,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'employee_subgroup',
    aggregateId: result['id'] as String,
    eventType: 'employee.subgroup_assigned',
    payload: {
      'employee_id': employeeId,
      'subgroup_id': subgroupId,
      'is_primary': isPrimary,
    },
  );

  return ApiResponse.created({
    'assignment': result,
    'message': 'Employee added to subgroup',
  }).toResponse();
}

/// DELETE /v1/access/subgroups/:id/members/:employeeId
///
/// Removes an employee from a subgroup.
Future<Response> subgroupMemberRemoveHandler(Request req) async {
  final subgroupId = req.rawPathParameters[#id];
  final employeeId = req.rawPathParameters[#employeeId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to manage subgroup members');
  }

  if (subgroupId == null || employeeId == null) {
    throw ValidationException({'id': 'Subgroup ID and Employee ID are required'});
  }

  await supabase
      .from('employee_subgroups')
      .update({
        'is_active': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('subgroup_id', subgroupId)
      .eq('employee_id', employeeId);

  return ApiResponse.ok({
    'message': 'Employee removed from subgroup',
  }).toResponse();
}

/// POST /v1/access/subgroups/:id/submit
Future<Response> subgroupSubmitHandler(Request req) async {
  final subgroupId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to submit subgroups');
  }

  if (subgroupId == null || subgroupId.isEmpty) {
    throw ValidationException({'id': 'Subgroup ID is required'});
  }

  final existing = await supabase
      .from('subgroups')
      .select('id, status')
      .eq('id', subgroupId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Subgroup not found');
  }

  if (existing['status'] != 'initiated' && existing['status'] != 'rejected') {
    throw ConflictException('Subgroup cannot be submitted from current status');
  }

  final result = await supabase
      .from('subgroups')
      .update({
        'status': 'pending_approval',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', subgroupId)
      .select()
      .single();

  return ApiResponse.ok({
    'subgroup': result,
    'message': 'Subgroup submitted for approval',
  }).toResponse();
}

/// POST /v1/access/subgroups/:id/approve
Future<Response> subgroupApproveHandler(Request req) async {
  final subgroupId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to approve subgroups');
  }

  if (subgroupId == null || subgroupId.isEmpty) {
    throw ValidationException({'id': 'Subgroup ID is required'});
  }

  final existing = await supabase
      .from('subgroups')
      .select('id, status, name')
      .eq('id', subgroupId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Subgroup not found');
  }

  if (existing['status'] != 'pending_approval') {
    throw ConflictException('Subgroup is not pending approval');
  }

  // Create e-signature
  final esig = body['esig'] as Map<String, dynamic>?;
  String? esigId;
  if (esig != null) {
    final esigService = EsigService(supabase);
    esigId = await esigService.createEsignature(
      employeeId: auth.employeeId,
      meaning: esig['meaning'] as String? ?? 'APPROVE_SUBGROUP',
      entityType: 'subgroup',
      entityId: subgroupId,
      reauthSessionId: esig['reauth_session_id'] as String?,
    );
  }

  final result = await supabase
      .from('subgroups')
      .update({
        'status': 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', subgroupId)
      .select()
      .single();

  return ApiResponse.ok({
    'subgroup': result,
    'message': 'Subgroup approved successfully',
    'esignature_id': esigId,
  }).toResponse();
}
