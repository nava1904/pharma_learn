import 'package:relic/relic.dart';

import 'approvals/routes.dart';
import 'audit/routes.dart';
import 'notifications/routes.dart';
import 'quality/routes.dart';
import 'standard_reasons/routes.dart';
import 'admin/routes.dart';

void mountWorkflowRoutes(RelicApp app) {
  mountApprovalRoutes(app);
  mountAuditRoutes(app);
  mountWorkflowNotificationRoutes(app);
  mountQualityRoutes(app);
  mountStandardReasonsRoutes(app);
  mountAdminRoutes(app);
}
