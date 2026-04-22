import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /jobs/events
///
/// Processes unprocessed events from events_outbox and fans them out to
/// appropriate consumers (workflow_engine, notification_service, etc.).
/// 
/// 21 CFR §11.10(a) - Ensures reliable event delivery with at-least-once semantics.
/// 
/// Processing flow:
/// 1. Fetch unprocessed events ordered by created_at (FIFO)
/// 2. For each event, determine subscribers based on event_type
/// 3. Deliver to each subscriber with retry logic
/// 4. Mark as processed on success, increment retry_count on failure
/// 5. Dead-letter events after max retries (5)
Future<Response> eventsFanoutHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final startTime = DateTime.now();
  
  const batchSize = 100;
  const maxRetries = 5;
  
  // Subscriber configuration - event_type prefix -> endpoint
  const subscribers = <String, List<String>>{
    'document.': ['http://localhost:8085/internal/workflow/advance-step'],
    'course.': ['http://localhost:8085/internal/workflow/advance-step'],
    'training_plan.': ['http://localhost:8085/internal/workflow/advance-step'],
    'schedule.': ['http://localhost:8085/internal/workflow/advance-step'],
    'trainer.': ['http://localhost:8085/internal/workflow/advance-step'],
    'curriculum.': ['http://localhost:8085/internal/workflow/advance-step'],
    'question_paper.': ['http://localhost:8085/internal/workflow/advance-step'],
    'certificate.': ['http://localhost:8087/internal/notify'],  // notification service
    'training.': ['http://localhost:8087/internal/notify'],
    'employee.': ['http://localhost:8087/internal/notify'],
  };
  
  // Fetch unprocessed events
  final events = await supabase
      .from('events_outbox')
      .select('*')
      .eq('processed', false)
      .lt('retry_count', maxRetries)
      .order('created_at')
      .limit(batchSize);
  
  var processed = 0;
  var failed = 0;
  var deadLettered = 0;
  final errors = <Map<String, dynamic>>[];
  
  for (final event in events) {
    final eventId = event['id'] as String;
    final eventType = event['event_type'] as String;
    final retryCount = event['retry_count'] as int? ?? 0;
    
    try {
      // Find matching subscribers based on event_type prefix
      final matchingEndpoints = <String>[];
      for (final entry in subscribers.entries) {
        if (eventType.startsWith(entry.key)) {
          matchingEndpoints.addAll(entry.value);
        }
      }
      
      // If no subscribers, mark as processed (event is valid but no handlers)
      if (matchingEndpoints.isEmpty) {
        await _markProcessed(supabase, eventId);
        processed++;
        continue;
      }
      
      // Deliver to each subscriber
      var allDelivered = true;
      for (final endpoint in matchingEndpoints) {
        final delivered = await _deliverEvent(event, endpoint);
        if (!delivered) {
          allDelivered = false;
          break;
        }
      }
      
      if (allDelivered) {
        await _markProcessed(supabase, eventId);
        processed++;
      } else {
        // Increment retry count
        final newRetryCount = retryCount + 1;
        if (newRetryCount >= maxRetries) {
          await _deadLetter(supabase, eventId, 'Max retries exceeded');
          deadLettered++;
        } else {
          await supabase.from('events_outbox').update({
            'retry_count': newRetryCount,
            'last_retry_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', eventId);
          failed++;
        }
      }
    } catch (e) {
      errors.add({
        'event_id': eventId,
        'event_type': eventType,
        'error': e.toString(),
      });
      
      // Increment retry count on error
      final newRetryCount = retryCount + 1;
      if (newRetryCount >= maxRetries) {
        await _deadLetter(supabase, eventId, e.toString());
        deadLettered++;
      } else {
        await supabase.from('events_outbox').update({
          'retry_count': newRetryCount,
          'last_error': e.toString(),
          'last_retry_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', eventId);
        failed++;
      }
    }
  }
  
  final duration = DateTime.now().difference(startTime);
  
  // Log job execution
  await supabase.from('job_executions').insert({
    'job_name': 'events_fanout',
    'started_at': startTime.toUtc().toIso8601String(),
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': errors.isEmpty ? 'success' : 'partial',
    'result': jsonEncode({
      'fetched': events.length,
      'processed': processed,
      'failed': failed,
      'dead_lettered': deadLettered,
      'errors': errors,
    }),
  });
  
  return ApiResponse.ok({
    'job': 'events_fanout',
    'fetched': events.length,
    'processed': processed,
    'failed': failed,
    'dead_lettered': deadLettered,
    'duration_ms': duration.inMilliseconds,
  }).toResponse();
}

/// Delivers an event to a subscriber endpoint.
Future<bool> _deliverEvent(Map<String, dynamic> event, String endpoint) async {
  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Event-Id': event['id'] as String,
        'X-Event-Type': event['event_type'] as String,
      },
      body: jsonEncode({
        'event_id': event['id'],
        'event_type': event['event_type'],
        'aggregate_type': event['aggregate_type'],
        'aggregate_id': event['aggregate_id'],
        'entity_type': event['aggregate_type'],
        'entity_id': event['aggregate_id'],
        'org_id': event['organization_id'],
        'payload': event['payload'] is String 
            ? jsonDecode(event['payload'] as String) 
            : event['payload'],
        'created_at': event['created_at'],
      }),
    ).timeout(const Duration(seconds: 30));
    
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (e) {
    return false;
  }
}

/// Marks an event as processed.
Future<void> _markProcessed(dynamic supabase, String eventId) async {
  await supabase.from('events_outbox').update({
    'processed': true,
    'processed_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', eventId);
}

/// Moves an event to dead letter queue after max retries.
Future<void> _deadLetter(dynamic supabase, String eventId, String reason) async {
  // Get the event
  final event = await supabase
      .from('events_outbox')
      .select('*')
      .eq('id', eventId)
      .single();
  
  // Insert into dead letter queue
  await supabase.from('events_dead_letter').insert({
    'original_event_id': eventId,
    'event_type': event['event_type'],
    'aggregate_type': event['aggregate_type'],
    'aggregate_id': event['aggregate_id'],
    'organization_id': event['organization_id'],
    'payload': event['payload'],
    'failure_reason': reason,
    'retry_count': event['retry_count'],
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });
  
  // Mark original as processed (moved to DLQ)
  await supabase.from('events_outbox').update({
    'processed': true,
    'processed_at': DateTime.now().toUtc().toIso8601String(),
    'dead_lettered': true,
  }).eq('id', eventId);
}
