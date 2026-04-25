// GET /health — lifecycle monitor liveness
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

Future<Response> healthHandler(Request req) async {
  // Check events_outbox lag
  int outboxLag = 0;
  try {
    final supabase = SupabaseService.client;
    final result = await supabase
        .from('events_outbox')
        .select('id')
        .isFilter('processed_at', null)
        .eq('is_dead_letter', false)
        .count();
    outboxLag = result.count ?? 0;
  } catch (_) {}

  return ApiResponse.ok({
    'status': 'ok',
    'server': 'lifecycle_monitor',
    'timestamp': DateTime.now().toIso8601String(),
    'events_outbox_lag': outboxLag,
  }).toResponse();
}
