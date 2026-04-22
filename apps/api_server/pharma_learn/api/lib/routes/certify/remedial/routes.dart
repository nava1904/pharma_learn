import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'remedial_handler.dart';

/// Mounts /v1/certify/remedial routes
void mountRemedialRoutes(RelicApp app) {
  // My remedial training
  app.get('/v1/certify/remedial/my', remedialMyHandler);
  
  // Admin list
  app.get('/v1/certify/remedial', remedialListHandler);
  
  // Create remedial training
  app.post('/v1/certify/remedial', remedialCreateHandler);
  
  // Single remedial
  app.get('/v1/certify/remedial/:id', remedialGetHandler);
  
  // Workflow
  app.post('/v1/certify/remedial/:id/start', remedialStartHandler);
  app.post('/v1/certify/remedial/:id/complete', withEsig(remedialCompleteHandler));
  
  // Cancel (admin)
  app.delete('/v1/certify/remedial/:id', remedialCancelHandler);
}
