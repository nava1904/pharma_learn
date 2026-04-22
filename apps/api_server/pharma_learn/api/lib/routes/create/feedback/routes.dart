import 'package:relic/relic.dart';

import 'feedback_templates_handler.dart';
import 'evaluation_templates_handler.dart';

void mountFeedbackRoutes(RelicApp app) {
  // Feedback Templates
  app
    ..get('/v1/feedback-templates', feedbackTemplatesListHandler)
    ..post('/v1/feedback-templates', feedbackTemplateCreateHandler)
    ..get('/v1/feedback-templates/:id', feedbackTemplateGetHandler)
    ..patch('/v1/feedback-templates/:id', feedbackTemplatePatchHandler)
    ..delete('/v1/feedback-templates/:id', feedbackTemplateDeleteHandler);

  // Evaluation Templates
  app
    ..get('/v1/evaluation-templates', evaluationTemplatesListHandler)
    ..post('/v1/evaluation-templates', evaluationTemplateCreateHandler)
    ..get('/v1/evaluation-templates/:id', evaluationTemplateGetHandler)
    ..patch('/v1/evaluation-templates/:id', evaluationTemplatePatchHandler)
    ..delete('/v1/evaluation-templates/:id', evaluationTemplateDeleteHandler);
}
