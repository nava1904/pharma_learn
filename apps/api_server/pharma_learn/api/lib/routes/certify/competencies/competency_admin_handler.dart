import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/certify/competency-definitions
///
/// Lists all competency definitions for the organization.
Future<Response> competencyDefinitionsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  final status = req.url.queryParameters['status'];
  final level = req.url.queryParameters['level'];

  var query = supabase
      .from('competency_definitions')
      .select('''
        id, code, name, description, level, category,
        status, required_training_hours, validity_months,
        created_at, updated_at
      ''')
      .eq('organization_id', auth.orgId);

  if (status != null) {
    query = query.eq('status', status);
  }
  if (level != null) {
    query = query.eq('level', level);
  }

  final results = await query
      .order('name', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  return ApiResponse.ok({
    'competencies': results,
    'pagination': {
      'page': page,
      'per_page': perPage,
    },
  }).toResponse();
}

/// GET /v1/certify/competency-definitions/:id
///
/// Gets a specific competency definition.
Future<Response> competencyDefinitionGetHandler(Request req) async {
  final competencyId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final result = await supabase
      .from('competency_definitions')
      .select('''
        id, code, name, description, level, category,
        status, required_training_hours, validity_months,
        prerequisite_competencies,
        created_at, updated_at,
        job_role_competencies!inner(
          job_roles!inner(id, name)
        )
      ''')
      .eq('id', competencyId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    throw NotFoundException('Competency definition not found');
  }

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/certify/competency-definitions
///
/// Creates a new competency definition.
///
/// Body:
/// ```json
/// {
///   "code": "COMP-001",
///   "name": "GMP Awareness",
///   "description": "Basic Good Manufacturing Practices",
///   "level": "basic",
///   "category": "compliance",
///   "required_training_hours": 8,
///   "validity_months": 24,
///   "prerequisite_competencies": []
/// }
/// ```
Future<Response> competencyDefinitionCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Verify user has permission to manage competencies
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompetencies,
    jwtPermissions: auth.permissions,
  );

  // Validate required fields
  final code = body['code'] as String?;
  final name = body['name'] as String?;
  
  if (code == null || code.trim().isEmpty) {
    throw ValidationException({'code': 'Competency code is required'});
  }
  if (name == null || name.trim().isEmpty) {
    throw ValidationException({'name': 'Competency name is required'});
  }

  // Check for duplicate code
  final existing = await supabase
      .from('competency_definitions')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('code', code.trim())
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Competency with code "$code" already exists');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final result = await supabase.from('competency_definitions').insert({
    'organization_id': auth.orgId,
    'code': code.trim(),
    'name': name.trim(),
    'description': body['description'] as String?,
    'level': body['level'] as String? ?? 'basic',
    'category': body['category'] as String?,
    'required_training_hours': body['required_training_hours'] as int?,
    'validity_months': body['validity_months'] as int?,
    'prerequisite_competencies': body['prerequisite_competencies'] as List? ?? [],
    'status': 'active',
    'created_by': auth.employeeId,
    'created_at': now,
    'updated_at': now,
  }).select().single();

  return ApiResponse.created(result).toResponse();
}

/// PATCH /v1/certify/competency-definitions/:id
///
/// Updates a competency definition.
Future<Response> competencyDefinitionUpdateHandler(Request req) async {
  final competencyId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Verify user has permission to manage competencies
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompetencies,
    jwtPermissions: auth.permissions,
  );

  // Check competency exists
  final existing = await supabase
      .from('competency_definitions')
      .select('id, code')
      .eq('id', competencyId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Competency definition not found');
  }

  // If code is being changed, check for duplicates
  final newCode = body['code'] as String?;
  if (newCode != null && newCode.trim() != existing['code']) {
    final duplicate = await supabase
        .from('competency_definitions')
        .select('id')
        .eq('organization_id', auth.orgId)
        .eq('code', newCode.trim())
        .neq('id', competencyId)
        .maybeSingle();

    if (duplicate != null) {
      throw ConflictException('Competency with code "$newCode" already exists');
    }
  }

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'updated_by': auth.employeeId,
  };

  if (newCode != null) updates['code'] = newCode.trim();
  if (body['name'] != null) updates['name'] = (body['name'] as String).trim();
  if (body['description'] != null) updates['description'] = body['description'];
  if (body['level'] != null) updates['level'] = body['level'];
  if (body['category'] != null) updates['category'] = body['category'];
  if (body['required_training_hours'] != null) {
    updates['required_training_hours'] = body['required_training_hours'];
  }
  if (body['validity_months'] != null) {
    updates['validity_months'] = body['validity_months'];
  }
  if (body['prerequisite_competencies'] != null) {
    updates['prerequisite_competencies'] = body['prerequisite_competencies'];
  }
  if (body['status'] != null) updates['status'] = body['status'];

  final result = await supabase
      .from('competency_definitions')
      .update(updates)
      .eq('id', competencyId)
      .select()
      .single();

  return ApiResponse.ok(result).toResponse();
}

/// DELETE /v1/certify/competency-definitions/:id
///
/// Soft-deletes a competency definition (sets status to 'inactive').
/// Cannot delete if employees have active competencies linked.
Future<Response> competencyDefinitionDeleteHandler(Request req) async {
  final competencyId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify user has permission to manage competencies
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompetencies,
    jwtPermissions: auth.permissions,
  );

  // Check competency exists
  final existing = await supabase
      .from('competency_definitions')
      .select('id, status')
      .eq('id', competencyId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Competency definition not found');
  }

  if (existing['status'] == 'inactive') {
    throw ConflictException('Competency is already inactive');
  }

  // Check for active employee competencies
  final activeCount = await supabase
      .from('employee_competencies')
      .select('id')
      .eq('competency_definition_id', competencyId)
      .eq('status', 'active')
      .count();

  if (activeCount.count > 0) {
    throw ConflictException(
      'Cannot delete competency with ${activeCount.count} active employee records. '
      'Revoke employee competencies first.',
    );
  }

  // Soft delete
  await supabase.from('competency_definitions').update({
    'status': 'inactive',
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'updated_by': auth.employeeId,
  }).eq('id', competencyId);

  return ApiResponse.ok({
    'id': competencyId,
    'status': 'inactive',
    'message': 'Competency definition deactivated',
  }).toResponse();
}

/// POST /v1/certify/competencies/:id/assess
///
/// Records that an employee has attained a competency.
/// Can be from training completion, assessment, or manual award.
///
/// Body:
/// ```json
/// {
///   "employee_id": "uuid",
///   "source": "training|assessment|manual",
///   "source_id": "uuid",
///   "esignature": {
///     "reauth_session_id": "uuid",
///     "meaning": "APPROVE"
///   },
///   "notes": "Optional notes"
/// }
/// ```
Future<Response> competencyAssessHandler(Request req) async {
  final competencyId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final employeeId = body['employee_id'] as String?;
  final source = body['source'] as String?;
  final sourceId = body['source_id'] as String?;
  final esigData = body['esignature'] as Map<String, dynamic>?;
  final notes = body['notes'] as String?;

  if (employeeId == null) {
    throw ValidationException({'employee_id': 'Employee ID is required'});
  }
  if (source == null || !['training', 'assessment', 'manual'].contains(source)) {
    throw ValidationException({'source': 'Source must be training, assessment, or manual'});
  }
  if (esigData == null || esigData['reauth_session_id'] == null) {
    throw ValidationException({'esignature': 'E-signature is required'});
  }

  // Verify user has permission
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompetencies,
    jwtPermissions: auth.permissions,
  );

  // Verify competency exists and is active
  final competency = await supabase
      .from('competency_definitions')
      .select('id, validity_months, status')
      .eq('id', competencyId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (competency == null) {
    throw NotFoundException('Competency definition not found');
  }
  if (competency['status'] != 'active') {
    throw ValidationException({'competency': 'Competency is not active'});
  }

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

  // Check for existing active competency
  final existingActive = await supabase
      .from('employee_competencies')
      .select('id')
      .eq('employee_id', employeeId)
      .eq('competency_definition_id', competencyId)
      .eq('status', 'active')
      .maybeSingle();

  if (existingActive != null) {
    throw ConflictException('Employee already has an active record for this competency');
  }

  // Create e-signature
  final esig = await supabase.rpc(
    'create_esignature_from_reauth',
    params: {
      'p_reauth_session_id': esigData['reauth_session_id'],
      'p_employee_id': auth.employeeId,
      'p_meaning': 'APPROVE',
      'p_context_type': 'competency_award',
      'p_context_id': competencyId,
    },
  ) as Map<String, dynamic>;

  final now = DateTime.now().toUtc();
  final validityMonths = competency['validity_months'] as int?;
  final expiresAt = validityMonths != null
      ? now.add(Duration(days: validityMonths * 30))
      : null;

  // Create employee competency record
  final result = await supabase.from('employee_competencies').insert({
    'organization_id': auth.orgId,
    'employee_id': employeeId,
    'competency_definition_id': competencyId,
    'source': source,
    'source_id': sourceId,
    'awarded_at': now.toIso8601String(),
    'awarded_by': auth.employeeId,
    'expires_at': expiresAt?.toIso8601String(),
    'status': 'active',
    'notes': notes,
    'esignature_id': esig['esignature_id'],
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
  }).select().single();

  return ApiResponse.created(result).toResponse();
}
