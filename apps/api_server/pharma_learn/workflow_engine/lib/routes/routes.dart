import 'package:relic/relic.dart';

import 'health_handler.dart';
import 'internal/routes.dart';

void mountAllRoutes(RelicApp app) {
  app.get('/health', healthHandler);
  mountInternalRoutes(app);
}
