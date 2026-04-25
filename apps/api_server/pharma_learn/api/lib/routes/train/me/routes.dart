import 'package:relic/relic.dart';

import 'me_dashboard_handler.dart';

void mountMeRoutes(RelicApp app) {
  app.get('/v1/me/dashboard', meDashboardHandler);
  // Additional /v1/me/* routes can be added here:
  // app.get('/v1/me/obligations', meObligationsHandler);
  // app.get('/v1/me/certificates', meCertificatesHandler);
  // app.get('/v1/me/history', meTrainingHistoryHandler);
}
