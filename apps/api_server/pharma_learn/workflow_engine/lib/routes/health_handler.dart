// GET /health — workflow engine liveness
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

Future<Response> healthHandler(Request req) async {
  // Check workflow queue depth (pending approval steps)
  int queueDepth = 0;
  try {
    final supabase = SupabaseService.client;
    final result = await supabase
        .from('approval_steps')
        .select('id')
        .eq('status', 'PENDING')
        .count();
    queueDepth = result.count ?? 0;
  } catch (_) {}

  // Check pending workflow events in outbox
  int pendingWorkflowEvents = 0;
  try {
    final supabase = SupabaseService.client;
    final workflowEventTypes = [
      'document.submitted',
      'course.submitted',
      'gtp.submitted',
      'question_paper.submitted',
      'curriculum.published',
    ];
    final result = await supabase
        .from('events_outbox')
        .select('id')
        .isFilter('processed_at', null)
        .eq('is_dead_letter', false)
        .inFilter('event_type', workflowEventTypes)
        .count();
    pendingWorkflowEvents = result.count ?? 0;
  } catch (_) {}

  return ApiResponse.ok({
    'status': 'ok',
    'server': 'workflow_engine',
    'timestamp': DateTime.now().toIso8601String(),
    'workflow_queue_depth': queueDepth,
    'pending_workflow_events': pendingWorkflowEvents,
  }).toResponse();
}
