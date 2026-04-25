import 'package:relic/relic.dart';

import 'certificates_handler.dart';

/// Mounts /v1/certify/certificates routes
void mountCertificatesRoutes(RelicApp app) {
  // Employee's certificates
  app.get('/v1/certify/certificates', certificatesListHandler);
  app.get('/v1/certify/certificates/:id', certificateGetHandler);
  app.get('/v1/certify/certificates/:id/download', certificateDownloadHandler);
  
  // Two-person revocation workflow
  app.post('/v1/certify/certificates/:id/revoke/initiate', certificateRevokeInitiateHandler);
  app.post('/v1/certify/certificates/:id/revoke/confirm', certificateRevokeConfirmHandler);
  app.post('/v1/certify/certificates/:id/revoke/cancel', certificateRevokeCancelHandler);
  
  // Public verification
  app.get('/v1/certify/certificates/verify/:certificateNumber', certificateVerifyHandler);
}
