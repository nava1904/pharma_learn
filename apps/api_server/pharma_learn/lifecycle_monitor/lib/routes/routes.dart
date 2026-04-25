import 'package:relic/relic.dart';
import 'health_handler.dart';
import 'jobs/routes.dart';

void mountAllRoutes(RelicApp app) {
  app.get('/health', healthHandler);
  mountJobRoutes(app);
}
