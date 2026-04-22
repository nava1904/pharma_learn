import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'ojt_handler.dart';

/// Mounts /v1/train/ojt routes
void mountOjtRoutes(RelicApp app) {
  // Employee's OJT assignments
  app.get('/v1/train/ojt', ojtListHandler);
  app.get('/v1/train/ojt/:id', ojtGetHandler);
  app.get('/v1/train/ojt/:id/tasks', ojtTasksListHandler);
  
  // Evaluator task sign-off (with e-signature for G2 compliance)
  app.post('/v1/train/ojt/:id/tasks/:taskId/complete', withEsig(ojtTaskCompleteHandler));
  
  // Final OJT sign-off (with e-signature)
  app.post('/v1/train/ojt/:id/sign-off', withEsig(ojtSignOffHandler));
  
  // Complete OJT (trainee acknowledges completion)
  app.post('/v1/train/ojt/:id/complete', withEsig(ojtCompleteHandler));
}
