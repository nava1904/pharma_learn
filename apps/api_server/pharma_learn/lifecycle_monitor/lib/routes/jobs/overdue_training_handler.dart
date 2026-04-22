import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /jobs/overdue-training
///
/// Processes overdue training obligations and escalates notifications.
/// Alfa §4.3.3 Overdue Escalation Tiers:
/// - Day 1-7: Mark as overdue, yellow flag
/// - Day 8-14: Email employee
/// - Day 15-29: Escalate to manager
/// - Day 30+: Escalate to director, CAPA candidate
/// Runs hourly via scheduler.
Future<Response> overdueTrainingHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final startTime = DateTime.now();
  final now = DateTime.now().toUtc();

  // Get all overdue obligations
  final overdueObligations = await supabase
      .from('employee_assignments')
      .select('''
        id, employee_id, course_id, due_date, status, escalation_level, last_escalation_at,
        employees!employee_id (
          id, full_name, email, manager_id,
          managers:employees!manager_id (id, full_name, email)
        ),
        courses!course_id (id, title)
      ''')
      .lt('due_date', now.toIso8601String())
      .neq('status', 'completed')
      .neq('status', 'waived');

  var processed = 0;
  var escalated = 0;
  final notifications = <Map<String, dynamic>>[];

  for (final obligation in overdueObligations) {
    final dueDate = DateTime.parse(obligation['due_date'] as String);
    final daysOverdue = now.difference(dueDate).inDays;
    final currentLevel = obligation['escalation_level'] as int? ?? 0;
    // lastEscalation available for future cooldown logic
    // final lastEscalation = obligation['last_escalation_at'] as String?;

    // Determine new escalation level
    int newLevel;
    if (daysOverdue >= 30) {
      newLevel = 4; // Director + CAPA
    } else if (daysOverdue >= 15) {
      newLevel = 3; // Manager
    } else if (daysOverdue >= 8) {
      newLevel = 2; // Employee email
    } else {
      newLevel = 1; // Yellow flag
    }

    // Only escalate if level has increased
    if (newLevel > currentLevel) {
      escalated++;

      // Update obligation
      await supabase.from('employee_assignments').update({
        'status': 'overdue',
        'escalation_level': newLevel,
        'last_escalation_at': now.toIso8601String(),
      }).eq('id', obligation['id']);

      // Create notification based on level
      final employee = obligation['employees'] as Map<String, dynamic>;
      final course = obligation['courses'] as Map<String, dynamic>;

      switch (newLevel) {
        case 2:
          // Email to employee
          notifications.add({
            'type': 'overdue_training_employee',
            'recipient_id': employee['id'],
            'email': employee['email'],
            'title': 'Training Overdue: ${course['title']}',
            'message': 'Your training "${course['title']}" is $daysOverdue days overdue. Please complete it immediately.',
            'level': newLevel,
          });
          break;

        case 3:
          // Escalate to manager
          final manager = employee['managers'] as Map<String, dynamic>?;
          if (manager != null) {
            notifications.add({
              'type': 'overdue_training_manager',
              'recipient_id': manager['id'],
              'email': manager['email'],
              'title': 'Employee Training Overdue: ${employee['full_name']}',
              'message': '${employee['full_name']} has training "${course['title']}" that is $daysOverdue days overdue.',
              'level': newLevel,
            });
          }
          break;

        case 4:
          // Escalate to director + flag for CAPA
          // Get plant director
          final directors = await supabase
              .from('employee_roles')
              .select('employees!employee_id (id, email, full_name)')
              .eq('role_id', 'director')
              .limit(5);

          for (final director in directors) {
            final dirEmployee = director['employees'] as Map<String, dynamic>;
            notifications.add({
              'type': 'overdue_training_director',
              'recipient_id': dirEmployee['id'],
              'email': dirEmployee['email'],
              'title': 'CRITICAL: Training Compliance Issue',
              'message': '${employee['full_name']} has training "${course['title']}" that is $daysOverdue days overdue. CAPA may be required.',
              'level': newLevel,
            });
          }

          // Flag for CAPA
          await supabase.from('capa_candidates').insert({
            'source_type': 'overdue_training',
            'source_id': obligation['id'],
            'employee_id': employee['id'],
            'description': 'Training "${course['title']}" overdue by $daysOverdue days',
            'created_at': now.toIso8601String(),
          });
          break;
      }
    }

    processed++;
  }

  // Send notifications via Edge Function
  for (final notification in notifications) {
    try {
      await supabase.functions.invoke(
        'send-notification',
        body: notification,
      );

      // Record notification sent
      await supabase.from('notifications').insert({
        'employee_id': notification['recipient_id'],
        'type': notification['type'],
        'title': notification['title'],
        'message': notification['message'],
        'data': jsonEncode({'level': notification['level']}),
        'created_at': now.toIso8601String(),
      });
    } catch (e) {
      // Log failure but continue
      await supabase.from('notification_failures').insert({
        'notification_type': notification['type'],
        'recipient_id': notification['recipient_id'],
        'error': e.toString(),
        'created_at': now.toIso8601String(),
      });
    }
  }

  final duration = DateTime.now().difference(startTime);

  // Log job execution
  await supabase.from('job_executions').insert({
    'job_name': 'overdue_training',
    'started_at': startTime.toUtc().toIso8601String(),
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': 'success',
    'result': jsonEncode({
      'processed': processed,
      'escalated': escalated,
      'notifications_sent': notifications.length,
    }),
  });

  return ApiResponse.ok({
    'job': 'overdue_training',
    'processed': processed,
    'escalated': escalated,
    'notifications_sent': notifications.length,
    'duration_ms': duration.inMilliseconds,
    'compliance': {
      'standard': 'Alfa A-SOP-QA-015',
      'clause': '§4.3.3',
    },
  }).toResponse();
}
