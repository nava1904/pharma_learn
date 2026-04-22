import 'package:relic/relic.dart';

import 'session_feedback_handler.dart';

void mountTrainFeedbackRoutes(RelicApp app) {
  app
    ..post('/v1/train/sessions/:id/feedback', sessionFeedbackSubmitHandler)
    ..get('/v1/train/sessions/:id/feedback', sessionFeedbackListHandler)
    ..get('/v1/train/sessions/:id/feedback/my', sessionFeedbackMyHandler);
}
