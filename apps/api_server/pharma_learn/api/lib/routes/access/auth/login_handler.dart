import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/login
///
/// Authenticates via GoTrue and creates a `user_sessions` row keyed by the
/// JWT `jti` claim.
///
/// Request body:
/// ```json
/// { "email": "user@example.com", "password": "secret",
///   "device_info": {"device_id": "…", "device_type": "ios|android|web",
///                   "ip_address": "…", "user_agent": "…"} }
/// ```
///
/// Responses:
/// - 200 `{data: {access_token, refresh_token, expires_at, user, session}}`
/// - 401 Invalid credentials
/// - 423 Account locked
Future<Response> loginHandler(Request req) async {
  // 1. Parse body
  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'})
        .toResponse();
  }

  final Map<String, dynamic> body;
  try {
    body = jsonDecode(bodyStr) as Map<String, dynamic>;
  } catch (_) {
    return ErrorResponse.validation({'body': 'Invalid JSON'}).toResponse();
  }

  final email = body['email'] as String?;
  final password = body['password'] as String?;
  final deviceInfo = body['device_info'] as Map<String, dynamic>?;

  // 2. Field validation
  final errors = <String, dynamic>{};
  if (email == null || email.isEmpty) errors['email'] = 'Email is required';
  if (password == null || password.isEmpty) {
    errors['password'] = 'Password is required';
  }
  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  final supabase = RequestContext.supabase;

  // 3. Lockout check (DB-side RPC)
  try {
    final lockCheck = await supabase
        .rpc('check_account_lock', params: {'p_email': email}) as Map?;
    if (lockCheck != null && lockCheck['is_locked'] == true) {
      final until = lockCheck['locked_until'] as String?;
      return ErrorResponse.accountLocked(
        'Account is locked until ${until ?? 'further notice'}.',
      ).toResponse();
    }
  } catch (_) {
    // Proceed if the RPC doesn't exist yet — DB migration may be pending
  }

  // 4. Authenticate with GoTrue
  try {
    final authResponse = await supabase.auth.signInWithPassword(
      email: email!,
      password: password!,
    );

    if (authResponse.user == null || authResponse.session == null) {
      await _recordFailedAttempt(supabase, email);
      return ErrorResponse.unauthorized('Invalid email or password')
          .toResponse();
    }

    final goUser = authResponse.user!;
    final goSession = authResponse.session!;

    // 5. Decode JWT to get jti (session ID)
    final claims = JwtService.decode(goSession.accessToken);
    final jti = claims['jti'] as String?;

    // 6. Load employee record
    final employeeRow = await supabase
        .from('employees')
        .select(
          'id, organization_id, plant_id, induction_completed, full_name',
        )
        .eq('user_id', goUser.id)
        .maybeSingle();

    if (employeeRow == null) {
      return ErrorResponse.unauthorized(
        'No employee record found for this user.',
      ).toResponse();
    }

    // 7. Upsert user_sessions row
    final now = DateTime.now().toUtc().toIso8601String();
    final expiresAt = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 8))
        .toIso8601String();

    if (jti != null) {
      await supabase.from('user_sessions').upsert({
        'id': jti,
        'user_id': goUser.id,
        'employee_id': employeeRow['id'],
        'device_id': deviceInfo?['device_id'],
        'device_type': deviceInfo?['device_type'],
        'ip_address': deviceInfo?['ip_address'],
        'user_agent': deviceInfo?['user_agent'],
        'expires_at': expiresAt,
        'last_activity_at': now,
      }, onConflict: 'id');
    }

    // 8. Clear failed-attempt counter
    try {
      await supabase
          .rpc('clear_failed_attempts', params: {'p_email': email});
    } catch (_) {}

    // 9. Publish login event
    try {
      final outbox = OutboxService(supabase);
      await outbox.publish(
        aggregateType: 'auth',
        aggregateId: employeeRow['id'] as String,
        eventType: EventTypes.authLogin,
        payload: {
          'ip': deviceInfo?['ip_address'] ?? 'unknown',
          'device_type': deviceInfo?['device_type'],
        },
        orgId: employeeRow['organization_id'] as String?,
      );
    } catch (_) {}

    return ApiResponse.ok({
      'access_token': goSession.accessToken,
      'refresh_token': goSession.refreshToken,
      'expires_at': goSession.expiresAt,
      'token_type': 'Bearer',
      'user': {
        'id': goUser.id,
        'email': goUser.email,
        'employee_id': employeeRow['id'],
        'full_name': employeeRow['full_name'],
        'organization_id': employeeRow['organization_id'],
        'plant_id': employeeRow['plant_id'],
        'induction_completed': employeeRow['induction_completed'] ?? false,
      },
    }).toResponse();
  } catch (e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials') ||
        msg.contains('invalid_grant') ||
        msg.contains('Invalid email or password')) {
      await _recordFailedAttempt(supabase, email!);
      return ErrorResponse.unauthorized('Invalid email or password')
          .toResponse();
    }
    return ErrorResponse.internalError().toResponse();
  }
}

Future<void> _recordFailedAttempt(dynamic supabase, String email) async {
  try {
    await supabase
        .rpc('record_failed_login', params: {'p_email': email});
  } catch (_) {}
}
