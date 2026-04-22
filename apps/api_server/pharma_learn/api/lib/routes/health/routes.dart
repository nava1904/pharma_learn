import 'package:relic/relic.dart';

import 'health_handler.dart';
import 'health_detailed_handler.dart';
import 'metrics_handler.dart';

void mountHealthRoutes(RelicApp app) {
  app
    ..get('/health', healthHandler)
    ..get('/health/detailed', healthDetailedHandler)
    ..get('/metrics', metricsHandler);
}
