import 'package:supabase/supabase.dart';
import 'package:logger/logger.dart';

// ---------------------------------------------------------------------------
// PG Listener Service
// ---------------------------------------------------------------------------
// Polls events_outbox for NON-WORKFLOW events and dispatches them.
// Workflow events (*.submitted) are handled by workflow_engine's listener.
// ---------------------------------------------------------------------------

/// Event types handled by workflow_engine (excluded here)
const _workflowEventTypes = [
  'document.submitted',
  'course.submitted',
  'gtp.submitted',
  'question_paper.submitted',
  'curriculum.published',
  'trainer.submitted',
  'schedule.submitted',
];

class PgListenerService {
  final SupabaseClient _supabase;
  final Logger _logger = Logger();
  final Future<void> Function(Map<String, dynamic> event) _onEvent;
  bool _running = false;

  PgListenerService(this._supabase,
      {required Future<void> Function(Map<String, dynamic>) onEvent})
      : _onEvent = onEvent;

  Future<void> start() async {
    _running = true;
    _logger.i('PgListenerService: starting event listener (excluding workflow events)');
    _startPolling();
  }

  void stop() {
    _running = false;
  }

  void _startPolling() async {
    while (_running) {
      try {
        await _pollEvents();
      } catch (e) {
        _logger.e('PgListenerService polling error: $e');
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> _pollEvents() async {
    // Fetch unprocessed events EXCLUDING workflow events (handled by workflow_engine)
    final events = await _supabase
        .from('events_outbox')
        .select()
        .isFilter('processed_at', null)
        .eq('is_dead_letter', false)
        .not('event_type', 'in', '(${_workflowEventTypes.join(",")})')
        .order('created_at')
        .limit(50);

    for (final event in events as List) {
      try {
        await _onEvent(Map<String, dynamic>.from(event as Map));
        await _supabase
            .rpc('mark_event_processed', params: {'p_event_id': event['id']});
      } catch (e) {
        _logger.e('Error processing event ${event['id']}: $e');
        await _supabase.rpc('schedule_event_retry', params: {
          'p_event_id': event['id'],
          'p_error': e.toString(),
        });
      }
    }
  }
}
