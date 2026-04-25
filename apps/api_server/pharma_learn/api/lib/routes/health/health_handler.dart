import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /health — liveness probe.
///
/// Returns a JSON body with status, timestamp, version, and server name.
/// Always 200 OK while the process is alive.
Future<Response> healthHandler(Request req) async {
  return ApiResponse.ok({
    'status': 'ok',
    'timestamp': DateTime.now().toIso8601String(),
    'version': '1.0.0',
    'server': 'pharma_learn_api',
  }).toResponse();
}
