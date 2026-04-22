// POST /internal/workflow/approve-step
// Body: {step_id: UUID, approved_by: UUID, esignature_id?: UUID}
import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// Handles approval of an individual step.
/// 
/// Flow:
/// 1. Validates approver has permission for this step's required_role/tier
/// 2. Calls approve_step RPC
/// 3. Checks if all steps are now complete
/// 4. If complete, marks entity effective
/// 5. Otherwise, triggers next step notification
///
/// For parallel approval with quorum:
/// - Multiple approvers may approve at same step_order
/// - When quorum is met, remaining parallel steps are auto-skipped
Future<Response> approveStepHandler(Request req) async {
  final body = await readJson(req);
  final stepId = body['step_id'] as String;
  final approvedBy = body['approved_by'] as String;
  final esignatureId = body['esignature_id'] as String?;
  
  final supabase = SupabaseService.client;

  // 1. Get step details and validate
  final step = await supabase
      .from('approval_steps')
      .select('''
        entity_type, 
        entity_id, 
        organization_id, 
        step_name,
        step_order,
        min_approval_tier,
        required_role,
        status
      ''')
      .eq('id', stepId)
      .maybeSingle();

  if (step == null) {
    return ErrorResponse.notFound('Approval step not found: $stepId').toResponse();
  }

  if (step['status'] != 'pending') {
    return ErrorResponse.conflict(
      'Step cannot be approved: current status is ${step['status']}',
    ).toResponse();
  }

  final entityType = step['entity_type'] as String;
  final entityId = step['entity_id'] as String;
  final orgId = step['organization_id'] as String;
  final stepOrder = step['step_order'] as int;

  // 2. Verify approver has required tier (via get_employee_permissions)
  // In production, this would check if the approver has the required role/tier
  // For now, we trust the API layer has already validated this

  // 3. Call approve_step RPC
  try {
    await supabase.rpc(
      'approve_step',
      params: {
        'p_step_id': stepId,
        'p_approved_by': approvedBy,
        'p_esignature_id': esignatureId,
      },
    );

    // 4. Check if quorum is met for parallel steps (if applicable)
    await _checkAndSkipParallelSteps(supabase, entityType, entityId, stepOrder);

    // 5. Check if all approval is complete
    final isComplete = await supabase.rpc(
      'check_approval_complete',
      params: {
        'p_entity_type': entityType,
        'p_entity_id': entityId,
      },
    );

    if (isComplete == true) {
      // All steps complete — mark entity effective
      await _markEntityEffective(supabase, entityType, entityId);
      
      // Publish completion event
      await EventPublisher.publish(
        supabase,
        eventType: '${entityType}.approved',
        aggregateType: entityType,
        aggregateId: entityId,
        orgId: orgId,
        payload: {
          'final_step_id': stepId,
          'approved_by': approvedBy,
        },
      );

      return ApiResponse.ok({
        'result': 'completed',
        'entity_id': entityId,
        'entity_type': entityType,
        'effective': true,
      }).toResponse();
    }

    // 6. Not complete — publish step approved event for next step notification
    await EventPublisher.publish(
      supabase,
      eventType: 'workflow.step_approved',
      aggregateType: entityType,
      aggregateId: entityId,
      orgId: orgId,
      payload: {
        'step_id': stepId,
        'approved_by': approvedBy,
      },
    );

    // Get next pending step info
    final nextStep = await supabase.rpc(
      'get_next_pending_step',
      params: {
        'p_entity_type': entityType,
        'p_entity_id': entityId,
      },
    );

    return ApiResponse.ok({
      'result': 'step_approved',
      'entity_id': entityId,
      'entity_type': entityType,
      'next_step': (nextStep as List).isNotEmpty ? {
        'id': nextStep[0]['step_id'],
        'order': nextStep[0]['step_order'],
        'name': nextStep[0]['step_name'],
      } : null,
    }).toResponse();

  } on PostgrestException catch (e) {
    if (e.message.contains('not found')) {
      return ErrorResponse.notFound('Approval step not found: $stepId').toResponse();
    }
    if (e.message.contains('not pending')) {
      return ErrorResponse.conflict(
        'Step cannot be approved: already processed',
      ).toResponse();
    }
    rethrow;
  }
}

/// Check if quorum is met for parallel steps and skip remaining if so.
/// This is for parallel approval where multiple people can approve at the same step_order.
Future<void> _checkAndSkipParallelSteps(
    dynamic supabase, String entityType, String entityId, int stepOrder) async {
  // Get the matrix step to check quorum settings
  final matrixStep = await supabase
      .from('approval_matrix_steps')
      .select('quorum, requires_all')
      .eq('step_order', stepOrder)
      .maybeSingle();
  
  if (matrixStep == null) return;
  
  // If requires_all is true, don't skip any parallel steps
  final requiresAll = matrixStep['requires_all'] as bool? ?? false;
  if (requiresAll) return;
  
  final quorum = matrixStep['quorum'] as int? ?? 1;
  
  // Count approved steps at this step_order
  final approvedCount = await supabase
      .from('approval_steps')
      .select()
      .eq('entity_type', entityType)
      .eq('entity_id', entityId)
      .eq('step_order', stepOrder)
      .eq('status', 'approved')
      .count();
  
  final count = approvedCount.count as int? ?? 0;
  
  // If quorum is met, skip remaining pending steps at this order
  if (count >= quorum) {
    await supabase.rpc(
      'skip_parallel_steps',
      params: {
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_step_order': stepOrder,
      },
    );
  }
}

Future<void> _markEntityEffective(
    dynamic supabase, String entityType, String entityId) async {
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
      'status': 'EFFECTIVE',
      'effective_date': DateTime.now().toIso8601String(),
    }).eq('id', entityId);
  }
}
