import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// PATCH /v1/access/employees/:id/deactivate
///
/// Deactivates an employee account. Per Alfa §3.1.4, employees are disabled,
/// not deleted, to preserve audit trail integrity.
///
/// Body:
/// ```json
/// {
///   "reason": "Resignation",
///   "effective_date": "2026-04-30",
///   "transfer_approvals_to": "uuid"
/// }
/// ```
Future<Response> employeeDeactivateHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Permission check
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageEmployees,
    jwtPermissions: auth.permissions,
  );

  final reason = body['reason'] as String?;
  final effectiveDateStr = body['effective_date'] as String?;
  final transferApprovalsTo = body['transfer_approvals_to'] as String?;

  if (reason == null || reason.trim().isEmpty) {
    throw ValidationException({'reason': 'Deactivation reason is required'});
  }

  // Verify employee exists and is in same org
  final employee = await supabase
      .from('employees')
      .select('id, status, user_id, first_name, last_name')
      .eq('id', employeeId)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  if (employee['status'] == 'inactive') {
    throw ConflictException('Employee is already deactivated');
  }

  // Cannot deactivate yourself
  if (employeeId == auth.employeeId) {
    throw ValidationException({'id': 'Cannot deactivate your own account'});
  }

  final effectiveDate = effectiveDateStr != null
      ? DateTime.tryParse(effectiveDateStr)
      : DateTime.now();

  // Transfer pending approvals if specified
  if (transferApprovalsTo != null) {
    // Verify transfer target exists and is active
    final target = await supabase
        .from('employees')
        .select('id, status')
        .eq('id', transferApprovalsTo)
        .eq('org_id', auth.orgId)
        .eq('status', 'active')
        .maybeSingle();

    if (target == null) {
      throw ValidationException({'transfer_approvals_to': 'Target employee not found or inactive'});
    }

    // Transfer pending approvals
    await supabase.from('approval_steps').update({
      'approver_id': transferApprovalsTo,
    }).eq('approver_id', employeeId).eq('status', 'pending');

    // Transfer active delegations
    await supabase.from('delegations').update({
      'is_active': false,
      'revoked_at': DateTime.now().toUtc().toIso8601String(),
      'revoked_reason': 'Delegator deactivated',
    }).eq('delegator_id', employeeId).eq('is_active', true);
  }

  // Revoke all active user sessions
  if (employee['user_id'] != null) {
    await supabase.from('user_sessions').update({
      'revoked_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', employee['user_id']).isFilter('revoked_at', null);
  }

  // Deactivate the employee
  final updated = await supabase.from('employees').update({
    'status': 'inactive',
    'deactivated_at': effectiveDate?.toIso8601String(),
    'deactivation_reason': reason.trim(),
    'deactivated_by': auth.employeeId,
  }).eq('id', employeeId).select().single();

  // Create audit trail entry
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee',
    'entity_id': employeeId,
    'action': 'DEACTIVATE',
    'event_category': 'EMPLOYEE_DEACTIVATION',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'new_values': {
      'status': 'inactive',
      'reason': reason,
      'effective_date': effectiveDate?.toIso8601String(),
      'approvals_transferred_to': transferApprovalsTo,
    },
  });

  return ApiResponse.ok({
    'employee': updated,
    'message': 'Employee deactivated successfully',
    'approvals_transferred': transferApprovalsTo != null,
  }).toResponse();
}
