import 'package:relic/relic.dart';

import 'auth/routes.dart';
import 'employees/routes.dart';
import 'roles/routes.dart';

void mountAccessRoutes(RelicApp app) {
  mountAuthRoutes(app);
  mountEmployeeRoutes(app);
  mountRoleRoutes(app);
}
