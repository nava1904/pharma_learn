import 'package:relic/relic.dart';

import 'assessments_handler.dart';
import 'assessment_grade_handler.dart';
import 'assessment_progress_handler.dart';
import 'assessment_results_handler.dart';
import 'assessment_publish_handler.dart';
import 'assessment_extend_handler.dart';
import 'grading_queue_handler.dart';

/// Mounts /v1/certify/assessments routes
void mountAssessmentsRoutes(RelicApp app) {
  // Assessment flow
  app.post('/v1/certify/assessments/start', assessmentStartHandler);
  app.post('/v1/certify/assessments/:id/answer', assessmentAnswerHandler);
  app.post('/v1/certify/assessments/:id/submit', assessmentSubmitHandler);
  app.get('/v1/certify/assessments/:id', assessmentGetHandler);
  app.get('/v1/certify/assessments/:id/progress', assessmentProgressHandler);
  app.get('/v1/certify/assessments/:id/results', assessmentResultsHandler);
  app.get('/v1/certify/assessments/history', assessmentHistoryHandler);

  // Grading (trainer/reviewer)
  app.post('/v1/certify/assessments/:id/grade', assessmentGradeHandler);
  app.post('/v1/certify/assessments/:id/publish-results', assessmentPublishResultsHandler);
  app.get('/v1/certify/assessments/:id/questions/analysis', assessmentQuestionAnalysisHandler);

  // Grading queue management
  app.get('/v1/certify/assessments/grading-queue', gradingQueueListHandler);
  app.get('/v1/certify/assessments/grading-queue/:id', gradingQueueGetHandler);
  app.post('/v1/certify/assessments/grading-queue/:id/assign', gradingQueueAssignHandler);
  app.post('/v1/certify/assessments/grading-queue/:id/grade', gradingQueueGradeHandler);
  
  // Graders list
  app.get('/v1/certify/assessments/graders', gradersListHandler);
  
  // GAP-M7: Extension requests
  app.get('/v1/certify/assessments/extension-requests', assessmentExtensionsPendingHandler);
  app.post('/v1/certify/assessments/:id/request-extension', assessmentExtendRequestHandler);
  app.post('/v1/certify/assessments/extension-requests/:id/approve', assessmentExtendApproveHandler);
  app.post('/v1/certify/assessments/extension-requests/:id/reject', assessmentExtendRejectHandler);
}
