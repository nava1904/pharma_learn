import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/register
///
/// Admin-only endpoint to register a new user account for an existing employee.
/// The employee record must exist first (created via POST /v1/access/employees).
///
/// Body:
/// ```json
/// {
///   "employee_id": "uuid",
///   "email": "user@org.com",
///   "password": "initial_password",
///   "send_welcome_email": true
/// }
/// ```
Future<Response> registerHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Permission check - only admins can register users
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageEmployees,
    jwtPermissions: auth.permissions,
  );

  final employeeId = body['employee_id'] as String?;
  final email = body['email'] as String?;
  final password = body['password'] as String?;
  final sendWelcomeEmail = body['send_welcome_email'] as bool? ?? true;

  final errors = <String, dynamic>{};
  if (employeeId == null || employeeId.isEmpty) errors['employee_id'] = 'Required';
  if (email == null || email.isEmpty) errors['email'] = 'Required';
  if (password == null || password.isEmpty) errors['password'] = 'Required';
  if (errors.isNotEmpty) throw ValidationException(errors);

  // Validate email format
  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  if (!emailRegex.hasMatch(email!)) {
    throw ValidationException({'email': 'Invalid email format'});
  }

  // Verify employee exists and doesn't already have a user account
  final employee = await supabase
      .from('employees')
      .select('id, user_id, org_id, first_name, last_name')
      .eq('id', employeeId!)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  if (employee['user_id'] != null) {
    throw ConflictException('Employee already has a user account');
  }

  // Check password policy
  final passwordPolicy = await supabase
      .from('password_policies')
      .select('*')
      .eq('org_id', auth.orgId)
      .eq('is_active', true)
      .maybeSingle();

  if (passwordPolicy != null) {
    final minLength = passwordPolicy['min_length'] as int? ?? 8;
    final requireUppercase = passwordPolicy['require_uppercase'] as bool? ?? true;
    final requireLowercase = passwordPolicy['require_lowercase'] as bool? ?? true;
    final requireNumbers = passwordPolicy['require_numbers'] as bool? ?? true;
    final requireSpecial = passwordPolicy['require_special'] as bool? ?? true;

    if (password!.length < minLength) {
      throw ValidationException({'password': 'Must be at least $minLength characters'});
    }
    if (requireUppercase && !password.contains(RegExp(r'[A-Z]'))) {
      throw ValidationException({'password': 'Must contain uppercase letter'});
    }
    if (requireLowercase && !password.contains(RegExp(r'[a-z]'))) {
      throw ValidationException({'password': 'Must contain lowercase letter'});
    }
    if (requireNumbers && !password.contains(RegExp(r'[0-9]'))) {
      throw ValidationException({'password': 'Must contain number'});
    }
    if (requireSpecial && !password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      throw ValidationException({'password': 'Must contain special character'});
    }
  }

  // Create user in GoTrue via admin API
  // Note: In production, this would call supabase.auth.admin.createUser
  // For now, we use signUp with auto-confirm
  final authResponse = await supabase.auth.signUp(
    email: email,
    password: password!,
    data: {
      'employee_id': employeeId,
      'org_id': auth.orgId,
    },
  );

  final userId = authResponse.user?.id;
  if (userId == null) {
    throw ConflictException('Failed to create user account');
  }

  // Link user to employee
  await supabase.from('employees').update({
    'user_id': userId,
    'email': email,
  }).eq('id', employeeId);

  // Create user_credentials record
  await supabase.from('user_credentials').insert({
    'employee_id': employeeId,
    'password_hash': 'managed_by_goture', // Actual hash is in GoTrue
    'must_change_password': true,
    'password_expires_at': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
  });

  // Send welcome email if requested
  if (sendWelcomeEmail) {
    try {
      await supabase.functions.invoke('send-notification', body: {
        'template': 'welcome_email',
        'recipient_id': employeeId,
        'data': {
          'email': email,
          'name': '${employee['first_name']} ${employee['last_name']}',
        },
      });
    } catch (_) {
      // Don't fail registration if email fails
    }
  }

  return ApiResponse.created({
    'employee_id': employeeId,
    'user_id': userId,
    'email': email,
    'must_change_password': true,
  }).toResponse();
}
