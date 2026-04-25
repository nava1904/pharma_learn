import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/config/password-policies
///
/// Gets the current password policy configuration.
Future<Response> passwordPolicyGetHandler(Request req) async {
  final supabase = RequestContext.supabase;

  final policy = await supabase
      .from('password_policies')
      .select('*')
      .eq('is_active', true)
      .maybeSingle();

  if (policy == null) {
    // Return defaults
    return ApiResponse.ok({
      'min_length': 8,
      'require_uppercase': true,
      'require_lowercase': true,
      'require_numbers': true,
      'require_special_chars': true,
      'max_age_days': 90,
      'history_count': 5,
      'lockout_attempts': 5,
      'lockout_duration_minutes': 30,
    }).toResponse();
  }

  return ApiResponse.ok(policy).toResponse();
}

/// PATCH /v1/config/password-policies
///
/// Updates the password policy.
Future<Response> passwordPolicyUpdateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to update password policies');
  }

  // Get current active policy
  final existing = await supabase
      .from('password_policies')
      .select('id')
      .eq('is_active', true)
      .maybeSingle();

  final now = DateTime.now().toUtc().toIso8601String();

  final policyData = <String, dynamic>{
    'min_length': body['min_length'] ?? 8,
    'require_uppercase': body['require_uppercase'] ?? true,
    'require_lowercase': body['require_lowercase'] ?? true,
    'require_numbers': body['require_numbers'] ?? true,
    'require_special_chars': body['require_special_chars'] ?? true,
    'max_age_days': body['max_age_days'] ?? 90,
    'history_count': body['history_count'] ?? 5,
    'lockout_attempts': body['lockout_attempts'] ?? 5,
    'lockout_duration_minutes': body['lockout_duration_minutes'] ?? 30,
    'updated_by': auth.employeeId,
    'updated_at': now,
  };

  Map<String, dynamic> policy;
  if (existing != null) {
    policy = await supabase
        .from('password_policies')
        .update(policyData)
        .eq('id', existing['id'])
        .select()
        .single();
  } else {
    policyData['is_active'] = true;
    policyData['created_by'] = auth.employeeId;
    policyData['created_at'] = now;
    policy = await supabase
        .from('password_policies')
        .insert(policyData)
        .select()
        .single();
  }

  return ApiResponse.ok(policy).toResponse();
}

/// GET /v1/config/approval-matrices
///
/// Lists approval matrices.
Future<Response> approvalMatricesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageApprovals)) {
    throw PermissionDeniedException('You do not have permission to view approval matrices');
  }

  final matrices = await supabase
      .from('approval_matrices')
      .select('*')
      .order('entity_type', ascending: true)
      .order('level', ascending: true);

  return ApiResponse.ok(matrices).toResponse();
}

/// GET /v1/config/approval-matrices/:id
///
/// Gets a specific approval matrix.
Future<Response> approvalMatrixGetHandler(Request req) async {
  final matrixId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (matrixId == null || matrixId.isEmpty) {
    throw ValidationException({'id': 'Matrix ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageApprovals)) {
    throw PermissionDeniedException('You do not have permission to view approval matrices');
  }

  final matrix = await supabase
      .from('approval_matrices')
      .select('*')
      .eq('id', matrixId)
      .maybeSingle();

  if (matrix == null) {
    throw NotFoundException('Approval matrix not found');
  }

  return ApiResponse.ok(matrix).toResponse();
}

/// POST /v1/config/approval-matrices
///
/// Creates an approval matrix.
/// Body: { entity_type, level, approver_role_id?, approver_employee_id?, conditions? }
Future<Response> approvalMatrixCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageApprovals)) {
    throw PermissionDeniedException('You do not have permission to create approval matrices');
  }

  final entityType = requireString(body, 'entity_type');
  final level = body['level'] as int? ?? 1;

  final now = DateTime.now().toUtc().toIso8601String();

  final matrix = await supabase
      .from('approval_matrices')
      .insert({
        'entity_type': entityType,
        'level': level,
        'approver_role_id': body['approver_role_id'],
        'approver_employee_id': body['approver_employee_id'],
        'conditions': body['conditions'],
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(matrix).toResponse();
}

/// PATCH /v1/config/approval-matrices/:id
///
/// Updates an approval matrix.
Future<Response> approvalMatrixUpdateHandler(Request req) async {
  final matrixId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (matrixId == null || matrixId.isEmpty) {
    throw ValidationException({'id': 'Matrix ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageApprovals)) {
    throw PermissionDeniedException('You do not have permission to update approval matrices');
  }

  final existing = await supabase
      .from('approval_matrices')
      .select('id')
      .eq('id', matrixId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Approval matrix not found');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = [
    'level', 'approver_role_id', 'approver_employee_id', 'conditions', 'is_active'
  ];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('approval_matrices')
      .update(updateData)
      .eq('id', matrixId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/config/approval-matrices/:id
///
/// Deletes an approval matrix.
Future<Response> approvalMatrixDeleteHandler(Request req) async {
  final matrixId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (matrixId == null || matrixId.isEmpty) {
    throw ValidationException({'id': 'Matrix ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageApprovals)) {
    throw PermissionDeniedException('You do not have permission to delete approval matrices');
  }

  await supabase.from('approval_matrices').delete().eq('id', matrixId);

  return ApiResponse.noContent().toResponse();
}

/// GET /v1/config/numbering-schemes
///
/// Lists numbering schemes.
Future<Response> numberingSchemesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view numbering schemes');
  }

  final schemes = await supabase
      .from('numbering_schemes')
      .select('*')
      .order('entity_type', ascending: true);

  return ApiResponse.ok(schemes).toResponse();
}

/// POST /v1/config/numbering-schemes/:id/next
///
/// Gets the next number in a sequence.
Future<Response> numberingSchemeNextHandler(Request req) async {
  final schemeId = req.rawPathParameters[#id];
  final supabase = RequestContext.supabase;

  if (schemeId == null || schemeId.isEmpty) {
    throw ValidationException({'id': 'Scheme ID is required'});
  }

  // Call RPC to get next number atomically
  final result = await supabase.rpc('get_next_sequence_number', params: {
    'p_scheme_id': schemeId,
  });

  return ApiResponse.ok({
    'next_number': result['next_number'],
    'formatted': result['formatted'],
  }).toResponse();
}

/// GET /v1/config/system-settings
///
/// Gets system settings.
Future<Response> systemSettingsGetHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view system settings');
  }

  final settings = await supabase
      .from('system_settings')
      .select('key, value, description, category')
      .order('category', ascending: true)
      .order('key', ascending: true);

  // Group by category
  final grouped = <String, Map<String, dynamic>>{};
  for (final setting in settings) {
    final category = setting['category'] as String? ?? 'general';
    grouped[category] ??= {};
    grouped[category]![setting['key']] = setting['value'];
  }

  return ApiResponse.ok(grouped).toResponse();
}

/// PATCH /v1/config/system-settings
///
/// Updates system settings.
/// Body: { "key": "value", ... }
Future<Response> systemSettingsUpdateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to update system settings');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  for (final entry in body.entries) {
    await supabase
        .from('system_settings')
        .update({
          'value': entry.value,
          'updated_by': auth.employeeId,
          'updated_at': now,
        })
        .eq('key', entry.key);
  }

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'config.settings_updated',
    'entity_type': 'system_settings',
    'details': {'updated_keys': body.keys.toList()},
    'created_at': now,
  });

  return ApiResponse.ok({'message': 'Settings updated successfully'}).toResponse();
}

/// GET /v1/config/feature-flags
///
/// Gets feature flags.
Future<Response> featureFlagsGetHandler(Request req) async {
  final supabase = RequestContext.supabase;

  final flags = await supabase
      .from('feature_flags')
      .select('key, is_enabled, description')
      .order('key', ascending: true);

  // Convert to map
  final flagMap = <String, bool>{};
  for (final flag in flags) {
    flagMap[flag['key'] as String] = flag['is_enabled'] as bool? ?? false;
  }

  return ApiResponse.ok(flagMap).toResponse();
}

/// PATCH /v1/config/feature-flags
///
/// Updates feature flags.
/// Body: { "flag_key": true/false, ... }
Future<Response> featureFlagsUpdateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to update feature flags');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  for (final entry in body.entries) {
    if (entry.value is bool) {
      await supabase
          .from('feature_flags')
          .update({
            'is_enabled': entry.value,
            'updated_by': auth.employeeId,
            'updated_at': now,
          })
          .eq('key', entry.key);
    }
  }

  return ApiResponse.ok({'message': 'Feature flags updated successfully'}).toResponse();
}
