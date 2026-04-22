import 'package:relic/relic.dart';

import 'inspection_handler.dart';

/// Mounts /v1/certify/inspection routes
void mountInspectionRoutes(RelicApp app) {
  app.get('/v1/certify/inspection/dashboard', inspectionDashboardHandler);
  app.get('/v1/certify/inspection/employee-dossier/:id', inspectionEmployeeDossierHandler);
  app.get('/v1/certify/inspection/audit-export', inspectionAuditExportHandler);
  app.get('/v1/certify/inspection/gaps', inspectionGapsHandler);
}
