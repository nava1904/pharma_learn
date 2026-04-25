import 'package:relic/relic.dart';

import 'self_learning_handler.dart';

/// Mounts /v1/train/self-learning routes
void mountSelfLearningRoutes(RelicApp app) {
  // Self-learning flow
  app.post('/v1/train/self-learning/:obligationId/start', selfLearningStartHandler);
  app.post('/v1/train/self-learning/:obligationId/progress', selfLearningProgressHandler);
  app.post('/v1/train/self-learning/:obligationId/complete', selfLearningCompleteHandler);
  app.get('/v1/train/self-learning/:obligationId/status', selfLearningStatusHandler);
}
