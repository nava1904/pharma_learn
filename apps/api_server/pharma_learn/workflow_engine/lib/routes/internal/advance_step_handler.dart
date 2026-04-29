// POST /internal/workflow/advance-step
// Body: {entity_type: string, entity_id: UUID, event_type: string, payload: Map, org_id: UUID}
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// Handles workflow advancement triggered by events_outbox.
/// 
/// Flow:
/// 1. On first call (*.submitted event), seeds approval_steps from matrix
/// 2. Returns current pending step info for notification
/// 3. If no steps (no matrix), auto-marks entity effective
/// 4. If all steps complete, marks entity effective
Future<Response> advanceStepHandler(Request req) async {
  final body = await readJson(req);
  final entityType = body['entity_type'] as String;
  final entityId = body['entity_id'] as String;
  final orgId = body['org_id'] as String?;
  final payload = body['payload'] as Map<String, dynamic>?;
  final plantId = payload?['plant_id'] as String?;
  
  final supabase = SupabaseService.client;

  // 1. Seed approval steps (idempotent - returns existing if already seeded)
  final seedResult = await supabase.rpc(
    'seed_approval_steps',
    params: {
      'p_entity_type': entityType,
      'p_entity_id': entityId,
      'p_organization_id': orgId,
      'p_plant_id': plantId,
    },
  );
  
  final stepsCreated = seedResult[0]['steps_created'] as int? ?? 0;
  final matrixId = seedResult[0]['matrix_id'] as String?;
  final isSerial = seedResult[0]['is_serial'] as bool? ?? true;

  // 2. If no matrix (stepsCreated = 0 and no matrixId), auto-approve
  if (stepsCreated == 0 && matrixId == null) {
    await _markEntityEffective(supabase, entityType, entityId);
    
    // Publish completion event
    await EventPublisher.publish(
      supabase,
      eventType: '$entityType.approved',
      aggregateType: entityType,
      aggregateId: entityId,
      orgId: orgId!,
      payload: {'auto_approved': true, 'reason': 'no_approval_matrix'},
    );
    
    return ApiResponse.ok({
      'result': 'auto_approved',
      'entity_id': entityId,
      'reason': 'no_approval_matrix',
    }).toResponse();
  }

  // 3. Get next pending step
  final nextStep = await supabase.rpc(
    'get_next_pending_step',
    params: {
      'p_entity_type': entityType,
      'p_entity_id': entityId,
    },
  );

  if ((nextStep as List).isEmpty) {
    // All steps complete — mark effective
    await _markEntityEffective(supabase, entityType, entityId);
    
    // Publish completion event
    await EventPublisher.publish(
      supabase,
      eventType: '$entityType.approved',
      aggregateType: entityType,
      aggregateId: entityId,
      orgId: orgId!,
      payload: {'all_steps_approved': true},
    );
    
    return ApiResponse.ok({
      'result': 'completed',
      'entity_id': entityId,
    }).toResponse();
  }

  // 4. Return pending step info for notification
  final step = nextStep[0];
  
  // Publish pending event for notification service
  await EventPublisher.publish(
    supabase,
    eventType: 'workflow.step_pending',
    aggregateType: entityType,
    aggregateId: entityId,
    orgId: orgId!,
    payload: {
      'step_id': step['step_id'],
      'step_name': step['step_name'],
      'required_role': step['required_role'],
      'min_approval_tier': step['min_approval_tier'],
      'is_serial': isSerial,
    },
  );

  return ApiResponse.ok({
    'result': 'pending',
    'entity_id': entityId,
    'matrix_id': matrixId,
    'is_serial': isSerial,
    'current_step': {
      'id': step['step_id'],
      'order': step['step_order'],
      'name': step['step_name'],
      'required_role': step['required_role'],
      'min_tier': step['min_approval_tier'],
    },
  }).toResponse();
}

Future<void> _markEntityEffective(
    dynamic supabase, String entityType, String entityId) async {
  // Update entity status based on type
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
