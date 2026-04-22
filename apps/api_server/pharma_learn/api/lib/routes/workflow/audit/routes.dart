import 'package:relic/relic.dart';

import 'audit_handler.dart';

/// Mounts /v1/audit/* and /v1/workflow/audit/* routes.
/// Implements 21 CFR §11.10(b) and §11.10(e).
void mountAuditRoutes(RelicApp app) {
  // View audit trails (21 CFR §11.10(e))
  app.get('/v1/audit/:entityType/:entityId', auditEntityHandler);
  app.get('/v1/audit/search', auditSearchHandler);
  
  // Export audit trails (21 CFR §11.10(b) - printable format)
  app.get('/v1/workflow/audit/:entityType/:entityId/export', auditExportHandler);
}
