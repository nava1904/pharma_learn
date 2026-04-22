import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';
import '../../../utils/query_parser.dart';

/// GET /v1/subjects
///
/// Lists all subjects for the organization.
/// URS Alfa §5.4.1 - Master data management for subjects
///
/// Query params:
/// - category_id: Filter by category
/// - status: Filter by status
/// - is_active: Filter by active status
/// - search: Search by name or code
Future<Response> subjectsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final params = req.url.queryParameters;
  final q = QueryParams.fromRequest(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCourses,
    jwtPermissions: auth.permissions,
  );

  final offset = (q.page - 1) * q.perPage;

  var query = supabase
      .from('subjects')
      .select('''
        id, organization_id, category_id, name, unique_code, description,
        status, revision_no, is_active, created_at, updated_at, created_by,
        categories(id, name, unique_code)
      ''')
      .eq('organization_id', auth.orgId);

  // Apply filters
  if (params['category_id'] != null) {
    query = query.eq('category_id', params['category_id']!);
  }
  if (params['status'] != null) {
    query = query.eq('status', params['status']!);
  }
  if (params['is_active'] != null) {
    query = query.eq('is_active', params['is_active'] == 'true');
  }
  if (params['search'] != null && params['search']!.isNotEmpty) {
    query = query.or('name.ilike.%${params['search']}%,unique_code.ilike.%${params['search']}%');
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

/// GET /v1/subjects/:id
///
/// Returns a single subject by ID.
Future<Response> subjectGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCourses,
    jwtPermissions: auth.permissions,
  );

  final subject = await supabase
      .from('subjects')
      .select('''
        id, organization_id, category_id, name, unique_code, description,
        status, revision_no, is_active, created_at, updated_at, created_by,
        categories(id, name, unique_code),
        employees!created_by(id, first_name, last_name)
      ''')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (subject == null) {
    throw NotFoundException('Subject not found');
  }

  return ApiResponse.ok(subject).toResponse();
}

/// POST /v1/subjects
///
/// Creates a new subject.
///
/// Body:
/// ```json
/// {
///   "name": "Pharma Regulations",
///   "unique_code": "SUB-001",
///   "description": "Subject covering pharma regulations",
///   "category_id": "uuid"
/// }
/// ```
Future<Response> subjectCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final name = requireString(body, 'name');
  final uniqueCode = requireString(body, 'unique_code');
  final categoryId = optionalString(body, 'category_id');

  // Check unique code doesn't already exist
  final existing = await supabase
      .from('subjects')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('unique_code', uniqueCode)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Subject with code $uniqueCode already exists');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final subject = await supabase
      .from('subjects')
      .insert({
        'organization_id': auth.orgId,
        'category_id': categoryId,
        'name': name,
        'unique_code': uniqueCode,
        'description': body['description'],
        'status': 'initiated',
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
        'updated_at': now,
      })
      .select('''
        id, organization_id, category_id, name, unique_code, description,
        status, revision_no, is_active, created_at, updated_at, created_by,
        categories(id, name, unique_code)
      ''')
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'subject',
    'entity_id': subject['id'],
    'action': 'create',
    'new_values': subject,
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.created(subject).toResponse();
}

/// PUT /v1/subjects/:id
///
/// Updates an existing subject.
Future<Response> subjectUpdateHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  // Get existing subject
  final existing = await supabase
      .from('subjects')
      .select('*')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Subject not found');
  }

  // Check for approved status - can't edit directly
  if (existing['status'] == 'approved') {
    throw ConflictException('Approved subjects cannot be edited directly. Create a new revision.');
  }

  // If unique_code is changing, verify uniqueness
  if (body['unique_code'] != null && body['unique_code'] != existing['unique_code']) {
    final duplicate = await supabase
        .from('subjects')
        .select('id')
        .eq('organization_id', auth.orgId)
        .eq('unique_code', body['unique_code'])
        .neq('id', id)
        .maybeSingle();

    if (duplicate != null) {
      throw ConflictException('Subject with code ${body['unique_code']} already exists');
    }
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final updateData = <String, dynamic>{
    'updated_at': now,
  };

  if (body['name'] != null) updateData['name'] = body['name'];
  if (body['unique_code'] != null) updateData['unique_code'] = body['unique_code'];
  if (body['description'] != null) updateData['description'] = body['description'];
  if (body['category_id'] != null) updateData['category_id'] = body['category_id'];
  if (body['is_active'] != null) updateData['is_active'] = body['is_active'];

  final updated = await supabase
      .from('subjects')
      .update(updateData)
      .eq('id', id)
      .select('''
        id, organization_id, category_id, name, unique_code, description,
        status, revision_no, is_active, created_at, updated_at, created_by,
        categories(id, name, unique_code)
      ''')
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'subject',
    'entity_id': id,
    'action': 'update',
    'old_values': existing,
    'new_values': updated,
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/subjects/:id
///
/// Soft-deletes a subject by setting is_active to false.
Future<Response> subjectDeleteHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('subjects')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Subject not found');
  }

  if (existing['status'] == 'approved') {
    throw ConflictException('Approved subjects cannot be deleted. Deactivate instead.');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('subjects')
      .update({
        'is_active': false,
        'status': 'obsolete',
        'updated_at': now,
      })
      .eq('id', id);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'subject',
    'entity_id': id,
    'action': 'delete',
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/subjects/:id/submit
///
/// Submits a subject for approval.
Future<Response> subjectSubmitHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.editCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('subjects')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Subject not found');
  }

  if (existing['status'] != 'initiated') {
    throw ConflictException('Only draft subjects can be submitted for approval');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final updated = await supabase
      .from('subjects')
      .update({
        'status': 'pending_approval',
        'updated_at': now,
      })
      .eq('id', id)
      .select()
      .single();

  // Create pending approval record
  await supabase.from('pending_approvals').insert({
    'organization_id': auth.orgId,
    'entity_type': 'subject',
    'entity_id': id,
    'requested_by': auth.employeeId,
    'requested_at': now,
    'status': 'pending',
  });

  // Audit
  await supabase.from('audit_trails').insert({
    'entity_type': 'subject',
    'entity_id': id,
    'action': 'submit_for_approval',
    'employee_id': auth.employeeId,
    'created_at': now,
  });

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/subjects/:id/approve
///
/// Approves a subject.
Future<Response> subjectApproveHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.approveCourses,
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('subjects')
      .select('id, status')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Subject not found');
  }

  if (existing['status'] != 'pending_approval') {
    throw ConflictException('Only pending subjects can be approved');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Handle e-signature if provided
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
          'p_context_type': 'subject_approval',
          'p_context_id': id,
        },
      ) as Map<String, dynamic>;
      esigId = esig['esignature_id'] as String?;
    }
  }

  final updated = await supabase
      .from('subjects')
      .update({
        'status': 'approved',
        'updated_at': now,
      })
      .eq('id', id)
      .select()
      .single();

  // Update pending approval
  await supabase
      .from('pending_approvals')
      .update({
        'status': 'approved',
        'approved_by': auth.employeeId,
        'approved_at': now,
        'esignature_id': esigId,
        'comments': body['comments'],
      })
      .eq('entity_type', 'subject')
      .eq('entity_id', id)
      .eq('status', 'pending');

  // Audit
  await supabase.from('audit_trails').insert({
    'entity_type': 'subject',
    'entity_id': id,
    'action': 'approve',
    'employee_id': auth.employeeId,
    'new_values': {'esignature_id': esigId},
    'created_at': now,
  });

  return ApiResponse.ok(updated).toResponse();
}
