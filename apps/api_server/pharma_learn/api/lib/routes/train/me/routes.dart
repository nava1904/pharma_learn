import 'package:relic/relic.dart';

import 'me_dashboard_handler.dart';
import 'me_training_history_handler.dart';
import 'me_obligations_handler.dart';
import 'me_certificates_handler.dart';

void mountMeRoutes(RelicApp app) {
  app.get('/v1/train/me/dashboard', meDashboardHandler);
  app.get('/v1/train/me/training-history', meTrainingHistoryHandler);
  app.get('/v1/train/me/obligations', meObligationsHandler);
  app.get('/v1/train/me/certificates', meCertificatesHandler);
}
