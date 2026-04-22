import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /jobs/cert-expiry
///
/// Scans for expiring certificates and sends notifications.
/// Runs hourly.
Future<Response> certExpiryHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final startTime = DateTime.now();
  final now = DateTime.now().toUtc();

  // Find certificates expiring in next 30, 14, 7, 1 days
  final thresholds = [30, 14, 7, 1];
  var totalNotified = 0;

  for (final days in thresholds) {
    final expiryDate = now.add(Duration(days: days));
    final startOfDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final expiringCerts = await supabase
        .from('certificates')
        .select('''
          id, certificate_number, valid_until,
          employees!employee_id (id, full_name, email),
          courses!course_id (id, title)
        ''')
        .eq('status', 'active')
        .gte('valid_until', startOfDay.toIso8601String())
        .lt('valid_until', endOfDay.toIso8601String());

    for (final cert in expiringCerts) {
      // Check if notification already sent for this threshold
      final existing = await supabase
          .from('notifications')
          .select('id')
          .eq('type', 'cert_expiry_$days')
          .eq('data->certificate_id', cert['id'])
          .maybeSingle();

      if (existing != null) continue;

      final employee = cert['employees'] as Map<String, dynamic>;
      final course = cert['courses'] as Map<String, dynamic>;

      // Create notification
      await supabase.from('notifications').insert({
        'employee_id': employee['id'],
        'type': 'cert_expiry_$days',
        'title': 'Certificate Expiring in $days Day(s)',
        'message': 'Your certificate for "${course['title']}" will expire on ${cert['valid_until']}.',
        'data': jsonEncode({
          'certificate_id': cert['id'],
          'certificate_number': cert['certificate_number'],
          'days_until_expiry': days,
        }),
        'created_at': now.toIso8601String(),
      });

      // Send email notification
      try {
        await supabase.functions.invoke(
          'send-notification',
          body: {
            'type': 'cert_expiry',
            'email': employee['email'],
            'title': 'Certificate Expiring Soon',
            'message': 'Your certificate for "${course['title']}" will expire in $days day(s).',
            'data': {
              'certificate_number': cert['certificate_number'],
              'valid_until': cert['valid_until'],
            },
          },
        );
      } catch (_) {
        // Email failures don't block processing
      }

      totalNotified++;
    }
  }

  final duration = DateTime.now().difference(startTime);

  // Log job execution
  await supabase.from('job_executions').insert({
    'job_name': 'cert_expiry',
    'started_at': startTime.toUtc().toIso8601String(),
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': 'success',
    'result': jsonEncode({
      'notifications_sent': totalNotified,
    }),
  });

  return ApiResponse.ok({
    'job': 'cert_expiry',
    'notifications_sent': totalNotified,
    'duration_ms': duration.inMilliseconds,
  }).toResponse();
}

/// POST /jobs/password-expiry
///
/// Checks for expiring passwords and sends notifications.
/// Runs hourly.
Future<Response> passwordExpiryHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final startTime = DateTime.now();
  final now = DateTime.now().toUtc();

  // Get password policy
  final policy = await supabase
      .from('password_policies')
      .select('expiry_days, warning_days_before')
      .maybeSingle();

  final expiryDays = (policy?['expiry_days'] as int?) ?? 90;
  final warningDays = (policy?['warning_days_before'] as int?) ?? 14;

  var totalNotified = 0;

  // Find credentials expiring within warning window
  final expiringCreds = await supabase
      .from('user_credentials')
      .select('''
        id, employee_id, password_changed_at,
        employees!employee_id (id, full_name, email)
      ''')
      .lt('password_changed_at', now.subtract(Duration(days: expiryDays - warningDays)).toIso8601String());

  for (final cred in expiringCreds) {
    final passwordChangedAt = DateTime.parse(cred['password_changed_at'] as String);
    final expiresAt = passwordChangedAt.add(Duration(days: expiryDays));
    final daysUntilExpiry = expiresAt.difference(now).inDays;

    if (daysUntilExpiry < 0) continue; // Already expired (handled elsewhere)

    // Check if notification already sent today
    final existing = await supabase
        .from('notifications')
        .select('id')
        .eq('type', 'password_expiry')
        .eq('employee_id', cred['employee_id'])
        .gte('created_at', DateTime(now.year, now.month, now.day).toIso8601String())
        .maybeSingle();

    if (existing != null) continue;

    final employee = cred['employees'] as Map<String, dynamic>;

    await supabase.from('notifications').insert({
      'employee_id': employee['id'],
      'type': 'password_expiry',
      'title': 'Password Expiring Soon',
      'message': 'Your password will expire in $daysUntilExpiry day(s). Please change it soon.',
      'data': jsonEncode({
        'days_until_expiry': daysUntilExpiry,
        'expires_at': expiresAt.toIso8601String(),
      }),
      'created_at': now.toIso8601String(),
    });

    totalNotified++;
  }

  final duration = DateTime.now().difference(startTime);

  await supabase.from('job_executions').insert({
    'job_name': 'password_expiry',
    'started_at': startTime.toUtc().toIso8601String(),
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': 'success',
    'result': jsonEncode({'notifications_sent': totalNotified}),
  });

  return ApiResponse.ok({
    'job': 'password_expiry',
    'notifications_sent': totalNotified,
    'duration_ms': duration.inMilliseconds,
  }).toResponse();
}

/// POST /jobs/session-cleanup
///
/// Expires idle sessions and cleans up old sessions.
/// Runs every 15 minutes.
Future<Response> sessionCleanupHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final startTime = DateTime.now();
  final now = DateTime.now().toUtc();

  // Get idle timeout setting
  final settings = await supabase
      .from('system_settings')
      .select('value')
      .eq('key', 'security.idle_timeout_minutes')
      .maybeSingle();

  final idleMinutes = int.tryParse(settings?['value'] as String? ?? '30') ?? 30;
  final idleCutoff = now.subtract(Duration(minutes: idleMinutes));

  // Expire idle sessions
  final idleExpired = await supabase
      .from('user_sessions')
      .update({
        'revoked_at': now.toIso8601String(),
        'revoke_reason': 'idle_timeout',
      })
      .isFilter('revoked_at', null)
      .lt('last_activity_at', idleCutoff.toIso8601String())
      .select('id');

  // Clean up expired sessions older than 7 days
  final cleanupCutoff = now.subtract(const Duration(days: 7));
  await supabase
      .from('user_sessions')
      .delete()
      .not('revoked_at', 'is', null)
      .lt('revoked_at', cleanupCutoff.toIso8601String());

  final duration = DateTime.now().difference(startTime);

  await supabase.from('job_executions').insert({
    'job_name': 'session_cleanup',
    'started_at': startTime.toUtc().toIso8601String(),
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': 'success',
    'result': jsonEncode({
      'idle_expired': idleExpired.length,
      'idle_timeout_minutes': idleMinutes,
    }),
  });

  return ApiResponse.ok({
    'job': 'session_cleanup',
    'idle_expired': idleExpired.length,
    'idle_timeout_minutes': idleMinutes,
    'duration_ms': duration.inMilliseconds,
  }).toResponse();
}
