// POST /internal/workflow/advance-step
// Body: {entity_type: string, entity_id: UUID, event_type: string, payload: Map}
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';
import 'dart:convert';

Future<Response> advanceStepHandler(Request req) async {
  final body = await readJson(req);
  final entityType = body['entity_type'] as String;
  final entityId = body['entity_id'] as String;
  final supabase = SupabaseService.client;

  // 1. Load approval matrix for this entity type
  final matrix = await supabase
      .from('approval_matrices')
      .select('*, approval_matrix_steps(*)')
      .eq('entity_type', entityType)
      .eq('is_active', true)
      .maybeSingle();

  if (matrix == null) {
    // No approval matrix — auto-approve
    await _markEntityEffective(supabase, entityType, entityId);
    return ApiResponse.ok(
        {'result': 'auto_approved', 'entity_id': entityId}).toResponse();
  }

  // 2. Find or create current pending approval step
  final currentStep = await supabase
      .from('approval_steps')
      .select()
      .eq('entity_type', entityType)
      .eq('entity_id', entityId)
      .eq('status', 'PENDING')
      .order('step_order')
      .limit(1)
      .maybeSingle();

  if (currentStep == null) {
    // All steps complete — mark effective
    await _markEntityEffective(supabase, entityType, entityId);
    return ApiResponse.ok(
        {'result': 'completed', 'entity_id': entityId}).toResponse();
  }

  // 3. Notify approver
  await supabase.functions.invoke('send-notification', body: {
    'employee_id': currentStep['assigned_to'],
    'template_key': 'approval_required',
    'data': {
      'entity_type': entityType,
      'entity_id': entityId,
      'step_name': currentStep['step_name'],
    },
  });

  return ApiResponse.ok({
    'result': 'pending',
    'entity_id': entityId,
    'current_step': currentStep,
  }).toResponse();
}

Future<void> _markEntityEffective(
    dynamic supabase, String entityType, String entityId) async {
  // Update entity status based on type
  final tableMap = {
    'document': 'documents',
    'course': 'courses',
    'gtp': 'training_plans',
  };
  final table = tableMap[entityType];
  if (table != null) {
    await supabase.from(table).update({
      'status': 'EFFECTIVE',
      'effective_date': DateTime.now().toIso8601String(),
    }).eq('id', entityId);
  }
}
