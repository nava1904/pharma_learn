import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/auth/profile
///
/// Returns the current employee's profile, including MFA status and roles.
///
/// Response 200: `{data: {employee: {...}, mfa_enabled: bool, roles: [],
///                        permissions: [...]}}`
Future<Response> profileHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final employee = await supabase
      .from('employees')
      .select(
        'id, user_id, employee_number, full_name, email, phone, '
        'organization_id, plant_id, department_id, job_title, '
        'employment_status, induction_completed, compliance_percent, '
        'created_at, updated_at, '
        'user_credentials ( mfa_enabled )',
      )
      .eq('id', auth.employeeId)
      .single();

  final roles = await supabase
      .from('employee_roles')
      .select('roles ( id, name, description )')
      .eq('employee_id', auth.employeeId);

  final creds = employee['user_credentials'];
  final mfaEnabled = creds is Map ? (creds['mfa_enabled'] as bool? ?? false) : false;

  return ApiResponse.ok({
    'employee': employee,
    'mfa_enabled': mfaEnabled,
    'roles': (roles as List).map((r) => r['roles']).toList(),
    'permissions': auth.permissions,
  }).toResponse();
}
