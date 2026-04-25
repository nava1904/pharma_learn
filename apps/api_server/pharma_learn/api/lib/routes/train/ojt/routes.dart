import 'package:relic/relic.dart';

import 'ojt_handler.dart';

/// Mounts /v1/train/ojt routes
void mountOjtRoutes(RelicApp app) {
  // Employee's OJT assignments
  app.get('/v1/train/ojt', ojtListHandler);
  app.get('/v1/train/ojt/:id', ojtGetHandler);
  app.get('/v1/train/ojt/:id/tasks', ojtTasksListHandler);
  
  // Evaluator task sign-off
  app.post('/v1/train/ojt/:id/tasks/:taskId/complete', ojtTaskCompleteHandler);
}
