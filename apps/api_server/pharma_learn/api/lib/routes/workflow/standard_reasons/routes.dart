import 'package:relic/relic.dart';

import 'standard_reason_handler.dart';

/// Mounts /v1/standard-reasons/* routes.
void mountStandardReasonsRoutes(RelicApp app) {
  app.get('/v1/standard-reasons', standardReasonsListHandler);
  app.post('/v1/standard-reasons', standardReasonCreateHandler);
  app.get('/v1/standard-reasons/:id', standardReasonGetHandler);
  app.patch('/v1/standard-reasons/:id', standardReasonUpdateHandler);
}
