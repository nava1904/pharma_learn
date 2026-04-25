import 'package:relic/relic.dart';

import 'waivers_handler.dart';

/// Mounts /v1/certify/waivers routes
void mountWaiversRoutes(RelicApp app) {
  // Employee's own waivers
  app.get('/v1/certify/waivers/my', myWaiversHandler);
  
  // Admin waiver management
  app.get('/v1/certify/waivers', waiversListHandler);
  app.get('/v1/certify/waivers/:id', waiverGetHandler);
  app.post('/v1/certify/waivers/:id/approve', waiverApproveHandler);
  app.post('/v1/certify/waivers/:id/reject', waiverRejectHandler);
}
