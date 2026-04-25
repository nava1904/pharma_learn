import 'package:relic/relic.dart';

import 'obligations_handler.dart';

/// Mounts /v1/train/obligations routes
void mountObligationsRoutes(RelicApp app) {
  // Employee's training obligations
  app.get('/v1/train/obligations', obligationsListHandler);
  app.get('/v1/train/obligations/:id', obligationGetHandler);
  app.post('/v1/train/obligations/:id/waive', obligationWaiveHandler);
}
