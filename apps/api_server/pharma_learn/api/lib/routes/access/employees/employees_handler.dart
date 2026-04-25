import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption, AdminUserAttributes;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/employees
///
/// Lists employees for the caller's organisation.
/// Query params: `page`, `per_page`, `search`, `status`, `department_id`,
///               `plant_id`, `sort_by`, `sort_order`
Future<Response> employeesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewEmployees,
    jwtPermissions: auth.permissions,
  );

  final q = QueryParams.fromRequest(req);
  final qp = req.url.queryParameters;

  // Build filter chain
  var query = supabase
      .from('employees')
      .select('*, user_credentials ( mfa_enabled )')
      .eq('organization_id', auth.orgId);

  if (qp['status'] != null) {
    query = query.eq('employment_status', qp['status']!);
  }
  if (qp['department_id'] != null) {
    query = query.eq('department_id', qp['department_id']!);
  }
  if (qp['plant_id'] != null) {
    query = query.eq('plant_id', qp['plant_id']!);
  }
  if (q.search != null && q.search!.isNotEmpty) {
    query = query.or(
      'full_name.ilike.%${q.search}%,'
      'email.ilike.%${q.search}%,'
      'employee_number.ilike.%${q.search}%',
    );
  }

  // Apply order, pagination, and count in the final await
  final sortColumn = q.sortBy ?? 'full_name';
  final offset = (q.page - 1) * q.perPage;

  final response = await query
      .order(sortColumn, ascending: q.sortOrder == 'asc')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  final total = response.count;
  final pagination = Pagination(
    page: q.page,
    perPage: q.perPage,
    total: total,
    totalPages: total == 0 ? 1 : (total / q.perPage).ceil(),
  );

  return ApiResponse.paginated(response.data, pagination).toResponse();
}

/// POST /v1/employees
///
/// Creates a new employee. Requires `employees.manage` permission.
/// Body: `{email, full_name, employee_number, job_title, department_id,
///         plant_id, employment_status, password}`
Future<Response> employeesCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageEmployees,
    jwtPermissions: auth.permissions,
  );

  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  final errors = <String, dynamic>{};
  final email = body['email'] as String?;
  final fullName = body['full_name'] as String?;
  final employeeNumber = body['employee_number'] as String?;
  final password = body['password'] as String?;

  if (email == null || email.isEmpty) errors['email'] = 'Required';
  if (fullName == null || fullName.isEmpty) errors['full_name'] = 'Required';
  if (employeeNumber == null || employeeNumber.isEmpty) {
    errors['employee_number'] = 'Required';
  }
  if (password == null || password.length < 8) {
    errors['password'] = 'Required, minimum 8 characters';
  }
  if (errors.isNotEmpty) throw ValidationException(errors);

  // 1. Create GoTrue user (AdminUserAttributes is from gotrue, re-exported by supabase)
  final authResponse = await supabase.auth.admin.createUser(
    AdminUserAttributes(
      email: email,
      password: password,
      emailConfirm: true,
    ),
  );
  final goUser = authResponse.user;
  if (goUser == null) throw AuthException('Failed to create GoTrue user');

  // 2. Create employee row
  final employee = await supabase
      .from('employees')
      .insert({
        'user_id': goUser.id,
        'email': email,
        'full_name': fullName,
        'employee_number': employeeNumber,
        'job_title': body['job_title'],
        'department_id': body['department_id'],
        'plant_id': body['plant_id'] ?? auth.plantId,
        'organization_id': auth.orgId,
        'employment_status': body['employment_status'] ?? 'active',
        'induction_completed': false,
      })
      .select()
      .single();

  // 3. Create user_credentials row
  await supabase.from('user_credentials').insert({
    'employee_id': employee['id'],
    'mfa_enabled': false,
  });

  // 4. Publish event
  await OutboxService(supabase).publish(
    aggregateType: 'employee',
    aggregateId: employee['id'] as String,
    eventType: EventTypes.employeeCreated,
    payload: {'created_by': auth.employeeId, 'email': email},
    orgId: auth.orgId,
  );

  return ApiResponse.created({'employee': employee}).toResponse();
}
