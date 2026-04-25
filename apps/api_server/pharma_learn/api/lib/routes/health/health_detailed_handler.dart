import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /health/detailed — readiness probe.
///
/// Pings the Supabase database with a lightweight count query and measures
/// round-trip latency.  Returns 200 when the database is reachable, 503 when
/// degraded.
Future<Response> healthDetailedHandler(Request req) async {
  final stopwatch = Stopwatch()..start();
  String dbStatus = 'ok';
  int? dbLatencyMs;

  try {
    final supabase = SupabaseService.client;
    await supabase.from('system_settings').select('id').limit(1);
    stopwatch.stop();
    dbLatencyMs = stopwatch.elapsedMilliseconds;
  } catch (e) {
    stopwatch.stop();
    final message = e.toString();
    dbStatus =
        'error: ${message.length > 100 ? message.substring(0, 100) : message}';
    dbLatencyMs = stopwatch.elapsedMilliseconds;
  }

  final isReady = dbStatus == 'ok';
  final responseBody = {
    'status': isReady ? 'ready' : 'degraded',
    'timestamp': DateTime.now().toIso8601String(),
    'checks': {
      'database': {'status': dbStatus, 'latency_ms': dbLatencyMs},
      'api': {'status': 'ok'},
    },
  };

  if (isReady) {
    return ApiResponse.ok(responseBody).toResponse();
  } else {
    return Response(
      503,
      body: Body.fromString(
        jsonEncode({'data': responseBody}),
        mimeType: MimeType.json,
      ),
    );
  }
}
