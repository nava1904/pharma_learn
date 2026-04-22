import 'package:relic/relic.dart';

import 'auth/routes.dart';
import 'biometric/routes.dart';
import 'consent/routes.dart';
import 'delegations/routes.dart';
import 'departments/routes.dart';
import 'employees/routes.dart';
import 'global_profiles/routes.dart';
import 'groups/routes.dart';
import 'job_responsibilities/routes.dart';
import 'mail_settings/routes.dart';
import 'notifications/routes.dart';
import 'roles/routes.dart';
import 'sso/routes.dart';
import 'subgroups/routes.dart';

void mountAccessRoutes(RelicApp app) {
  mountAuthRoutes(app);
  mountBiometricRoutes(app);
  mountConsentRoutes(app);
  mountDelegationRoutes(app);
  mountDepartmentRoutes(app);
  mountEmployeeRoutes(app);
  mountGlobalProfileRoutes(app);
  mountGroupRoutes(app);
  mountJobResponsibilityRoutes(app);
  mountMailSettingsRoutes(app);
  mountNotificationRoutes(app);
  mountRoleRoutes(app);
  mountSsoRoutes(app);
  mountSubgroupRoutes(app);
}
