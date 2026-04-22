import 'dart:convert';
import 'dart:math';
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/password/reset-request (PUBLIC)
/// 
/// Initiates password reset by sending email with reset token.
/// Always returns success to avoid email enumeration.
Future<Response> passwordResetRequestHandler(Request req) async {
  final supabase = SupabaseService.client;
  final body = await readJson(req);
  final email = body['email'] as String?;

  if (email == null || email.isEmpty) {
    throw ValidationException({'email': 'Email is required'});
  }

  // Look up employee (but don't reveal if exists)
  final employee = await supabase
      .from('employees')
      .select('id, organization_id')
      .eq('email', email.toLowerCase())
      .maybeSingle();

  if (employee != null) {
    // Generate token
    final token = _generateSecureToken();
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 15));

    // Store token
    await supabase.from('password_reset_tokens').insert({
      'employee_id': employee['id'],
      'token': token,
      'expires_at': expiresAt.toIso8601String(),
    });

    // Send email via Edge Function
    try {
      await supabase.functions.invoke('send-notification', body: {
        'template_key': 'password_reset',
        'recipient_id': employee['id'],
        'data': {
          'reset_token': token,
          'expires_at': expiresAt.toIso8601String(),
          'reset_url': 'https://app.pharmalearn.com/reset-password?token=$token',
        },
      });
    } catch (e) {
      // Log but don't fail - security: don't reveal email delivery issues
    }

    // Audit trail
    await supabase.from('audit_trails').insert({
      'entity_type': 'employee',
      'entity_id': employee['id'],
      'action': 'PASSWORD_RESET_REQUESTED',
      'event_category': 'AUTH',
      'performed_by': employee['id'],
      'organization_id': employee['organization_id'],
    });
  }

  // Always return success (security - don't reveal if email exists)
  return ApiResponse.ok({
    'message': 'If the email exists, a reset link has been sent',
  }).toResponse();
}

/// POST /v1/auth/password/reset (PUBLIC)
/// 
/// Completes password reset using the token from email.
Future<Response> passwordResetHandler(Request req) async {
  final supabase = SupabaseService.client;
  final body = await readJson(req);
  
  final token = body['token'] as String?;
  final newPassword = body['new_password'] as String?;

  if (token == null || token.isEmpty) {
    throw ValidationException({'token': 'Token is required'});
  }
  if (newPassword == null || newPassword.isEmpty) {
    throw ValidationException({'new_password': 'New password is required'});
  }

  // Validate token
  final resetToken = await supabase
      .from('password_reset_tokens')
      .select('id, employee_id, expires_at')
      .eq('token', token)
      .isFilter('used_at', null)
      .maybeSingle();

  if (resetToken == null) {
    throw ValidationException({'token': 'Invalid or expired token'});
  }

  final expiresAt = DateTime.parse(resetToken['expires_at']);
  if (DateTime.now().toUtc().isAfter(expiresAt)) {
    throw ValidationException({'token': 'Token has expired'});
  }

  // Get password policy and validate
  final policy = await supabase
      .from('password_policies')
      .select()
      .eq('is_active', true)
      .maybeSingle();

  if (policy != null) {
    final minLength = policy['min_length'] as int? ?? 8;
    if (newPassword.length < minLength) {
      throw ValidationException({
        'new_password': 'Password must be at least $minLength characters'
      });
    }
    
    // Check complexity requirements
    if (policy['require_uppercase'] == true && !newPassword.contains(RegExp(r'[A-Z]'))) {
      throw ValidationException({
        'new_password': 'Password must contain at least one uppercase letter'
      });
    }
    if (policy['require_lowercase'] == true && !newPassword.contains(RegExp(r'[a-z]'))) {
      throw ValidationException({
        'new_password': 'Password must contain at least one lowercase letter'
      });
    }
    if (policy['require_number'] == true && !newPassword.contains(RegExp(r'[0-9]'))) {
      throw ValidationException({
        'new_password': 'Password must contain at least one number'
      });
    }
    if (policy['require_special'] == true && !newPassword.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      throw ValidationException({
        'new_password': 'Password must contain at least one special character'
      });
    }
  }

  // Get employee's auth user_id
  final employee = await supabase
      .from('employees')
      .select('user_id, organization_id')
      .eq('id', resetToken['employee_id'])
      .single();

  // Update password via GoTrue admin API
  // Note: In production, use service role key for admin operations
  await supabase.rpc('update_user_password', params: {
    'p_user_id': employee['user_id'],
    'p_new_password': newPassword,
  });

  // Mark token as used
  await supabase.from('password_reset_tokens').update({
    'used_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', resetToken['id']);

  // Update credential record
  await supabase.from('user_credentials').update({
    'password_changed_at': DateTime.now().toUtc().toIso8601String(),
    'failed_attempts': 0,
    'locked_at': null,
  }).eq('employee_id', resetToken['employee_id']);

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee',
    'entity_id': resetToken['employee_id'],
    'action': 'PASSWORD_RESET',
    'event_category': 'AUTH',
    'performed_by': resetToken['employee_id'],
    'organization_id': employee['organization_id'],
  });

  return ApiResponse.ok({'message': 'Password reset successfully'}).toResponse();
}

String _generateSecureToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}
