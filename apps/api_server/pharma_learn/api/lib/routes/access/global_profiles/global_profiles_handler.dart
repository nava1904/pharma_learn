import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/access/global-profiles
///
/// Lists all global profiles (role-level permission matrices).
Future<Response> globalProfilesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final query = req.url.queryParameters;

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view global profiles');
  }

  var builder = supabase
      .from('global_profiles')
      .select('''
        id, name, description, 
        has_admin_access, has_approval_access, has_report_access,
        status, revision_no, is_active, created_at, updated_at,
        role:roles(id, name, description)
      ''')
      .eq('organization_id', auth.orgId);

  if (query['role_id'] != null) {
    builder = builder.eq('role_id', query['role_id']!);
  }
  if (query['is_active'] != null) {
    builder = builder.eq('is_active', query['is_active'] == 'true');
  }
  if (query['status'] != null) {
    builder = builder.eq('status', query['status']!);
  }

  final result = await builder.order('name');

  return ApiResponse.ok({
    'global_profiles': result,
  }).toResponse();
}

/// POST /v1/access/global-profiles
///
/// Creates a new global profile for a role.
Future<Response> globalProfileCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to create global profiles');
  }

  final roleId = requireUuid(body, 'role_id');
  final name = body['name'] as String?;
  final description = body['description'] as String?;
  final permissionsJson = body['permissions_json'] as Map<String, dynamic>? ?? {};
  final hasAdminAccess = body['has_admin_access'] as bool? ?? false;
  final hasApprovalAccess = body['has_approval_access'] as bool? ?? false;
  final hasReportAccess = body['has_report_access'] as bool? ?? false;

  // Check if profile already exists for this role
  final existing = await supabase
      .from('global_profiles')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('role_id', roleId)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('A global profile already exists for this role');
  }

  // Verify role exists
  final role = await supabase
      .from('roles')
      .select('id, name')
      .eq('id', roleId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (role == null) {
    throw NotFoundException('Role not found');
  }

  final result = await supabase
      .from('global_profiles')
      .insert({
        'organization_id': auth.orgId,
        'role_id': roleId,
        'name': name ?? role['name'],
        'description': description,
        'permissions_json': permissionsJson,
        'has_admin_access': hasAdminAccess,
        'has_approval_access': hasApprovalAccess,
        'has_report_access': hasReportAccess,
        'status': 'initiated',
        'is_active': true,
        'created_by': auth.employeeId,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'global_profile',
    aggregateId: result['id'] as String,
    eventType: 'global_profile.created',
    payload: {'role_id': roleId},
  );

  return ApiResponse.created({
    'global_profile': result,
    'message': 'Global profile created successfully',
  }).toResponse();
}

/// GET /v1/access/global-profiles/:id
Future<Response> globalProfileGetHandler(Request req) async {
  final profileId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view global profiles');
  }

  if (profileId == null || profileId.isEmpty) {
    throw ValidationException({'id': 'Global profile ID is required'});
  }

  final result = await supabase
      .from('global_profiles')
      .select('''
        id, name, description, permissions_json,
        has_admin_access, has_approval_access, has_report_access,
        status, revision_no, is_active, created_at, updated_at,
        role:roles(id, name, description)
      ''')
      .eq('id', profileId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    throw NotFoundException('Global profile not found');
  }

  return ApiResponse.ok({'global_profile': result}).toResponse();
}

/// PATCH /v1/access/global-profiles/:id
Future<Response> globalProfileUpdateHandler(Request req) async {
  final profileId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to update global profiles');
  }

  if (profileId == null || profileId.isEmpty) {
    throw ValidationException({'id': 'Global profile ID is required'});
  }

  final existing = await supabase
      .from('global_profiles')
      .select('id, status')
      .eq('id', profileId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Global profile not found');
  }

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  if (body['name'] != null) updates['name'] = body['name'];
  if (body['description'] != null) updates['description'] = body['description'];
  if (body['permissions_json'] != null) updates['permissions_json'] = body['permissions_json'];
  if (body['has_admin_access'] != null) updates['has_admin_access'] = body['has_admin_access'];
  if (body['has_approval_access'] != null) updates['has_approval_access'] = body['has_approval_access'];
  if (body['has_report_access'] != null) updates['has_report_access'] = body['has_report_access'];
  if (body['is_active'] != null) updates['is_active'] = body['is_active'];

  final result = await supabase
      .from('global_profiles')
      .update(updates)
      .eq('id', profileId)
      .select()
      .single();

  return ApiResponse.ok({
    'global_profile': result,
    'message': 'Global profile updated successfully',
  }).toResponse();
}

/// DELETE /v1/access/global-profiles/:id
Future<Response> globalProfileDeleteHandler(Request req) async {
  final profileId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to delete global profiles');
  }

  if (profileId == null || profileId.isEmpty) {
    throw ValidationException({'id': 'Global profile ID is required'});
  }

  await supabase
      .from('global_profiles')
      .update({
        'is_active': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', profileId)
      .eq('organization_id', auth.orgId);

  return ApiResponse.ok({
    'message': 'Global profile deactivated successfully',
  }).toResponse();
}

/// POST /v1/access/global-profiles/:id/submit
Future<Response> globalProfileSubmitHandler(Request req) async {
  final profileId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to submit global profiles');
  }

  if (profileId == null || profileId.isEmpty) {
    throw ValidationException({'id': 'Global profile ID is required'});
  }

  final existing = await supabase
      .from('global_profiles')
      .select('id, status')
      .eq('id', profileId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Global profile not found');
  }

  if (existing['status'] != 'initiated' && existing['status'] != 'rejected') {
    throw ConflictException('Global profile cannot be submitted from current status');
  }

  final result = await supabase
      .from('global_profiles')
      .update({
        'status': 'pending_approval',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', profileId)
      .select()
      .single();

  return ApiResponse.ok({
    'global_profile': result,
    'message': 'Global profile submitted for approval',
  }).toResponse();
}

/// POST /v1/access/global-profiles/:id/approve
Future<Response> globalProfileApproveHandler(Request req) async {
  final profileId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to approve global profiles');
  }

  if (profileId == null || profileId.isEmpty) {
    throw ValidationException({'id': 'Global profile ID is required'});
  }

  final existing = await supabase
      .from('global_profiles')
      .select('id, status, role_id')
      .eq('id', profileId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Global profile not found');
  }

  if (existing['status'] != 'pending_approval') {
    throw ConflictException('Global profile is not pending approval');
  }

  // E-signature
  final esig = body['esig'] as Map<String, dynamic>?;
  String? esigId;
  if (esig != null) {
    final esigService = EsigService(supabase);
    esigId = await esigService.createEsignature(
      employeeId: auth.employeeId,
      meaning: esig['meaning'] as String? ?? 'APPROVE_GLOBAL_PROFILE',
      entityType: 'global_profile',
      entityId: profileId,
      reauthSessionId: esig['reauth_session_id'] as String?,
    );
  }

  final result = await supabase
      .from('global_profiles')
      .update({
        'status': 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', profileId)
      .select()
      .single();

  return ApiResponse.ok({
    'global_profile': result,
    'message': 'Global profile approved and activated',
    'esignature_id': esigId,
  }).toResponse();
}

/// GET /v1/access/roles/:id/profile
///
/// Gets the global profile for a specific role.
Future<Response> roleGlobalProfileHandler(Request req) async {
  final roleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (roleId == null || roleId.isEmpty) {
    throw ValidationException({'id': 'Role ID is required'});
  }

  final result = await supabase
      .from('global_profiles')
      .select('''
        id, name, description, permissions_json,
        has_admin_access, has_approval_access, has_report_access,
        status, is_active
      ''')
      .eq('role_id', roleId)
      .eq('organization_id', auth.orgId)
      .eq('is_active', true)
      .eq('status', 'active')
      .maybeSingle();

  if (result == null) {
    return ApiResponse.ok({
      'global_profile': null,
      'message': 'No active global profile found for this role',
    }).toResponse();
  }

  return ApiResponse.ok({'global_profile': result}).toResponse();
}

/// POST /v1/access/global-profiles/:id/permissions/check
///
/// Checks if a specific permission is granted in a profile.
Future<Response> globalProfileCheckPermissionHandler(Request req) async {
  final profileId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (profileId == null || profileId.isEmpty) {
    throw ValidationException({'id': 'Global profile ID is required'});
  }

  final module = requireString(body, 'module');
  final action = requireString(body, 'action');
  final subModule = body['sub_module'] as String?;

  final profile = await supabase
      .from('global_profiles')
      .select('permissions_json')
      .eq('id', profileId)
      .eq('organization_id', auth.orgId)
      .eq('is_active', true)
      .maybeSingle();

  if (profile == null) {
    throw NotFoundException('Global profile not found');
  }

  final permissions = profile['permissions_json'] as Map<String, dynamic>? ?? {};
  bool hasPermission = false;

  if (subModule != null) {
    hasPermission = (permissions[module]?[subModule]?[action] as bool?) ?? false;
  } else {
    hasPermission = (permissions[module]?[action] as bool?) ?? false;
  }

  return ApiResponse.ok({
    'module': module,
    'sub_module': subModule,
    'action': action,
    'has_permission': hasPermission,
  }).toResponse();
}
