import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/access/departments
///
/// Lists all departments in the organization.
/// Query params: status, parent_id, is_active, search, page, per_page
Future<Response> departmentsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final query = req.url.queryParameters;

  var builder = supabase
      .from('departments')
      .select('''
        id, name, unique_code, short_name, description,
        hierarchy_level, hierarchy_path, cost_center_code,
        status, revision_no, is_active, email, phone, location,
        created_at, updated_at,
        parent:departments!departments_parent_department_id_fkey(
          id, name, unique_code
        ),
        head:employees!departments_head_employee_id_fkey(
          id, first_name, last_name, employee_number
        ),
        plant:plants(id, name, code)
      ''')
      .eq('organization_id', auth.orgId);

  // Filters
  if (query['status'] != null) {
    builder = builder.eq('status', query['status']!);
  }
  if (query['parent_id'] != null) {
    builder = builder.eq('parent_department_id', query['parent_id']!);
  }
  if (query['is_active'] != null) {
    builder = builder.eq('is_active', query['is_active'] == 'true');
  }
  if (query['plant_id'] != null) {
    builder = builder.eq('plant_id', query['plant_id']!);
  }
  if (query['search'] != null) {
    final search = '%${query['search']}%';
    builder = builder.or('name.ilike.$search,unique_code.ilike.$search');
  }

  // Pagination
  final page = int.tryParse(query['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(query['per_page'] ?? '50') ?? 50;
  final from = (page - 1) * perPage;

  final result = await builder
      .order('hierarchy_level')
      .order('name')
      .range(from, from + perPage - 1);

  return ApiResponse.ok({
    'departments': result,
    'page': page,
    'per_page': perPage,
  }).toResponse();
}

/// POST /v1/access/departments
///
/// Creates a new department.
/// Body: { name, unique_code, short_name?, description?, parent_department_id?, plant_id?, head_employee_id?, ... }
Future<Response> departmentCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to create departments');
  }

  final name = requireString(body, 'name');
  final uniqueCode = requireString(body, 'unique_code');
  final shortName = body['short_name'] as String?;
  final description = body['description'] as String?;
  final parentDepartmentId = body['parent_department_id'] as String?;
  final plantId = body['plant_id'] as String?;
  final headEmployeeId = body['head_employee_id'] as String?;
  final email = body['email'] as String?;
  final phone = body['phone'] as String?;
  final location = body['location'] as String?;
  final costCenterCode = body['cost_center_code'] as String?;

  // Check unique code doesn't exist
  final existing = await supabase
      .from('departments')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('unique_code', uniqueCode)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('Department with code $uniqueCode already exists');
  }

  // Calculate hierarchy if parent exists
  int hierarchyLevel = 1;
  List<String> hierarchyPath = [];

  if (parentDepartmentId != null) {
    final parent = await supabase
        .from('departments')
        .select('id, hierarchy_level, hierarchy_path')
        .eq('id', parentDepartmentId)
        .maybeSingle();

    if (parent == null) {
      throw NotFoundException('Parent department not found');
    }

    hierarchyLevel = (parent['hierarchy_level'] as int) + 1;
    hierarchyPath = [...(parent['hierarchy_path'] as List? ?? []).cast<String>(), parentDepartmentId];
  }

  final result = await supabase
      .from('departments')
      .insert({
        'organization_id': auth.orgId,
        'plant_id': plantId,
        'name': name,
        'unique_code': uniqueCode,
        'short_name': shortName,
        'description': description,
        'parent_department_id': parentDepartmentId,
        'hierarchy_level': hierarchyLevel,
        'hierarchy_path': hierarchyPath,
        'head_employee_id': headEmployeeId,
        'email': email,
        'phone': phone,
        'location': location,
        'cost_center_code': costCenterCode,
        'status': 'initiated',
        'is_active': true,
        'created_by': auth.employeeId,
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'department',
    aggregateId: result['id'] as String,
    eventType: 'department.created',
    payload: {'name': name, 'unique_code': uniqueCode},
  );

  return ApiResponse.created({
    'department': result,
    'message': 'Department created successfully',
  }).toResponse();
}

/// GET /v1/access/departments/:id
///
/// Gets a single department by ID.
Future<Response> departmentGetHandler(Request req) async {
  final departmentId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (departmentId == null || departmentId.isEmpty) {
    throw ValidationException({'id': 'Department ID is required'});
  }

  final result = await supabase
      .from('departments')
      .select('''
        id, name, unique_code, short_name, description,
        hierarchy_level, hierarchy_path, cost_center_code,
        status, revision_no, is_active, email, phone, location,
        created_at, updated_at,
        parent:departments!departments_parent_department_id_fkey(
          id, name, unique_code
        ),
        head:employees!departments_head_employee_id_fkey(
          id, first_name, last_name, employee_number
        ),
        plant:plants(id, name, code),
        children:departments!departments_parent_department_id_fkey(
          id, name, unique_code, is_active
        )
      ''')
      .eq('id', departmentId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    throw NotFoundException('Department not found');
  }

  return ApiResponse.ok({'department': result}).toResponse();
}

/// PATCH /v1/access/departments/:id
///
/// Updates a department.
Future<Response> departmentUpdateHandler(Request req) async {
  final departmentId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to update departments');
  }

  if (departmentId == null || departmentId.isEmpty) {
    throw ValidationException({'id': 'Department ID is required'});
  }

  // Verify exists
  final existing = await supabase
      .from('departments')
      .select('id, status')
      .eq('id', departmentId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Department not found');
  }

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  if (body['name'] != null) updates['name'] = body['name'];
  if (body['short_name'] != null) updates['short_name'] = body['short_name'];
  if (body['description'] != null) updates['description'] = body['description'];
  if (body['head_employee_id'] != null) updates['head_employee_id'] = body['head_employee_id'];
  if (body['email'] != null) updates['email'] = body['email'];
  if (body['phone'] != null) updates['phone'] = body['phone'];
  if (body['location'] != null) updates['location'] = body['location'];
  if (body['cost_center_code'] != null) updates['cost_center_code'] = body['cost_center_code'];
  if (body['is_active'] != null) updates['is_active'] = body['is_active'];

  final result = await supabase
      .from('departments')
      .update(updates)
      .eq('id', departmentId)
      .select()
      .single();

  return ApiResponse.ok({
    'department': result,
    'message': 'Department updated successfully',
  }).toResponse();
}

/// DELETE /v1/access/departments/:id
///
/// Deactivates a department (soft delete).
Future<Response> departmentDeleteHandler(Request req) async {
  final departmentId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to delete departments');
  }

  if (departmentId == null || departmentId.isEmpty) {
    throw ValidationException({'id': 'Department ID is required'});
  }

  // Check for child departments
  final children = await supabase
      .from('departments')
      .select('id')
      .eq('parent_department_id', departmentId)
      .eq('is_active', true)
      .limit(1);

  if ((children as List).isNotEmpty) {
    throw ConflictException('Cannot delete department with active child departments');
  }

  // Check for employees
  final employees = await supabase
      .from('employees')
      .select('id')
      .eq('department_id', departmentId)
      .eq('is_active', true)
      .limit(1);

  if ((employees as List).isNotEmpty) {
    throw ConflictException('Cannot delete department with active employees');
  }

  await supabase
      .from('departments')
      .update({
        'is_active': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', departmentId)
      .eq('organization_id', auth.orgId);

  return ApiResponse.ok({
    'message': 'Department deactivated successfully',
  }).toResponse();
}

/// POST /v1/access/departments/:id/submit
///
/// Submits department for approval.
Future<Response> departmentSubmitHandler(Request req) async {
  final departmentId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to submit departments');
  }

  if (departmentId == null || departmentId.isEmpty) {
    throw ValidationException({'id': 'Department ID is required'});
  }

  final existing = await supabase
      .from('departments')
      .select('id, status')
      .eq('id', departmentId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Department not found');
  }

  if (existing['status'] != 'initiated' && existing['status'] != 'rejected') {
    throw ConflictException('Department cannot be submitted from current status');
  }

  final result = await supabase
      .from('departments')
      .update({
        'status': 'pending_approval',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', departmentId)
      .select()
      .single();

  return ApiResponse.ok({
    'department': result,
    'message': 'Department submitted for approval',
  }).toResponse();
}

/// POST /v1/access/departments/:id/approve
///
/// Approves a department (requires e-signature).
Future<Response> departmentApproveHandler(Request req) async {
  final departmentId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to approve departments');
  }

  if (departmentId == null || departmentId.isEmpty) {
    throw ValidationException({'id': 'Department ID is required'});
  }

  final existing = await supabase
      .from('departments')
      .select('id, status, name')
      .eq('id', departmentId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Department not found');
  }

  if (existing['status'] != 'pending_approval') {
    throw ConflictException('Department is not pending approval');
  }

  // Create e-signature
  final esig = body['esig'] as Map<String, dynamic>?;
  String? esigId;
  if (esig != null) {
    final esigService = EsigService(supabase);
    esigId = await esigService.createEsignature(
      employeeId: auth.employeeId,
      meaning: esig['meaning'] as String? ?? 'APPROVE_DEPARTMENT',
      entityType: 'department',
      entityId: departmentId,
      reauthSessionId: esig['reauth_session_id'] as String?,
    );
  }

  final result = await supabase
      .from('departments')
      .update({
        'status': 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', departmentId)
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'department',
    aggregateId: departmentId,
    eventType: 'department.approved',
    payload: {'esignature_id': esigId},
  );

  return ApiResponse.ok({
    'department': result,
    'message': 'Department approved successfully',
    'esignature_id': esigId,
  }).toResponse();
}

/// GET /v1/access/departments/:id/employees
///
/// Lists employees in a department.
Future<Response> departmentEmployeesHandler(Request req) async {
  final departmentId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final query = req.url.queryParameters;

  if (departmentId == null || departmentId.isEmpty) {
    throw ValidationException({'id': 'Department ID is required'});
  }

  var builder = supabase
      .from('employees')
      .select('''
        id, employee_number, first_name, last_name, email,
        designation, is_active, induction_completed
      ''')
      .eq('department_id', departmentId)
      .eq('organization_id', auth.orgId);

  if (query['is_active'] != null) {
    builder = builder.eq('is_active', query['is_active'] == 'true');
  }

  final result = await builder.order('first_name').order('last_name');

  return ApiResponse.ok({
    'department_id': departmentId,
    'employees': result,
    'count': (result as List).length,
  }).toResponse();
}

/// GET /v1/access/departments/hierarchy
///
/// Returns department hierarchy tree.
Future<Response> departmentHierarchyHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final result = await supabase
      .from('departments')
      .select('''
        id, name, unique_code, parent_department_id,
        hierarchy_level, is_active
      ''')
      .eq('organization_id', auth.orgId)
      .eq('is_active', true)
      .order('hierarchy_level')
      .order('name');

  // Build tree structure
  final departments = result as List;
  final tree = _buildDepartmentTree(departments);

  return ApiResponse.ok({
    'hierarchy': tree,
    'total_departments': departments.length,
  }).toResponse();
}

List<Map<String, dynamic>> _buildDepartmentTree(List<dynamic> departments) {
  final Map<String, Map<String, dynamic>> nodeMap = {};
  final List<Map<String, dynamic>> roots = [];

  // Create nodes
  for (final dept in departments) {
    final node = Map<String, dynamic>.from(dept as Map);
    node['children'] = <Map<String, dynamic>>[];
    nodeMap[dept['id'] as String] = node;
  }

  // Build tree
  for (final dept in departments) {
    final parentId = dept['parent_department_id'] as String?;
    final node = nodeMap[dept['id'] as String]!;

    if (parentId == null || !nodeMap.containsKey(parentId)) {
      roots.add(node);
    } else {
      (nodeMap[parentId]!['children'] as List).add(node);
    }
  }

  return roots;
}
