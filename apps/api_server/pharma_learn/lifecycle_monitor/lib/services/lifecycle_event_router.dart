import 'package:supabase/supabase.dart';
import 'package:logger/logger.dart';

// ---------------------------------------------------------------------------
// Lifecycle Event Router
// ---------------------------------------------------------------------------
// Routes incoming events (from PgListenerService) to appropriate handlers.
// Events are dispatched based on event_type prefix:
//   - workflow.* → workflow_engine (for step_pending, step_approved events)
//   - *.approved → notification fanout + training record updates
//   - *.rejected → notification to submitter
//   - certificate.* → compliance recalculations
//   - notification.* → send via email/push
// ---------------------------------------------------------------------------

class LifecycleEventRouter {
  final SupabaseClient _supabase;
  final Logger _logger = Logger();

  LifecycleEventRouter(this._supabase);

  /// Routes an event to appropriate handlers based on event_type.
  Future<void> route(Map<String, dynamic> event) async {
    final eventType = event['event_type'] as String;
    final aggregateType = event['aggregate_type'] as String;
    final aggregateId = event['aggregate_id'] as String;
    final payload = event['payload'] as Map<String, dynamic>? ?? {};
    final orgId = event['organization_id'] as String?;

    _logger.d('Routing event: $eventType for $aggregateType/$aggregateId');

    // Route based on event type patterns
    if (eventType.startsWith('workflow.')) {
      await _handleWorkflowEvent(eventType, aggregateType, aggregateId, payload, orgId);
    } else if (eventType.endsWith('.approved')) {
      await _handleApprovedEvent(aggregateType, aggregateId, payload, orgId);
    } else if (eventType.endsWith('.rejected')) {
      await _handleRejectedEvent(aggregateType, aggregateId, payload, orgId);
    } else if (eventType.startsWith('certificate.')) {
      await _handleCertificateEvent(eventType, aggregateId, payload, orgId);
    } else if (eventType.startsWith('training.')) {
      await _handleTrainingEvent(eventType, aggregateId, payload, orgId);
    } else if (eventType == 'notification.send') {
      await _handleNotificationSend(payload, orgId);
    } else {
      // Generic handler for unmatched events
      _logger.d('Unhandled event type: $eventType');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WORKFLOW EVENTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleWorkflowEvent(
    String eventType,
    String aggregateType,
    String aggregateId,
    Map<String, dynamic> payload,
    String? orgId,
  ) async {
    switch (eventType) {
      case 'workflow.step_pending':
        // Notify potential approvers
        await _notifyApprovers(aggregateType, aggregateId, payload, orgId);
        break;

      case 'workflow.step_approved':
        // Notify submitter that step was approved
        await _notifyStepProgress(aggregateType, aggregateId, payload, orgId, 'approved');
        break;

      default:
        _logger.d('Unknown workflow event: $eventType');
    }
  }

  Future<void> _notifyApprovers(
    String aggregateType,
    String aggregateId,
    Map<String, dynamic> payload,
    String? orgId,
  ) async {
    final requiredRole = payload['required_role'] as String?;
    final minTier = payload['min_approval_tier'] as int? ?? 0;
    final stepName = payload['step_name'] as String? ?? 'Approval';

    if (requiredRole == null || orgId == null) return;

    // Find employees with the required role and tier
    final approvers = await _supabase
        .from('employees')
        .select('id')
        .eq('organization_id', orgId)
        .eq('role', requiredRole)
        .gte('tier', minTier)
        .eq('is_active', true);

    // Load entity details for notification
    final tableMap = {
      'document': 'documents',
      'course': 'courses',
      'gtp': 'training_plans',
    };
    final table = tableMap[aggregateType];
    String? entityTitle;
    if (table != null) {
      final entity = await _supabase
          .from(table)
          .select('title')
          .eq('id', aggregateId)
          .maybeSingle();
      entityTitle = entity?['title'] as String?;
    }

    // Send notification to each potential approver
    for (final approver in approvers as List) {
      await _sendNotification(
        approver['id'] as String,
        'approval_required',
        {
          'entity_type': aggregateType,
          'entity_id': aggregateId,
          'entity_title': entityTitle,
          'step_name': stepName,
        },
      );
    }

    _logger.i(
      'Notified ${approvers.length} approvers for $aggregateType/$aggregateId step "$stepName"',
    );
  }

  Future<void> _notifyStepProgress(
    String aggregateType,
    String aggregateId,
    Map<String, dynamic> payload,
    String? orgId,
    String status,
  ) async {
    // Find the original submitter
    final tableMap = {
      'document': 'documents',
      'course': 'courses',
      'gtp': 'training_plans',
    };
    final table = tableMap[aggregateType];
    if (table == null || orgId == null) return;

    final entity = await _supabase
        .from(table)
        .select('created_by, title')
        .eq('id', aggregateId)
        .maybeSingle();

    if (entity == null) return;

    final submitterId = entity['created_by'] as String?;
    if (submitterId == null) return;

    await _sendNotification(
      submitterId,
      'approval_step_$status',
      {
        'entity_type': aggregateType,
        'entity_id': aggregateId,
        'entity_title': entity['title'],
        'step_id': payload['step_id'],
        'approved_by': payload['approved_by'],
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // APPROVED / REJECTED EVENTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleApprovedEvent(
    String aggregateType,
    String aggregateId,
    Map<String, dynamic> payload,
    String? orgId,
  ) async {
    // Notify submitter
    await _notifySubmitterOfCompletion(aggregateType, aggregateId, 'approved', orgId);

    // For training content, update any GTPs that reference this content
    if (['document', 'course'].contains(aggregateType)) {
      await _updateRelatedGtps(aggregateType, aggregateId);
    }
  }

  Future<void> _handleRejectedEvent(
    String aggregateType,
    String aggregateId,
    Map<String, dynamic> payload,
    String? orgId,
  ) async {
    final reason = payload['reason'] as String? ?? 'No reason provided';
    
    // Notify submitter
    await _notifySubmitterOfCompletion(
      aggregateType, 
      aggregateId, 
      'rejected', 
      orgId,
      extraData: {'reason': reason},
    );
  }

  Future<void> _notifySubmitterOfCompletion(
    String aggregateType,
    String aggregateId,
    String status,
    String? orgId, {
    Map<String, dynamic>? extraData,
  }) async {
    final tableMap = {
      'document': 'documents',
      'course': 'courses',
      'gtp': 'training_plans',
    };
    final table = tableMap[aggregateType];
    if (table == null) return;

    final entity = await _supabase
        .from(table)
        .select('created_by, title')
        .eq('id', aggregateId)
        .maybeSingle();

    if (entity == null) return;

    final submitterId = entity['created_by'] as String?;
    if (submitterId == null) return;

    await _sendNotification(
      submitterId,
      '${aggregateType}_$status',
      {
        'entity_type': aggregateType,
        'entity_id': aggregateId,
        'entity_title': entity['title'],
        ...?extraData,
      },
    );
  }

  Future<void> _updateRelatedGtps(String aggregateType, String aggregateId) async {
    // This could trigger recalculation of GTP readiness
    // For now, just log it
    _logger.d('Content approved: $aggregateType/$aggregateId - checking related GTPs');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CERTIFICATE EVENTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleCertificateEvent(
    String eventType,
    String aggregateId,
    Map<String, dynamic> payload,
    String? orgId,
  ) async {
    switch (eventType) {
      case 'certificate.issued':
        // Recalculate compliance for employee
        final employeeId = payload['employee_id'] as String?;
        if (employeeId != null) {
          await _supabase.rpc('recalculate_employee_compliance', params: {
            'p_employee_id': employeeId,
          });
        }
        break;

      case 'certificate.expired':
        // Notify employee of expiration
        final employeeId = payload['employee_id'] as String?;
        if (employeeId != null) {
          await _sendNotification(employeeId, 'certificate_expired', {
            'certificate_id': aggregateId,
            'expired_at': payload['expired_at'],
          });
        }
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TRAINING EVENTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleTrainingEvent(
    String eventType,
    String aggregateId,
    Map<String, dynamic> payload,
    String? orgId,
  ) async {
    switch (eventType) {
      case 'training.completed':
        // Update training record status
        final employeeId = payload['employee_id'] as String?;
        if (employeeId != null) {
          await _sendNotification(employeeId, 'training_completed', {
            'training_record_id': aggregateId,
          });
        }
        break;

      case 'training.assigned':
        // Notify employee of new assignment
        final employeeId = payload['employee_id'] as String?;
        if (employeeId != null) {
          await _sendNotification(employeeId, 'training_assigned', {
            'training_plan_id': aggregateId,
            'due_date': payload['due_date'],
          });
        }
        break;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATION EVENTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _handleNotificationSend(
    Map<String, dynamic> payload,
    String? orgId,
  ) async {
    final employeeId = payload['employee_id'] as String?;
    final templateKey = payload['template_key'] as String?;
    final data = payload['data'] as Map<String, dynamic>? ?? {};

    if (employeeId != null && templateKey != null) {
      await _sendNotification(employeeId, templateKey, data);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER METHODS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendNotification(
    String employeeId,
    String templateKey,
    Map<String, dynamic> data,
  ) async {
    try {
      // Insert notification record
      await _supabase.from('notifications').insert({
        'employee_id': employeeId,
        'template_key': templateKey,
        'data': data,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Optionally call edge function for immediate delivery
      await _supabase.functions.invoke('send-notification', body: {
        'employee_id': employeeId,
        'template_key': templateKey,
        'data': data,
      });
    } catch (e) {
      _logger.e('Failed to send notification to $employeeId: $e');
    }
  }
}
