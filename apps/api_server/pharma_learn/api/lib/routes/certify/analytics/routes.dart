import 'package:relic/relic.dart';

import 'course_analytics_handler.dart';
import 'question_stats_handler.dart';

/// Mounts /v1/certify/analytics routes
void mountAnalyticsRoutes(RelicApp app) {
  // Course analytics
  app.get('/v1/certify/analytics/courses', coursesAnalyticsListHandler);
  app.get('/v1/certify/analytics/courses/:id', courseAnalyticsHandler);

  // Question psychometrics
  app.get('/v1/certify/analytics/questions', questionsStatsListHandler);
  app.get('/v1/certify/analytics/questions/:id', questionStatsHandler);
}
