import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';
import '../../../utils/query_parser.dart';

/// GET /v1/certify/training-matrix
///
/// Lists all training matrices for the organization.
/// Training matrices define required training by role/department.
/// URS Alfa §5.2.4 - Role-based training requirements
Future<Response> trainingMatrixListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final params = req.url.queryParameters;
  final q = QueryParams.fromRequest(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  final offset = (q.page - 1) * q.perPage;

  var query = supabase
      .from('training_matrix')
      .select('''
        id, organization_id, unique_code, name, description, matrix_type,
        department_id, effective_from, effective_to, status,
        initiated_by, initiated_at, approved_by, approved_at,
        created_at, updated_at,
        departments(id, name, code),
        initiator:employees!initiated_by(id, first_name, last_name),
        approver:employees!approved_by(id, first_name, last_name)
      ''')
      .eq('organization_id', auth.orgId);

  if (params['department_id'] != null) {
    query = query.eq('department_id', params['department_id']!);
  }
  if (params['status'] != null) {
    query = query.eq('status', params['status']!);
  }
  if (params['matrix_type'] != null) {
    query = query.eq('matrix_type', params['matrix_type']!);
  }

  final response = await query
      .order('name')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  return ApiResponse.paginated(
    response.data,
    Pagination(
      page: q.page,
      perPage: q.perPage,
      total: response.count,
      totalPages: response.count == 0 ? 1 : (response.count / q.perPage).ceil(),
    ),
  ).toResponse();
}

/// GET /v1/certify/training-matrix/:id
///
/// Returns a single training matrix with all items.
Future<Response> trainingMatrixGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  final matrix = await supabase
      .from('training_matrix')
      .select('''
        id, organization_id, unique_code, name, description, matrix_type,
        department_id, effective_from, effective_to, status,
        initiated_by, initiated_at, approved_by, approved_at,
        created_at, updated_at,
        departments(id, name, code),
        initiator:employees!initiated_by(id, first_name, last_name),
        approver:employees!approved_by(id, first_name, last_name)
      ''')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (matrix == null) {
    throw NotFoundException('Training matrix not found');
  }

  // Get matrix items with details
  final items = await supabase
      .from('training_matrix_items')
      .select('''
        id, matrix_id, role_id, course_id, gtp_id, document_id,
        is_mandatory, frequency_months, priority, sequence_order,
        roles(id, name, role_code),
        courses(id, name, course_code),
        gtp_masters(id, name, gtp_code),
        documents(id, title, doc_number)
      ''')
      .eq('matrix_id', id)
      .order('sequence_order');

  return ApiResponse.ok({
    ...matrix,
    'items': items,
  }).toResponse();
}

/// POST /v1/certify/training-matrix
///
/// Creates a new training matrix.
Future<Response> trainingMatrixCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  final name = requireString(body, 'name');
  final uniqueCode = requireString(body, 'unique_code');
  final effectiveFrom = requireString(body, 'effective_from');

  // Check unique code
  final existing = await supabase
      .from('training_matrix')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('unique_code', uniqueCode)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Training matrix with code $uniqueCode already exists');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final matrix = await supabase
      .from('training_matrix')
      .insert({
        'organization_id': auth.orgId,
        'unique_code': uniqueCode,
        'name': name,
        'description': body['description'],
        'matrix_type': body['matrix_type'] ?? 'role_based',
        'department_id': body['department_id'],
        'effective_from': effectiveFrom,
        'effective_to': body['effective_to'],
        'status': 'draft',
        'initiated_by': auth.employeeId,
        'initiated_at': now,
        'created_at': now,
        'updated_at': now,
      })
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_matrix',
    'entity_id': matrix['id'],
    'action': 'create',
    'new_values': matrix,
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.created(matrix).toResponse();
}

/// PUT /v1/certify/training-matrix/:id
///
/// Updates a training matrix (only in draft status).
Future<Response> trainingMatrixUpdateHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('training_matrix')
      .select('*')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Training matrix not found');
  }

  if (existing['status'] == 'approved') {
    throw ConflictException('Approved matrices cannot be edited. Create a new version.');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final updateData = <String, dynamic>{
    'updated_at': now,
  };

  if (body['name'] != null) updateData['name'] = body['name'];
  if (body['description'] != null) updateData['description'] = body['description'];
  if (body['department_id'] != null) updateData['department_id'] = body['department_id'];
  if (body['effective_from'] != null) updateData['effective_from'] = body['effective_from'];
  if (body['effective_to'] != null) updateData['effective_to'] = body['effective_to'];

  final updated = await supabase
      .from('training_matrix')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_matrix',
    'entity_id': id,
    'action': 'update',
    'old_values': existing,
    'new_values': updated,
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/certify/training-matrix/:id/items
///
/// Adds an item to a training matrix.
Future<Response> trainingMatrixAddItemHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  final matrix = await supabase
      .from('training_matrix')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (matrix == null) {
    throw NotFoundException('Training matrix not found');
  }

  if (matrix['status'] == 'approved') {
    throw ConflictException('Cannot add items to approved matrix');
  }

  final roleId = body['role_id'] as String?;
  final courseId = body['course_id'] as String?;
  final gtpId = body['gtp_id'] as String?;
  final documentId = body['document_id'] as String?;

  if (courseId == null && gtpId == null && documentId == null) {
    throw ValidationException({
      'content': 'At least one of course_id, gtp_id, or document_id is required',
    });
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final item = await supabase
      .from('training_matrix_items')
      .insert({
        'matrix_id': id,
        'role_id': roleId,
        'course_id': courseId,
        'gtp_id': gtpId,
        'document_id': documentId,
        'is_mandatory': body['is_mandatory'] ?? true,
        'frequency_months': body['frequency_months'],
        'priority': body['priority'] ?? 'normal',
        'sequence_order': body['sequence_order'] ?? 0,
        'created_at': now,
      })
      .select('''
        id, matrix_id, role_id, course_id, gtp_id, document_id,
        is_mandatory, frequency_months, priority, sequence_order,
        roles(id, name),
        courses(id, name, course_code),
        gtp_masters(id, name),
        documents(id, title)
      ''')
      .single();

  return ApiResponse.created(item).toResponse();
}

/// DELETE /v1/certify/training-matrix/:id/items/:itemId
///
/// Removes an item from a training matrix.
Future<Response> trainingMatrixRemoveItemHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final itemId = parsePathUuid(req.rawPathParameters[#itemId], fieldName: 'itemId');
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  final matrix = await supabase
      .from('training_matrix')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (matrix == null) {
    throw NotFoundException('Training matrix not found');
  }

  if (matrix['status'] == 'approved') {
    throw ConflictException('Cannot remove items from approved matrix');
  }

  await supabase
      .from('training_matrix_items')
      .delete()
      .eq('id', itemId)
      .eq('matrix_id', id);

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/certify/training-matrix/:id/submit
///
/// Submits training matrix for approval.
Future<Response> trainingMatrixSubmitHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  final matrix = await supabase
      .from('training_matrix')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (matrix == null) {
    throw NotFoundException('Training matrix not found');
  }

  if (matrix['status'] != 'draft') {
    throw ConflictException('Only draft matrices can be submitted');
  }

  // Ensure there's at least one item
  final itemCount = await supabase
      .from('training_matrix_items')
      .select('id')
      .eq('matrix_id', id);

  if ((itemCount as List).isEmpty) {
    throw ValidationException({'items': 'Matrix must have at least one item'});
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final updated = await supabase
      .from('training_matrix')
      .update({
        'status': 'pending_approval',
        'updated_at': now,
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('pending_approvals').insert({
    'organization_id': auth.orgId,
    'entity_type': 'training_matrix',
    'entity_id': id,
    'requested_by': auth.employeeId,
    'requested_at': now,
    'status': 'pending',
  });

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_matrix',
    'entity_id': id,
    'action': 'submit_for_approval',
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/certify/training-matrix/:id/approve
///
/// Approves a training matrix.
Future<Response> trainingMatrixApproveHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  final matrix = await supabase
      .from('training_matrix')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (matrix == null) {
    throw NotFoundException('Training matrix not found');
  }

  if (matrix['status'] != 'pending_approval') {
    throw ConflictException('Only pending matrices can be approved');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Handle e-signature
  final esigData = body['esignature'] as Map<String, dynamic>?;
  String? esigId;
  if (esigData != null) {
    final reauthSessionId = esigData['reauth_session_id'] as String?;
    if (reauthSessionId != null) {
      final esig = await supabase.rpc(
        'create_esignature_from_reauth',
        params: {
          'p_reauth_session_id': reauthSessionId,
          'p_employee_id': auth.employeeId,
          'p_meaning': 'APPROVE',
          'p_context_type': 'training_matrix_approval',
          'p_context_id': id,
        },
      ) as Map<String, dynamic>;
      esigId = esig['esignature_id'] as String?;
    }
  }

  final updated = await supabase
      .from('training_matrix')
      .update({
        'status': 'approved',
        'approved_by': auth.employeeId,
        'approved_at': now,
        'updated_at': now,
      })
      .eq('id', id)
      .select()
      .single();

  await supabase
      .from('pending_approvals')
      .update({
        'status': 'approved',
        'approved_by': auth.employeeId,
        'approved_at': now,
        'esignature_id': esigId,
        'comments': body['comments'],
      })
      .eq('entity_type', 'training_matrix')
      .eq('entity_id', id)
      .eq('status', 'pending');

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_matrix',
    'entity_id': id,
    'action': 'approve',
    'employee_id': auth.employeeId,
    'new_values': {'esignature_id': esigId},
    'created_at': now,
  });

  return ApiResponse.ok(updated).toResponse();
}

/// GET /v1/certify/training-matrix/:id/coverage
///
/// Returns coverage report for a training matrix.
/// Shows which employees have completed required training.
Future<Response> trainingMatrixCoverageHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  final matrix = await supabase
      .from('training_matrix')
      .select('id, name, department_id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (matrix == null) {
    throw NotFoundException('Training matrix not found');
  }

  // Get coverage using RPC function
  final coverage = await supabase.rpc(
    'get_training_matrix_coverage',
    params: {'p_matrix_id': id},
  ) as List;

  return ApiResponse.ok({
    'matrix_id': id,
    'matrix_name': matrix['name'],
    'coverage': coverage,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  }).toResponse();
}

/// GET /v1/certify/training-matrix/:id/gap-analysis
///
/// Returns gap analysis for a training matrix.
/// Shows employees who are missing required training.
Future<Response> trainingMatrixGapAnalysisHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  final matrix = await supabase
      .from('training_matrix')
      .select('id, name, department_id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (matrix == null) {
    throw NotFoundException('Training matrix not found');
  }

  // Get gap analysis using RPC function
  final gaps = await supabase.rpc(
    'get_training_matrix_gaps',
    params: {'p_matrix_id': id},
  ) as List;

  return ApiResponse.ok({
    'matrix_id': id,
    'matrix_name': matrix['name'],
    'gaps': gaps,
    'total_gaps': gaps.length,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  }).toResponse();
}
