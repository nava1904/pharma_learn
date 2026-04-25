import 'package:relic/relic.dart';

import 'health/routes.dart';
import 'access/routes.dart';
import 'certify/routes.dart';
import 'create/routes.dart';
// import 'train/routes.dart';    // S4
// import 'workflow/routes.dart'; // S6

void mountAllRoutes(RelicApp app) {
  mountHealthRoutes(app);
  mountAccessRoutes(app);   // S2 ✅
  mountCertifyRoutes(app);  // S2 (reauth only) ✅
  mountCreateRoutes(app);   // S3 ✅
  // mountTrainRoutes(app);
  // mountWorkflowRoutes(app);
}
