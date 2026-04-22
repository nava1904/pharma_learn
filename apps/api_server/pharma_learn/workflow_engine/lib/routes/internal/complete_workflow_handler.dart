// POST /internal/workflow/complete
// Body: {entity_type: string, entity_id: UUID, org_id: UUID, completion_type: 'approved' | 'auto' | 'bypass'}
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// Handles workflow completion - final step after all approvals.
/// 
/// Called when:
/// 1. All approval steps are approved (normal flow)
/// 2. Auto-approval (no matrix exists)
/// 3. Admin bypass (emergency workflow skip)
/// 
/// Actions:
/// 1. Marks entity as EFFECTIVE
/// 2. Sets effective_date
/// 3. Creates version history entry
/// 4. Publishes workflow.completed event
/// 5. Triggers downstream actions (training assignments, etc.)
Future<Response> completeWorkflowHandler(Request req) async {
  final body = await readJson(req);
  final entityType = body['entity_type'] as String;
  final entityId = body['entity_id'] as String;
  final orgId = body['org_id'] as String;
  final completionType = body['completion_type'] as String? ?? 'approved';
  final completedBy = body['completed_by'] as String?;
  final bypassReason = body['bypass_reason'] as String?;
  
  final supabase = SupabaseService.client;
  final now = DateTime.now().toUtc();

  // 1. Verify all steps are approved (unless bypass)
  if (completionType != 'bypass' && completionType != 'auto') {
    final pendingSteps = await supabase
        .from('approval_steps')
        .select('id, step_name')
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .eq('status', 'pending');
    
    if ((pendingSteps as List).isNotEmpty) {
      throw ConflictException(
        'Cannot complete workflow: ${pendingSteps.length} steps pending',
      );
    }
  }

  // 2. Mark entity as EFFECTIVE
  final tableMap = _getTableName(entityType);
  if (tableMap != null) {
    await supabase.from(tableMap).update({
      'status': 'EFFECTIVE',
      'effective_date': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    }).eq('id', entityId);
  }

  // 3. Create version history entry
  try {
    final entity = await supabase
        .from(tableMap!)
        .select('version, title')
        .eq('id', entityId)
        .single();
    
    await supabase.from('version_history').insert({
      'entity_type': entityType,
      'entity_id': entityId,
      'version': entity['version'] ?? '1.0',
      'status': 'EFFECTIVE',
      'effective_date': now.toIso8601String(),
      'changed_by': completedBy,
      'change_type': 'workflow_completed',
      'change_reason': completionType == 'bypass' 
          ? 'Bypass: $bypassReason'
          : 'All approvals obtained',
      'organization_id': orgId,
      'created_at': now.toIso8601String(),
    });
  } catch (e) {
    // Version history is supplementary, continue on failure
  }

  // 4. Mark workflow as completed
  await supabase.from('workflow_instances').upsert({
    'entity_type': entityType,
    'entity_id': entityId,
    'organization_id': orgId,
    'status': 'completed',
    'completed_at': now.toIso8601String(),
    'completion_type': completionType,
    'completed_by': completedBy,
  }, onConflict: 'entity_type,entity_id');

  // 5. If bypass, log the administrative override
  if (completionType == 'bypass') {
    await supabase.from('audit_trails').insert({
      'entity_type': entityType,
      'entity_id': entityId,
      'action': 'WORKFLOW_BYPASS',
      'event_category': 'SECURITY',
      'performed_by': completedBy,
      'organization_id': orgId,
      'details': {
        'bypass_reason': bypassReason,
        'bypassed_at': now.toIso8601String(),
      },
    });
  }

  // 6. Publish completion event
  await EventPublisher.publish(
    supabase,
    eventType: '$entityType.approved',
    aggregateType: entityType,
    aggregateId: entityId,
    orgId: orgId,
    payload: {
      'completion_type': completionType,
      'completed_by': completedBy,
      'effective_date': now.toIso8601String(),
    },
  );

  // 7. Trigger downstream actions based on entity type
  await _triggerDownstreamActions(supabase, entityType, entityId, orgId);

  return ApiResponse.ok({
    'result': 'completed',
    'entity_type': entityType,
    'entity_id': entityId,
    'completion_type': completionType,
    'effective_date': now.toIso8601String(),
  }).toResponse();
}

/// Returns table name for entity type.
String? _getTableName(String entityType) {
  const tableMap = {
    'document': 'documents',
    'course': 'courses',
    'training_plan': 'training_plans',
    'gtp': 'training_plans',
    'question_paper': 'question_papers',
    'curriculum': 'curricula',
    'trainer': 'trainers',
    'schedule': 'training_schedules',
    'deviation': 'deviations',
    'capa': 'capas',
    'change_control': 'change_controls',
  };
  return tableMap[entityType];
}

/// Triggers entity-specific downstream actions.
Future<void> _triggerDownstreamActions(
    dynamic supabase, String entityType, String entityId, String orgId) async {
  switch (entityType) {
    case 'training_plan':
    case 'gtp':
      // Auto-assign training to employees based on TNIs
      await EventPublisher.publish(
        supabase,
        eventType: 'training_plan.effective',
        aggregateType: 'training_plan',
        aggregateId: entityId,
        orgId: orgId,
        payload: {'trigger': 'auto_assignment'},
      );
      break;
      
    case 'document':
      // Check for training requirements linked to document
      final trainings = await supabase
          .from('course_documents')
          .select('course_id')
          .eq('document_id', entityId);
      
      for (final link in trainings) {
        await EventPublisher.publish(
          supabase,
          eventType: 'document.linked_training',
          aggregateType: 'course',
          aggregateId: link['course_id'] as String,
          orgId: orgId,
          payload: {'document_id': entityId, 'action': 'document_effective'},
        );
      }
      break;
      
    case 'course':
      // Notify assigned employees of new training available
      await EventPublisher.publish(
        supabase,
        eventType: 'course.available',
        aggregateType: 'course',
        aggregateId: entityId,
        orgId: orgId,
        payload: {'trigger': 'notify_assignees'},
      );
      break;
      
    case 'curriculum':
      // Update linked GTPs with new curriculum version
      await EventPublisher.publish(
        supabase,
        eventType: 'curriculum.updated',
        aggregateType: 'curriculum',
        aggregateId: entityId,
        orgId: orgId,
        payload: {'trigger': 'cascade_updates'},
      );
      break;
      
    case 'schedule':
      // Notify enrolled trainees
      await EventPublisher.publish(
        supabase,
        eventType: 'schedule.confirmed',
        aggregateType: 'schedule',
        aggregateId: entityId,
        orgId: orgId,
        payload: {'trigger': 'notify_participants'},
      );
      break;
  }
}
