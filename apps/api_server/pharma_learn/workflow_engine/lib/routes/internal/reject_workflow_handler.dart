// POST /internal/workflow/reject
// Body: {step_id: UUID, rejected_by: UUID, reason: string, esignature_id?: UUID}
import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// Handles rejection of an approval step.
/// 
/// Flow:
/// 1. Validates the step exists and is pending
/// 2. Calls reject_step RPC which:
///    - Marks step as rejected
///    - Cancels all remaining pending steps
/// 3. Updates entity status to REJECTED
/// 4. Publishes rejection event for notifications
///
/// Per design: rejection means the submitter must create a NEW version
/// with a new UUID. The rejected entity stays forever as an audit record.
Future<Response> rejectWorkflowHandler(Request req) async {
  final body = await readJson(req);
  final stepId = body['step_id'] as String;
  final rejectedBy = body['rejected_by'] as String;
  final reason = body['reason'] as String;
  final esignatureId = body['esignature_id'] as String?;
  
  final supabase = SupabaseService.client;

  // 1. Get step details first (for entity info)
  final step = await supabase
      .from('approval_steps')
      .select('entity_type, entity_id, organization_id, step_name')
      .eq('id', stepId)
      .maybeSingle();

  if (step == null) {
    return ErrorResponse.notFound('Approval step not found: $stepId').toResponse();
  }

  final entityType = step['entity_type'] as String;
  final entityId = step['entity_id'] as String;
  final orgId = step['organization_id'] as String;
  final stepName = step['step_name'] as String;

  // 2. Call reject_step RPC (marks rejected + cancels remaining)
  try {
    final result = await supabase.rpc(
      'reject_step',
      params: {
        'p_step_id': stepId,
        'p_rejected_by': rejectedBy,
        'p_reason': reason,
        'p_esignature_id': esignatureId,
      },
    );
    
    final cancelledSteps = (result as List).isNotEmpty 
        ? result[0]['cancelled_steps'] as int? ?? 0 
        : 0;

    // 3. Update entity status to REJECTED
    await _markEntityRejected(supabase, entityType, entityId, reason);

    // 4. Publish rejection event
    await EventPublisher.publish(
      supabase,
      eventType: '$entityType.rejected',
      aggregateType: entityType,
      aggregateId: entityId,
      orgId: orgId,
      payload: {
        'step_id': stepId,
        'step_name': stepName,
        'rejected_by': rejectedBy,
        'reason': reason,
        'cancelled_steps': cancelledSteps,
      },
    );

    return ApiResponse.ok({
      'result': 'rejected',
      'entity_id': entityId,
      'entity_type': entityType,
      'step_id': stepId,
      'cancelled_steps': cancelledSteps,
    }).toResponse();
    
  } on PostgrestException catch (e) {
    if (e.message.contains('not found')) {
      return ErrorResponse.notFound('Approval step not found: $stepId').toResponse();
    }
    if (e.message.contains('not pending')) {
      return ErrorResponse.conflict(
        'Step cannot be rejected: already processed',
      ).toResponse();
    }
    rethrow;
  }
}

Future<void> _markEntityRejected(
    dynamic supabase, String entityType, String entityId, String reason) async {
  final tableMap = {
    'document': 'documents',
    'course': 'courses',
    'gtp': 'training_plans',
    'question_paper': 'question_papers',
    'curriculum': 'curricula',
    'trainer': 'trainers',
    'schedule': 'training_schedules',
  };
  final table = tableMap[entityType];
  if (table != null) {
    await supabase.from(table).update({
      'status': 'REJECTED',
      'rejection_reason': reason,
      'rejected_at': DateTime.now().toIso8601String(),
    }).eq('id', entityId);
  }
}
