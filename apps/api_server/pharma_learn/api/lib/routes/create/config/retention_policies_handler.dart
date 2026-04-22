import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/config/retention-policies
///
/// Lists all retention policies with regulatory minimums.
/// Retention policies define how long records must be kept per regulation.
Future<Response> retentionPoliciesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view retention policies');
  }

  final policies = await supabase
      .from('retention_policies')
      .select('''
        id, entity_type, regulation, retention_years, 
        regulatory_floor_years, description, is_active,
        created_at, updated_at
      ''')
      .order('entity_type', ascending: true);

  return ApiResponse.ok(policies).toResponse();
}

/// GET /v1/config/retention-policies/:id
///
/// Gets a specific retention policy.
Future<Response> retentionPolicyGetHandler(Request req) async {
  final policyId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (policyId == null || policyId.isEmpty) {
    throw ValidationException({'id': 'Policy ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view retention policies');
  }

  final policy = await supabase
      .from('retention_policies')
      .select('*')
      .eq('id', policyId)
      .maybeSingle();

  if (policy == null) {
    throw NotFoundException('Retention policy not found');
  }

  return ApiResponse.ok(policy).toResponse();
}

/// POST /v1/config/retention-policies
///
/// Creates a new retention policy.
/// Body: {
///   entity_type: 'training_records' | 'audit_trails' | 'clinical_data' | ...,
///   regulation: 'WHO_GMP' | 'ICH_E6_R2' | '21_CFR_Part_11' | ...,
///   retention_years: number,
///   regulatory_floor_years: number,  // Minimum per regulation (e.g., GMP=6, Clinical=7)
///   description?: string
/// }
Future<Response> retentionPolicyCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to create retention policies');
  }

  final entityType = requireString(body, 'entity_type');
  final regulation = requireString(body, 'regulation');
  
  // Get retention years with validation
  final retentionYearsRaw = body['retention_years'];
  if (retentionYearsRaw == null) {
    throw ValidationException({'retention_years': 'retention_years is required'});
  }
  final retentionYears = retentionYearsRaw is int 
      ? retentionYearsRaw 
      : int.parse(retentionYearsRaw.toString());
  
  final regulatoryFloorYears = body['regulatory_floor_years'] as int? ?? _getDefaultFloor(regulation);

  // Validate retention meets regulatory minimum
  if (retentionYears < regulatoryFloorYears) {
    throw ValidationException({
      'retention_years': 
          'Retention period ($retentionYears years) cannot be less than '
          'regulatory floor ($regulatoryFloorYears years) for $regulation'
    });
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final policy = await supabase
      .from('retention_policies')
      .insert({
        'entity_type': entityType,
        'regulation': regulation,
        'retention_years': retentionYears,
        'regulatory_floor_years': regulatoryFloorYears,
        'description': body['description'],
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'config.retention_policy_created',
    'entity_type': 'retention_policies',
    'entity_id': policy['id'],
    'details': {
      'entity_type': entityType,
      'regulation': regulation,
      'retention_years': retentionYears,
    },
    'created_at': now,
  });

  return ApiResponse.created(policy).toResponse();
}

/// PATCH /v1/config/retention-policies/:id
///
/// Updates a retention policy.
/// Note: Cannot reduce retention_years below regulatory_floor_years.
Future<Response> retentionPolicyUpdateHandler(Request req) async {
  final policyId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (policyId == null || policyId.isEmpty) {
    throw ValidationException({'id': 'Policy ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to update retention policies');
  }

  final existing = await supabase
      .from('retention_policies')
      .select('id, regulatory_floor_years')
      .eq('id', policyId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Retention policy not found');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  // Check retention_years against floor
  if (body.containsKey('retention_years')) {
    final newRetention = body['retention_years'] as int;
    final floor = existing['regulatory_floor_years'] as int? ?? 0;
    if (newRetention < floor) {
      throw ValidationException({
        'retention_years': 
            'Retention period ($newRetention years) cannot be less than '
            'regulatory floor ($floor years)'
      });
    }
    updateData['retention_years'] = newRetention;
  }

  final allowedFields = ['description', 'is_active'];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('retention_policies')
      .update(updateData)
      .eq('id', policyId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/config/retention-policies/:id
///
/// Deletes a retention policy.
/// WARNING: This is a soft-delete (sets is_active=false).
Future<Response> retentionPolicyDeleteHandler(Request req) async {
  final policyId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (policyId == null || policyId.isEmpty) {
    throw ValidationException({'id': 'Policy ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to delete retention policies');
  }

  // Soft delete - set is_active to false
  await supabase
      .from('retention_policies')
      .update({
        'is_active': false,
        'updated_by': auth.employeeId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', policyId);

  return ApiResponse.noContent().toResponse();
}

/// Returns the regulatory floor years for a given regulation.
int _getDefaultFloor(String regulation) {
  switch (regulation.toUpperCase()) {
    case 'WHO_GMP':
    case 'WHO GMP':
      return 6; // WHO GMP requires 6 years minimum
    case 'ICH_E6_R2':
    case 'ICH E6(R2)':
      return 7; // Clinical trial data requires 7 years minimum
    case '21_CFR_PART_11':
    case '21 CFR Part 11':
      return 5; // FDA Part 11 requires 5 years minimum
    case 'EU_GMP':
    case 'EU GMP':
      return 5; // EU GMP requires 5 years minimum
    default:
      return 5; // Default to 5 years
  }
}
