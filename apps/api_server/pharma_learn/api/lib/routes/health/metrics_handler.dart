import 'package:relic/relic.dart';

import '../../context/metrics_middleware.dart';

/// GET /metrics
///
/// Prometheus metrics endpoint.
/// Returns metrics in Prometheus text format.
/// 
/// This endpoint is typically called by Prometheus scraper every 15-30 seconds.
/// It should NOT require authentication since Prometheus can't provide JWT tokens.
/// Secure via network policy (only allow scraper IP) or basic auth if needed.
Future<Response> metricsHandler(Request req) async {
  final metricsText = getMetricsExport();
  
  return Response(
    200,
    body: Body.fromString(
      metricsText,
      mimeType: MimeType('text', 'plain'),
    ),
  );
}
