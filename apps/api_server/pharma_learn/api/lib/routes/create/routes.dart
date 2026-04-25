import 'package:relic/relic.dart';

import 'categories/routes.dart';
import 'config/routes.dart';
import 'courses/routes.dart';
import 'curricula/routes.dart';
import 'documents/routes.dart';
import 'gtps/routes.dart';
import 'periodic_reviews/routes.dart';
import 'question_banks/routes.dart';
import 'question_papers/routes.dart';
import 'scorm/routes.dart';
import 'trainers/routes.dart';
import 'venues/routes.dart';

void mountCreateRoutes(RelicApp app) {
  mountCategoryRoutes(app);
  mountConfigRoutes(app);
  mountCourseRoutes(app);
  mountCurriculaRoutes(app);
  mountDocumentRoutes(app);
  mountGtpRoutes(app);
  mountPeriodicReviewRoutes(app);
  mountQuestionBankRoutes(app);
  mountQuestionPaperRoutes(app);
  mountScormRoutes(app);
  mountTrainerRoutes(app);
  mountVenueRoutes(app);
}

