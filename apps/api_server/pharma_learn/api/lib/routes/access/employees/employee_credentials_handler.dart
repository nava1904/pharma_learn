import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/access/employees/:id/credentials
/// Admin endpoint to reset employee credentials.
/// Requires: Permissions.manageEmployees
Future<Response> employeeCredentialsResetHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageEmployees,
    jwtPermissions: auth.permissions,
  );

  final forceChangeOnLogin = body['force_change_on_login'] as bool? ?? true;

  // Validate employee exists
  final employee = await supabase
      .from('employees')
      .select('id, email, organization_id')
      .eq('id', employeeId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  // Reset credentials
  await supabase.from('user_credentials').update({
    'force_password_change': forceChangeOnLogin,
    'failed_attempts': 0,
    'locked_at': null,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('employee_id', employeeId);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'user_credentials',
    'entity_id': employeeId,
    'action': 'CREDENTIALS_RESET',
    'event_category': 'SECURITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'target_employee_id': employeeId,
      'force_change_on_login': forceChangeOnLogin,
    }),
  });

  // Publish event
  await OutboxService(supabase).publish(
    aggregateType: 'employee',
    aggregateId: employeeId,
    eventType: 'credentials.reset',
    payload: {
      'reset_by': auth.employeeId,
      'force_change': forceChangeOnLogin,
    },
    orgId: auth.orgId,
  );

  return ApiResponse.ok({
    'message': 'Credentials reset successfully',
    'employee_id': employeeId,
    'force_change_on_login': forceChangeOnLogin,
  }).toResponse();
}

/// POST /v1/access/employees/:id/unlock
/// Unlocks an account that was locked due to failed login attempts.
/// Requires: Permissions.manageEmployees
Future<Response> employeeUnlockHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageEmployees,
    jwtPermissions: auth.permissions,
  );

  // Check if employee is actually locked
  final credentials = await supabase
      .from('user_credentials')
      .select('locked_at, failed_attempts')
      .eq('employee_id', employeeId)
      .maybeSingle();

  if (credentials == null) {
    throw NotFoundException('Employee credentials not found');
  }

  if (credentials['locked_at'] == null) {
    throw ValidationException({'account': 'Account is not locked'});
  }

  // Unlock the account
  await supabase.from('user_credentials').update({
    'locked_at': null,
    'failed_attempts': 0,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('employee_id', employeeId);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'user_credentials',
    'entity_id': employeeId,
    'action': 'ACCOUNT_UNLOCKED',
    'event_category': 'SECURITY',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'target_employee_id': employeeId,
      'previous_failed_attempts': credentials['failed_attempts'],
    }),
  });

  // Publish event
  await OutboxService(supabase).publish(
    aggregateType: 'employee',
    aggregateId: employeeId,
    eventType: 'account.unlocked',
    payload: {'unlocked_by': auth.employeeId},
    orgId: auth.orgId,
  );

  return ApiResponse.ok({
    'message': 'Account unlocked successfully',
    'employee_id': employeeId,
  }).toResponse();
}
