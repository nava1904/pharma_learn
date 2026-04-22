import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/coordinators
/// 
/// List training coordinators with pagination and filtering.
Future<Response> coordinatorsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check - admin or training manager
  if (!auth.hasPermission('training.coordinators.view') &&
      !auth.hasPermission('training.manage')) {
    throw PermissionDeniedException('Training coordinator view access required');
  }

  // Parse pagination
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;

  // Parse filters
  final departmentId = req.url.queryParameters['department_id'];
  final plantId = req.url.queryParameters['plant_id'];
  final status = req.url.queryParameters['status'];

  // Get total count first
  var countQuery = supabase
      .from('training_coordinators')
      .select('id')
      .eq('organization_id', auth.orgId);

  if (departmentId != null) countQuery = countQuery.eq('department_id', departmentId);
  if (plantId != null) countQuery = countQuery.eq('plant_id', plantId);
  if (status != null) {
    countQuery = countQuery.eq('status', status);
  } else {
    countQuery = countQuery.eq('status', 'active');
  }

  final countResult = await countQuery;
  final total = countResult.length;

  // Build query for data
  var query = supabase
      .from('training_coordinators')
      .select('''
        id,
        employee_id,
        department_id,
        plant_id,
        scope,
        status,
        appointed_at,
        deactivated_at,
        created_at,
        employees!inner(
          id,
          employee_number,
          first_name,
          last_name,
          email
        ),
        departments(
          id,
          name
        ),
        plants(
          id,
          name
        )
      ''')
      .eq('organization_id', auth.orgId);

  // Apply filters
  if (departmentId != null) {
    query = query.eq('department_id', departmentId);
  }
  if (plantId != null) {
    query = query.eq('plant_id', plantId);
  }
  if (status != null) {
    query = query.eq('status', status);
  } else {
    query = query.eq('status', 'active');
  }

  // Apply pagination
  final offset = (page - 1) * perPage;
  final data = await query
      .order('created_at', ascending: false)
      .range(offset, offset + perPage - 1);

  return ApiResponse.paginated(
    data,
    Pagination.compute(page: page, perPage: perPage, total: total),
  ).toResponse();
}

/// POST /v1/train/coordinators
/// 
/// Appoint a new training coordinator.
Future<Response> coordinatorsCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Permission check
  if (!auth.hasPermission('training.coordinators.manage') &&
      !auth.hasPermission('training.manage')) {
    throw PermissionDeniedException('Training coordinator management access required');
  }

  // Validate required fields
  final employeeId = body['employee_id'] as String?;
  final scope = body['scope'] as String?;

  if (employeeId == null || employeeId.isEmpty) {
    throw ValidationException({'employee_id': 'Employee ID is required'});
  }
  if (scope == null || !['organization', 'plant', 'department'].contains(scope)) {
    throw ValidationException({
      'scope': 'Scope must be one of: organization, plant, department'
    });
  }

  // Validate scope-specific fields
  String? departmentId;
  String? plantId;

  if (scope == 'department') {
    departmentId = body['department_id'] as String?;
    if (departmentId == null) {
      throw ValidationException({
        'department_id': 'Department ID is required for department scope'
      });
    }
  } else if (scope == 'plant') {
    plantId = body['plant_id'] as String?;
    if (plantId == null) {
      throw ValidationException({
        'plant_id': 'Plant ID is required for plant scope'
      });
    }
  }

  // Check if employee exists and is in same org
  final employee = await supabase
      .from('employees')
      .select('id, organization_id')
      .eq('id', employeeId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }
  if (employee['organization_id'] != auth.orgId) {
    throw PermissionDeniedException('Employee not in your organization');
  }

  // Check for existing active coordinator role
  var existingQuery = supabase
      .from('training_coordinators')
      .select('id')
      .eq('employee_id', employeeId)
      .eq('status', 'active');

  if (scope == 'department') {
    existingQuery = existingQuery.eq('department_id', departmentId!);
  } else if (scope == 'plant') {
    existingQuery = existingQuery.eq('plant_id', plantId!);
  } else {
    existingQuery = existingQuery.eq('scope', 'organization');
  }

  final existing = await existingQuery.maybeSingle();
  if (existing != null) {
    throw ConflictException('Employee is already an active coordinator for this scope');
  }

  // Create coordinator
  final coordinator = await supabase.from('training_coordinators').insert({
    'employee_id': employeeId,
    'organization_id': auth.orgId,
    'department_id': departmentId,
    'plant_id': plantId,
    'scope': scope,
    'status': 'active',
    'appointed_at': DateTime.now().toUtc().toIso8601String(),
    'appointed_by': auth.employeeId,
  }).select().single();

  return ApiResponse.created(coordinator).toResponse();
}

/// GET /v1/train/coordinators/:id
/// 
/// Get a specific training coordinator.
Future<Response> coordinatorDetailHandler(Request req) async {
  final coordinatorId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check
  if (!auth.hasPermission('training.coordinators.view') &&
      !auth.hasPermission('training.manage')) {
    throw PermissionDeniedException('Training coordinator view access required');
  }

  final coordinator = await supabase
      .from('training_coordinators')
      .select('''
        id,
        employee_id,
        department_id,
        plant_id,
        scope,
        status,
        appointed_at,
        appointed_by,
        deactivated_at,
        deactivated_by,
        created_at,
        employees!inner(
          id,
          employee_number,
          first_name,
          last_name,
          email,
          job_title
        ),
        departments(
          id,
          name
        ),
        plants(
          id,
          name
        ),
        appointed:employees!training_coordinators_appointed_by_fkey(
          id,
          first_name,
          last_name
        ),
        deactivated:employees!training_coordinators_deactivated_by_fkey(
          id,
          first_name,
          last_name
        )
      ''')
      .eq('id', coordinatorId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (coordinator == null) {
    throw NotFoundException('Training coordinator not found');
  }

  return ApiResponse.ok(coordinator).toResponse();
}

/// PATCH /v1/train/coordinators/:id
/// 
/// Update a training coordinator (scope changes).
Future<Response> coordinatorUpdateHandler(Request req) async {
  final coordinatorId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Permission check
  if (!auth.hasPermission('training.coordinators.manage') &&
      !auth.hasPermission('training.manage')) {
    throw PermissionDeniedException('Training coordinator management access required');
  }

  // Get existing coordinator
  final existing = await supabase
      .from('training_coordinators')
      .select('id, status')
      .eq('id', coordinatorId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Training coordinator not found');
  }

  if (existing['status'] != 'active') {
    throw ConflictException('Cannot update deactivated coordinator');
  }

  // Build update
  final updates = <String, dynamic>{};

  if (body.containsKey('scope')) {
    final scope = body['scope'] as String;
    if (!['organization', 'plant', 'department'].contains(scope)) {
      throw ValidationException({
        'scope': 'Scope must be one of: organization, plant, department'
      });
    }
    updates['scope'] = scope;

    // Update scope-specific fields
    if (scope == 'department') {
      final departmentId = body['department_id'] as String?;
      if (departmentId == null) {
        throw ValidationException({
          'department_id': 'Department ID required for department scope'
        });
      }
      updates['department_id'] = departmentId;
      updates['plant_id'] = null;
    } else if (scope == 'plant') {
      final plantId = body['plant_id'] as String?;
      if (plantId == null) {
        throw ValidationException({
          'plant_id': 'Plant ID required for plant scope'
        });
      }
      updates['plant_id'] = plantId;
      updates['department_id'] = null;
    } else {
      updates['department_id'] = null;
      updates['plant_id'] = null;
    }
  }

  if (updates.isEmpty) {
    throw ValidationException({'_': 'No valid updates provided'});
  }

  updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

  final updated = await supabase
      .from('training_coordinators')
      .update(updates)
      .eq('id', coordinatorId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/train/coordinators/:id/deactivate
/// 
/// Deactivate a training coordinator.
Future<Response> coordinatorDeactivateHandler(Request req) async {
  final coordinatorId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Permission check
  if (!auth.hasPermission('training.coordinators.manage') &&
      !auth.hasPermission('training.manage')) {
    throw PermissionDeniedException('Training coordinator management access required');
  }

  // Get existing coordinator
  final existing = await supabase
      .from('training_coordinators')
      .select('id, status')
      .eq('id', coordinatorId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Training coordinator not found');
  }

  if (existing['status'] != 'active') {
    throw ConflictException('Coordinator is already deactivated');
  }

  // Deactivate
  final reason = body['reason'] as String? ?? 'No reason provided';

  final updated = await supabase.from('training_coordinators').update({
    'status': 'inactive',
    'deactivated_at': DateTime.now().toUtc().toIso8601String(),
    'deactivated_by': auth.employeeId,
    'deactivation_reason': reason,
  }).eq('id', coordinatorId).select().single();

  return ApiResponse.ok(updated).toResponse();
}
