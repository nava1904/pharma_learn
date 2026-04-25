import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/employees/:id
Future<Response> employeeGetHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Employees can view their own record; managers need viewEmployees permission
  if (id != auth.employeeId) {
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.viewEmployees,
      jwtPermissions: auth.permissions,
    );
  }

  final employee = await supabase
      .from('employees')
      .select(
        'id, user_id, employee_number, full_name, email, phone, '
        'organization_id, plant_id, department_id, job_title, '
        'employment_status, induction_completed, compliance_percent, '
        'created_at, updated_at, '
        'user_credentials ( mfa_enabled ), '
        'employee_roles ( roles ( id, name, description ) )',
      )
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (employee == null) throw NotFoundException('Employee not found');

  return ApiResponse.ok({'employee': employee}).toResponse();
}

/// PATCH /v1/employees/:id
Future<Response> employeePatchHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageEmployees,
    jwtPermissions: auth.permissions,
  );

  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  const updatableFields = {
    'full_name', 'job_title', 'department_id', 'plant_id',
    'phone', 'employment_status',
  };
  final updates = Map<String, dynamic>.fromEntries(
    body.entries.where((e) => updatableFields.contains(e.key)),
  );

  if (updates.isEmpty) {
    throw ValidationException({'body': 'No updatable fields provided'});
  }

  updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

  final updated = await supabase
      .from('employees')
      .update(updates)
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .select()
      .maybeSingle();

  if (updated == null) throw NotFoundException('Employee not found');

  await OutboxService(supabase).publish(
    aggregateType: 'employee',
    aggregateId: id,
    eventType: EventTypes.employeeUpdated,
    payload: {'updated_by': auth.employeeId, 'fields': updates.keys.toList()},
    orgId: auth.orgId,
  );

  return ApiResponse.ok({'employee': updated}).toResponse();
}
