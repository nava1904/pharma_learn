import 'package:supabase/supabase.dart';
import 'package:logger/logger.dart';
import 'package:cron/cron.dart';

// Schedules recurring background jobs
class JobSchedulerService {
  final SupabaseClient _supabase;
  final Logger _logger = Logger();
  final Cron _cron = Cron();

  JobSchedulerService(this._supabase);

  void start() {
    _logger.i('JobSchedulerService: starting cron jobs');

    // Cert expiry: every hour
    _cron.schedule(Schedule.parse('0 * * * *'), () async {
      await _runJob('cert_expiry', _certExpiryJob);
    });

    // Overdue training: every hour
    _cron.schedule(Schedule.parse('30 * * * *'), () async {
      await _runJob('overdue_training', _overdueTrainingJob);
    });

    // Session cleanup: every 15 minutes
    _cron.schedule(Schedule.parse('*/15 * * * *'), () async {
      await _runJob('session_cleanup', _sessionCleanupJob);
    });

    // Integrity check: nightly at 2am
    _cron.schedule(Schedule.parse('0 2 * * *'), () async {
      await _runJob('integrity_check', _integrityCheckJob);
    });

    // Archive: nightly at 3am
    _cron.schedule(Schedule.parse('0 3 * * *'), () async {
      await _runJob('archive', _archiveJob);
    });

    // Password expiry: daily at 8am
    _cron.schedule(Schedule.parse('0 8 * * *'), () async {
      await _runJob('password_expiry', _passwordExpiryJob);
    });

    // Compliance metrics: every 6 hours
    _cron.schedule(Schedule.parse('0 */6 * * *'), () async {
      await _runJob('compliance_metrics', _complianceMetricsJob);
    });

    // Periodic review: daily at 7am
    _cron.schedule(Schedule.parse('0 7 * * *'), () async {
      await _runJob('periodic_review', _periodicReviewJob);
    });
  }

  Future<void> _runJob(String name, Future<void> Function() job) async {
    _logger.i('Running job: $name');
    try {
      await job();
      _logger.i('Job $name completed');
    } catch (e) {
      _logger.e('Job $name failed: $e');
    }
  }

  Future<void> _certExpiryJob() async {
    final thirtyDaysFromNow =
        DateTime.now().add(const Duration(days: 30)).toIso8601String();
    final expiring = await _supabase
        .from('certificates')
        .select('employee_id, course_name:training_records(courses(title)), valid_until')
        .lte('valid_until', thirtyDaysFromNow)
        .eq('status', 'ACTIVE');

    for (final cert in expiring as List) {
      await _supabase.functions.invoke('send-notification', body: {
        'employee_id': cert['employee_id'],
        'template_key': 'cert_expiry_30d',
        'data': {'valid_until': cert['valid_until']},
      });
    }
  }

  Future<void> _overdueTrainingJob() async {
    await _supabase.rpc('mark_overdue_reviews');
  }

  Future<void> _sessionCleanupJob() async {
    await _supabase.rpc('cleanup_expired_sessions');
  }

  Future<void> _integrityCheckJob() async {
    await _supabase.rpc('verify_audit_hash_chain');
  }

  Future<void> _archiveJob() async {
    await _supabase.rpc('process_retention_policies');
  }

  Future<void> _passwordExpiryJob() async {
    final sevenDaysFromNow =
        DateTime.now().add(const Duration(days: 7)).toIso8601String();
    final expiring = await _supabase
        .from('user_credentials')
        .select('employee_id, expires_at')
        .lte('expires_at', sevenDaysFromNow)
        .gt('expires_at', DateTime.now().toIso8601String());

    for (final cred in expiring as List) {
      await _supabase.functions.invoke('send-notification', body: {
        'employee_id': cred['employee_id'],
        'template_key': 'password_expiry_warning',
        'data': {'expires_at': cred['expires_at']},
      });
    }
  }

  Future<void> _complianceMetricsJob() async {
    await _supabase.rpc('recalculate_compliance_metrics');
  }

  Future<void> _periodicReviewJob() async {
    await _supabase.rpc('mark_overdue_reviews');
  }

  Future<void> stop() async {
    await _cron.close();
  }
}
