import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:supabase/supabase.dart';

// ---------------------------------------------------------------------------
// Workflow Listener Service
// ---------------------------------------------------------------------------
// Polls events_outbox every 5 s for workflow-triggering events
// (*.submitted, *.published) and dispatches them to the internal
// /internal/workflow/advance-step endpoint.
// ---------------------------------------------------------------------------

const _workflowEventTypes = [
  'document.submitted',
  'course.submitted',
  'gtp.submitted',
  'question_paper.submitted',
  'curriculum.published',
  'trainer.submitted',
  'schedule.submitted',
];

class WorkflowListenerService {
  final SupabaseClient _supabase;
  final String _internalBaseUrl;
  final Logger _logger = Logger();
  bool _running = false;

  WorkflowListenerService(
    this._supabase, {
    String? internalBaseUrl,
  }) : _internalBaseUrl = internalBaseUrl ?? 'http://localhost:8085';

  /// Start polling in the background.
  Future<void> start() async {
    _running = true;
    _logger.i('WorkflowListenerService: starting poll loop');
    _poll();
  }

  void stop() {
    _running = false;
    _logger.i('WorkflowListenerService: stopped');
  }

  void _poll() async {
    while (_running) {
      try {
        await _processEvents();
      } catch (e) {
        _logger.e('WorkflowListenerService poll error: $e');
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> _processEvents() async {
    final events = await _supabase
        .from('events_outbox')
        .select()
        .isFilter('processed_at', null)
        .eq('is_dead_letter', false)
        .inFilter('event_type', _workflowEventTypes)
        .isFilter('processing_started_at', null)
        .order('created_at')
        .limit(20);

    for (final event in events as List) {
      final eventId = event['id'] as String;

      // Optimistic lock: mark processing started
      final updated = await _supabase
          .from('events_outbox')
          .update({
            'processing_started_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', eventId)
          .isFilter('processing_started_at', null)
          .select();

      if ((updated as List).isEmpty) continue; // Another instance picked it up

      try {
        await _dispatchToWorkflowEngine(event);
        await _supabase.rpc(
          'mark_event_processed',
          params: {'p_event_id': eventId},
        );
      } catch (e) {
        _logger.e('WorkflowListenerService failed to process $eventId: $e');
        await _supabase.rpc(
          'schedule_event_retry',
          params: {'p_event_id': eventId, 'p_error': e.toString()},
        );
      }
    }
  }

  Future<void> _dispatchToWorkflowEngine(Map<String, dynamic> event) async {
    final response = await http.post(
      Uri.parse('$_internalBaseUrl/internal/workflow/advance-step'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'entity_type': event['aggregate_type'],
        'entity_id': event['aggregate_id'],
        'event_type': event['event_type'],
        'payload': event['payload'],
        'org_id': event['organization_id'],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'advance-step returned ${response.statusCode}: ${response.body}',
      );
    }
  }
}
