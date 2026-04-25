import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show UserAttributes;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/password/change
///
/// Allows an authenticated employee to change their own password.
/// The current password is validated via the `validate_credential` RPC before
/// updating via GoTrue.
///
/// Body: `{"current_password": "…", "new_password": "…"}`
Future<Response> passwordChangeHandler(Request req) async {
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final currentPassword = body['current_password'] as String?;
  final newPassword = body['new_password'] as String?;

  final errors = <String, dynamic>{};
  if (currentPassword == null || currentPassword.isEmpty) {
    errors['current_password'] = 'Required';
  }
  if (newPassword == null || newPassword.isEmpty) {
    errors['new_password'] = 'Required';
  } else if (newPassword.length < 8) {
    errors['new_password'] = 'Must be at least 8 characters';
  }
  if (errors.isNotEmpty) throw ValidationException(errors);

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // 1. Validate current credential (also checks lockout)
  final valid = await supabase.rpc(
    'validate_credential',
    params: {
      'p_employee_id': auth.employeeId,
      'p_input_hash': currentPassword,
      'p_policy_threshold': 5,
    },
  ) as bool? ?? false;

  if (!valid) {
    return ErrorResponse.unauthorized('Current password is incorrect')
        .toResponse();
  }

  // 2. Update via GoTrue (UserAttributes is exported by supabase package)
  try {
    await supabase.auth.updateUser(UserAttributes(password: newPassword));
  } catch (e) {
    throw AuthException('Failed to update password: $e');
  }

  // 3. Publish event
  try {
    await OutboxService(supabase).publish(
      aggregateType: 'auth',
      aggregateId: auth.employeeId,
      eventType: 'auth.password_changed',
      payload: {'employee_id': auth.employeeId},
      orgId: auth.orgId,
    );
  } catch (_) {}

  return ApiResponse.ok({'message': 'Password updated successfully'})
      .toResponse();
}
