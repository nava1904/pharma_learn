import 'package:relic/relic.dart';

import 'auth/routes.dart';
import 'biometric/routes.dart';
import 'consent/routes.dart';
import 'delegations/routes.dart';
import 'employees/routes.dart';
import 'groups/routes.dart';
import 'roles/routes.dart';
import 'sso/routes.dart';

void mountAccessRoutes(RelicApp app) {
  mountAuthRoutes(app);
  mountBiometricRoutes(app);
  mountConsentRoutes(app);
  mountDelegationRoutes(app);
  mountEmployeeRoutes(app);
  mountGroupRoutes(app);
  mountRoleRoutes(app);
  mountSsoRoutes(app);
}
