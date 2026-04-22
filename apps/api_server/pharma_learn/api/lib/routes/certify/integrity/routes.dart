import 'package:relic/relic.dart';

import 'integrity_handler.dart';

/// Mounts /v1/certify/integrity/* routes.
/// Implements 21 CFR §11.10(c) - record protection.
void mountIntegrityRoutes(RelicApp app) {
  // Hash chain verification
  app.post('/v1/certify/integrity/verify', integrityVerifyHandler);
  app.get('/v1/certify/integrity/status', integrityStatusHandler);
}
