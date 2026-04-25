import 'package:relic/relic.dart';

import 'documents/routes.dart';
import 'courses/routes.dart';
import 'gtps/routes.dart';

void mountCreateRoutes(RelicApp app) {
  mountDocumentRoutes(app);
  mountCourseRoutes(app);
  mountGtpRoutes(app);
  // S3 remaining domains (question_banks, config, etc.) — mounted in Sprint 3 continuation
}
