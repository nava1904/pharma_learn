import 'package:supabase/supabase.dart';
import 'package:logger/logger.dart';
import 'package:cron/cron.dart';

import 'report_generator_service.dart';

// ---------------------------------------------------------------------------
// Job Scheduler Service
// ---------------------------------------------------------------------------
// Runs recurring background jobs on cron schedules
// ---------------------------------------------------------------------------

class JobSchedulerService {
  final SupabaseClient _supabase;
  final Logger _logger = Logger();
  final Cron _cron = Cron();
  late final ReportGeneratorService _reportGenerator;

  JobSchedulerService(this._supabase) {
    _reportGenerator = ReportGeneratorService(_supabase);
  }

  void start() {
    _logger.i('JobSchedulerService: starting cron jobs');

    // Report generation: every minute (processes queued reports)
    _cron.schedule(Schedule.parse('* * * * *'), () async {
      await _runJob('report_generation', _reportGenerationJob);
    });

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

    // Unblock prerequisites: every 15 minutes
    // Checks for completed courses and unblocks dependent obligations
    _cron.schedule(Schedule.parse('*/15 * * * *'), () async {
      await _runJob('unblock_prerequisites', _unblockPrerequisitesJob);
    });

    // Blended WBT overdue check: every hour
    // Marks blended_wbt obligations as overdue if deadline passed
    _cron.schedule(Schedule.parse('45 * * * *'), () async {
      await _runJob('blended_wbt_overdue', _blendedWbtOverdueJob);
    });

    // ─────────────────────────────────────────────────────────────────────
    // S7: WORKFLOW & EVENT JOBS
    // ─────────────────────────────────────────────────────────────────────

    // Escalation check: every 4 hours
    // Notifies supervisors about pending approvals that have been waiting too long
    _cron.schedule(Schedule.parse('0 */4 * * *'), () async {
      await _runJob('approval_escalation', _approvalEscalationJob);
    });

    // Dead-letter alert: every hour
    // Alerts super_admin about events that have exceeded max retries
    _cron.schedule(Schedule.parse('15 * * * *'), () async {
      await _runJob('dead_letter_alert', _deadLetterAlertJob);
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

  /// Unblocks training obligations when prerequisites are completed (Alfa §4.2.1.25).
  /// 
  /// Logic:
  /// 1. Find all obligations with status = 'blocked'
  /// 2. For each, check if all prerequisite courses are completed
  /// 3. If yes, update status to 'pending'
  Future<void> _unblockPrerequisitesJob() async {
    // Get blocked obligations with their course prerequisite info
    final blockedObligations = await _supabase
        .from('employee_training_obligations')
        .select('''
          id, employee_id, course_id, organization_id,
          courses!inner(
            id, prerequisite_course_ids
          )
        ''')
        .eq('status', 'blocked');

    int unblocked = 0;

    for (final obligation in blockedObligations as List) {
      final employeeId = obligation['employee_id'] as String;
      final course = obligation['courses'] as Map<String, dynamic>?;
      final prerequisiteIds = course?['prerequisite_course_ids'] as List? ?? [];

      if (prerequisiteIds.isEmpty) {
        // No prerequisites - shouldn't be blocked, unblock it
        await _supabase
            .from('employee_training_obligations')
            .update({
              'status': 'pending',
              'unblocked_at': DateTime.now().toUtc().toIso8601String(),
              'unblock_reason': 'no_prerequisites',
            })
            .eq('id', obligation['id']);
        unblocked++;
        continue;
      }

      // Check if all prerequisites are completed
      final completedPrereqs = await _supabase
          .from('training_records')
          .select('course_id')
          .eq('employee_id', employeeId)
          .eq('overall_status', 'completed')
          .inFilter('course_id', prerequisiteIds);

      final completedIds = (completedPrereqs as List)
          .map((r) => r['course_id'] as String)
          .toSet();

      final allPrereqsComplete = prerequisiteIds.every(
        (id) => completedIds.contains(id),
      );

      if (allPrereqsComplete) {
        await _supabase
            .from('employee_training_obligations')
            .update({
              'status': 'pending',
              'unblocked_at': DateTime.now().toUtc().toIso8601String(),
              'unblock_reason': 'prerequisites_completed',
            })
            .eq('id', obligation['id']);
        unblocked++;

        // Send notification to employee
        await _supabase.functions.invoke('send-notification', body: {
          'employee_id': employeeId,
          'template_key': 'training_unblocked',
          'data': {
            'course_id': obligation['course_id'],
          },
        });
      }
    }

    if (unblocked > 0) {
      _logger.i('Unblocked $unblocked training obligations');
    }
  }

  /// Marks blended WBT obligations as overdue if deadline has passed (Alfa §4.3.13).
  /// 
  /// For blended sessions:
  /// - ILT attendance is recorded immediately
  /// - WBT must be completed within blended_wbt_deadline_days
  /// - If not completed by deadline, obligation becomes overdue
  Future<void> _blendedWbtOverdueJob() async {
    final now = DateTime.now().toUtc();

    // Find blended WBT obligations past their due date
    final overdueObligations = await _supabase
        .from('employee_training_obligations')
        .select('id, employee_id, course_id, organization_id, due_date')
        .eq('obligation_type', 'blended_wbt')
        .eq('status', 'pending')
        .lt('due_date', now.toIso8601String());

    int markedOverdue = 0;

    for (final obligation in overdueObligations as List) {
      final employeeId = obligation['employee_id'] as String;
      final courseId = obligation['course_id'] as String;

      // Check if WBT has been completed since obligation was created
      final wbtProgress = await _supabase
          .from('learning_progress')
          .select('id, status, completed_at')
          .eq('employee_id', employeeId)
          .eq('course_id', courseId)
          .eq('status', 'completed')
          .maybeSingle();

      if (wbtProgress != null) {
        // WBT completed - mark obligation as completed
        await _supabase
            .from('employee_training_obligations')
            .update({
              'status': 'completed',
              'completed_at': wbtProgress['completed_at'],
            })
            .eq('id', obligation['id']);
      } else {
        // WBT still not completed - mark as overdue
        await _supabase
            .from('employee_training_obligations')
            .update({
              'status': 'overdue',
              'escalation_level': 1,
              'last_escalation_at': now.toIso8601String(),
            })
            .eq('id', obligation['id']);

        // Send notification
        await _supabase.functions.invoke('send-notification', body: {
          'employee_id': employeeId,
          'template_key': 'blended_wbt_overdue',
          'data': {
            'course_id': courseId,
            'due_date': obligation['due_date'],
          },
        });

        markedOverdue++;
      }
    }

    if (markedOverdue > 0) {
      _logger.i('Marked $markedOverdue blended WBT obligations as overdue');
    }
  }

  Future<void> _reportGenerationJob() async {
    // Process queued reports one at a time
    await _reportGenerator.processQueuedReports();
  }

  // ───────────────────────────────────────────────────────────────────────
  // S7: WORKFLOW JOBS
  // ───────────────────────────────────────────────────────────────────────

  /// Finds approval steps pending > 3 days and sends escalation notifications.
  /// Uses escalation_sent_at to avoid duplicate notifications.
  Future<void> _approvalEscalationJob() async {
    final pendingSteps = await _supabase.rpc(
      'get_escalation_candidates',
      params: {
        'p_escalation_days': 3,
      },
    );

    for (final step in pendingSteps as List) {
      // Find supervisor for escalation
      // In production, this would look up the supervisor based on org hierarchy
      final supervisor = await _supabase
          .from('employees')
          .select('id')
          .eq('organization_id', step['organization_id'])
          .eq('role', 'plant_admin')
          .limit(1)
          .maybeSingle();

      if (supervisor != null) {
        // Send escalation notification
        await _supabase.functions.invoke('send-notification', body: {
          'employee_id': supervisor['id'],
          'template_key': 'approval_escalation',
          'data': {
            'entity_type': step['entity_type'],
            'entity_id': step['entity_id'],
            'step_name': step['step_name'],
            'days_pending': step['days_pending'],
            'required_role': step['required_role'],
          },
        });
      }

      // Mark escalation sent
      await _supabase
          .from('approval_steps')
          .update({'escalation_sent_at': DateTime.now().toIso8601String()})
          .eq('id', step['step_id']);

      _logger.i(
        'Escalated approval step ${step['step_id']} for ${step['entity_type']}/${step['entity_id']}',
      );
    }
  }

  /// Alerts super_admin about dead letter events (exceeded max retries).
  /// Uses dead_letter_alerted_at to avoid duplicate alerts.
  Future<void> _deadLetterAlertJob() async {
    final deadLetters = await _supabase.rpc('get_dead_letter_events');

    if ((deadLetters as List).isEmpty) return;

    // Group by organization for consolidated alerts
    final byOrg = <String, List<Map<String, dynamic>>>{};
    for (final dl in deadLetters) {
      final orgId = dl['organization_id'] as String? ?? 'global';
      byOrg.putIfAbsent(orgId, () => []).add(Map<String, dynamic>.from(dl as Map));
    }

    for (final entry in byOrg.entries) {
      final orgId = entry.key;
      final events = entry.value;

      // Find super_admin for this org
      final superAdmin = await _supabase
          .from('employees')
          .select('id')
          .eq('organization_id', orgId)
          .eq('role', 'super_admin')
          .limit(1)
          .maybeSingle();

      if (superAdmin != null) {
        await _supabase.functions.invoke('send-notification', body: {
          'employee_id': superAdmin['id'],
          'template_key': 'dead_letter_alert',
          'data': {
            'count': events.length,
            'events': events.map((e) => {
              'id': e['event_id'],
              'type': e['event_type'],
              'error': e['error_text'],
              'retries': e['retry_count'],
            }).toList(),
          },
        });
      }

      // Mark as alerted
      for (final event in events) {
        await _supabase.rpc('mark_dead_letter_alerted', params: {
          'p_event_id': event['event_id'],
        });
      }

      _logger.w(
        'Alerted super_admin about ${events.length} dead letter events in org $orgId',
      );
    }
  }

  Future<void> stop() async {
    await _cron.close();
  }
}
