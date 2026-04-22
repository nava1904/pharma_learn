import 'package:relic/relic.dart';

import 'esignatures_handler.dart';

/// Mounts /v1/certify/esignatures routes
void mountEsignaturesRoutes(RelicApp app) {
  // List e-signatures (admin)
  app.get('/v1/certify/esignatures', esignaturesListHandler);
  
  // Get specific e-signature
  app.get('/v1/certify/esignatures/:id', esignatureGetHandler);
  
  // Create e-signature (after re-auth)
  app.post('/v1/certify/esignatures', esignatureCreateHandler);
  
  // Verify e-signature integrity
  app.post('/v1/certify/esignatures/:id/verify', esignatureVerifyHandler);
  
  // Get e-signature history for an entity
  app.get('/v1/certify/esignatures/history/:contextType/:contextId', esignatureHistoryHandler);
}
