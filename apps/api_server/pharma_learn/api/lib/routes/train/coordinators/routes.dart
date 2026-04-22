import 'package:relic/relic.dart';

import 'coordinators_handler.dart';

/// Mount coordinator routes on the app.
void mountCoordinatorRoutes(RelicApp app) {
  // List coordinators - GET /v1/train/coordinators
  app.get('/v1/train/coordinators', coordinatorsListHandler);

  // Create coordinator - POST /v1/train/coordinators
  app.post('/v1/train/coordinators', coordinatorsCreateHandler);

  // Get coordinator - GET /v1/train/coordinators/:id
  app.get('/v1/train/coordinators/:id', coordinatorDetailHandler);

  // Update coordinator - PATCH /v1/train/coordinators/:id
  app.patch('/v1/train/coordinators/:id', coordinatorUpdateHandler);

  // Deactivate coordinator - POST /v1/train/coordinators/:id/deactivate
  app.post('/v1/train/coordinators/:id/deactivate', coordinatorDeactivateHandler);
}
