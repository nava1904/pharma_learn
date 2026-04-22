import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/admin/events/status
/// 
/// Returns the status of the event processing system.
/// Admin endpoint for monitoring event outbox health.
/// 
/// Returns:
/// - Total pending events
/// - Events by status (pending, processed, dead_lettered)
/// - Events by type breakdown
/// - Oldest pending event age
/// - Recent errors
/// - Throughput metrics
Future<Response> adminEventsStatusHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Admin permission required
  if (!auth.hasPermission('admin.events.view')) {
    throw PermissionDeniedException('Admin access required');
  }

  final now = DateTime.now().toUtc();

  // Get pending events count
  final pendingResult = await supabase
      .from('events_outbox')
      .select()
      .eq('processed', false)
      .count();
  final pendingCount = pendingResult.count;

  // Get processed count (last 24 hours)
  final yesterday = now.subtract(const Duration(hours: 24));
  final processedResult = await supabase
      .from('events_outbox')
      .select()
      .eq('processed', true)
      .gte('processed_at', yesterday.toIso8601String())
      .count();
  final processedLast24h = processedResult.count;

  // Get dead lettered count
  final deadLetteredResult = await supabase
      .from('events_dead_letter')
      .select()
      .count();
  final deadLetteredCount = deadLetteredResult.count;

  // Get events by type (pending only)
  final eventsByType = await supabase.rpc(
    'count_events_by_type',
    params: {'p_processed': false},
  ).catchError((_) => <Map<String, dynamic>>[]);

  // Get oldest pending event
  final oldestPending = await supabase
      .from('events_outbox')
      .select('id, event_type, created_at, retry_count')
      .eq('processed', false)
      .order('created_at')
      .limit(1)
      .maybeSingle();

  String? oldestAge;
  if (oldestPending != null) {
    final createdAt = DateTime.parse(oldestPending['created_at'] as String);
    final age = now.difference(createdAt);
    oldestAge = _formatDuration(age);
  }

  // Get recent errors (last hour)
  final hourAgo = now.subtract(const Duration(hours: 1));
  final recentErrors = await supabase
      .from('events_outbox')
      .select('id, event_type, last_error, retry_count, created_at')
      .eq('processed', false)
      .gt('retry_count', 0)
      .gte('last_retry_at', hourAgo.toIso8601String())
      .order('last_retry_at', ascending: false)
      .limit(10);

  // Get job execution history (last 10 runs)
  final recentJobs = await supabase
      .from('job_executions')
      .select('job_name, started_at, completed_at, duration_ms, status, result')
      .eq('job_name', 'events_fanout')
      .order('started_at', ascending: false)
      .limit(10);

  // Calculate throughput
  double? throughputPerMinute;
  if ((recentJobs as List).isNotEmpty) {
    var totalProcessed = 0;
    var totalDurationMs = 0;
    for (final job in recentJobs) {
      final result = job['result'];
      if (result != null) {
        final parsed = result is String ? jsonDecode(result) : result;
        totalProcessed += (parsed['processed'] as int?) ?? 0;
      }
      totalDurationMs += (job['duration_ms'] as int?) ?? 0;
    }
    if (totalDurationMs > 0) {
      throughputPerMinute = (totalProcessed / totalDurationMs) * 60000;
    }
  }

  // Health status determination
  String healthStatus;
  if (pendingCount == 0 && deadLetteredCount == 0) {
    healthStatus = 'healthy';
  } else if (pendingCount > 1000 || deadLetteredCount > 100) {
    healthStatus = 'critical';
  } else if (pendingCount > 100 || deadLetteredCount > 10) {
    healthStatus = 'warning';
  } else {
    healthStatus = 'healthy';
  }

  return ApiResponse.ok({
    'status': healthStatus,
    'summary': {
      'pending': pendingCount,
      'processed_last_24h': processedLast24h,
      'dead_lettered': deadLetteredCount,
      'oldest_pending_age': oldestAge,
      'throughput_per_minute': throughputPerMinute?.toStringAsFixed(2),
    },
    'events_by_type': eventsByType,
    'oldest_pending': oldestPending,
    'recent_errors': recentErrors,
    'recent_job_runs': recentJobs,
    'timestamp': now.toIso8601String(),
  }).toResponse();
}

/// GET /v1/admin/events/dead-letter
/// 
/// Lists dead-lettered events for manual review/retry.
Future<Response> adminDeadLetterListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission('admin.events.view')) {
    throw PermissionDeniedException('Admin access required');
  }

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  final offset = (page - 1) * perPage;

  final events = await supabase
      .from('events_dead_letter')
      .select('*')
      .order('created_at', ascending: false)
      .range(offset, offset + perPage - 1);

  return ApiResponse.ok({'dead_letter_events': events}).toResponse();
}

/// POST /v1/admin/events/dead-letter/:id/retry
/// 
/// Moves a dead-lettered event back to outbox for retry.
Future<Response> adminDeadLetterRetryHandler(Request req) async {
  final eventId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (eventId == null) {
    throw ValidationException({'id': 'Event ID is required'});
  }

  if (!auth.hasPermission('admin.events.manage')) {
    throw PermissionDeniedException('Admin access required');
  }

  // Get dead letter event
  final dlEvent = await supabase
      .from('events_dead_letter')
      .select('*')
      .eq('id', eventId)
      .maybeSingle();

  if (dlEvent == null) {
    throw NotFoundException('Dead letter event not found');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Re-insert into outbox
  await supabase.from('events_outbox').insert({
    'event_type': dlEvent['event_type'],
    'aggregate_type': dlEvent['aggregate_type'],
    'aggregate_id': dlEvent['aggregate_id'],
    'organization_id': dlEvent['organization_id'],
    'payload': dlEvent['payload'],
    'processed': false,
    'retry_count': 0,
    'created_at': now,
  });

  // Remove from dead letter
  await supabase.from('events_dead_letter').delete().eq('id', eventId);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'events_dead_letter',
    'entity_id': eventId,
    'action': 'DEAD_LETTER_RETRIED',
    'event_category': 'ADMIN',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'original_event_id': dlEvent['original_event_id'],
      'event_type': dlEvent['event_type'],
    }),
  });

  return ApiResponse.ok({'message': 'Event moved back to outbox for retry'}).toResponse();
}

/// Formats a duration for human readability.
String _formatDuration(Duration duration) {
  if (duration.inDays > 0) {
    return '${duration.inDays}d ${duration.inHours % 24}h';
  } else if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  } else if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  } else {
    return '${duration.inSeconds}s';
  }
}
