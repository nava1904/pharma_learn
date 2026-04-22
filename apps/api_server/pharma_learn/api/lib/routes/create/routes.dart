import 'package:relic/relic.dart';

import 'categories/routes.dart';
import 'config/routes.dart';
import 'courses/routes.dart';
import 'curricula/routes.dart';
import 'documents/routes.dart';
import 'feedback/routes.dart';
import 'gtps/routes.dart';
import 'periodic_reviews/routes.dart';
import 'question_banks/routes.dart';
import 'question_papers/routes.dart';
import 'question_papers/question_paper_print_handler.dart';
import 'scorm/routes.dart';
import 'subjects/routes.dart';
import 'topics/routes.dart';
import 'trainers/routes.dart';
import 'venues/routes.dart';

void mountCreateRoutes(RelicApp app) {
  mountCategoryRoutes(app);
  mountConfigRoutes(app);
  mountCourseRoutes(app);
  mountCurriculaRoutes(app);
  mountDocumentRoutes(app);
  mountFeedbackRoutes(app);  // GAP-H1: Feedback & Evaluation Templates
  mountGtpRoutes(app);
  mountPeriodicReviewRoutes(app);
  mountQuestionBankRoutes(app);
  mountQuestionPaperRoutes(app);
  mountScormRoutes(app);
  mountSubjectsRoutes(app);  // Phase 3: Subjects master data
  mountTopicsRoutes(app);    // Phase 3: Topics master data
  mountTrainerRoutes(app);
  mountVenueRoutes(app);
  
  // GAP-L4: Question paper print
  app.get('/v1/question-papers/:id/print', questionPaperPrintHandler);
}

