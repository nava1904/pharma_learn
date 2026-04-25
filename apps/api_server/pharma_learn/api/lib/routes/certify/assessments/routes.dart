import 'package:relic/relic.dart';

import 'assessments_handler.dart';

/// Mounts /v1/certify/assessments routes
void mountAssessmentsRoutes(RelicApp app) {
  // Assessment flow
  app.post('/v1/certify/assessments/start', assessmentStartHandler);
  app.post('/v1/certify/assessments/:id/answer', assessmentAnswerHandler);
  app.post('/v1/certify/assessments/:id/submit', assessmentSubmitHandler);
  app.get('/v1/certify/assessments/:id', assessmentGetHandler);
  app.get('/v1/certify/assessments/history', assessmentHistoryHandler);
}
