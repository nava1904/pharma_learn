import 'package:relic/relic.dart';

import 'external_training_handler.dart';

void mountExternalTrainingRoutes(RelicApp app) {
  app
    ..post('/v1/train/external-training', externalTrainingCreateHandler)
    ..get('/v1/train/external-training', externalTrainingListHandler)
    ..get('/v1/train/external-training/:id', externalTrainingGetHandler)
    ..patch('/v1/train/external-training/:id', externalTrainingPatchHandler)
    ..post('/v1/train/external-training/:id/approve', externalTrainingApproveHandler)
    ..post('/v1/train/external-training/:id/reject', externalTrainingRejectHandler);
}
