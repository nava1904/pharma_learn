import 'package:relic/relic.dart';

import 'health/routes.dart';
import 'access/routes.dart';
import 'certify/routes.dart';
import 'create/routes.dart';
import 'reports/routes.dart';
import 'train/routes.dart';
import 'workflow/routes.dart';

void mountAllRoutes(RelicApp app) {
  mountHealthRoutes(app);
  mountAccessRoutes(app);    // S2 ✅
  mountCertifyRoutes(app);   // S5 ✅
  mountCreateRoutes(app);    // S3 ✅
  mountReportsRoutes(app);   // S6 ✅
  mountWorkflowRoutes(app);  // S7 ✅
  mountTrainRoutes(app);     // S4 ✅
}
