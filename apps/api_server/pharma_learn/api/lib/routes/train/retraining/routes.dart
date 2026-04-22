import 'package:relic/relic.dart';

import 'retraining_handler.dart';

void mountRetrainingRoutes(RelicApp app) {
  app
    ..post('/v1/train/retraining', retrainingCreateHandler)
    ..get('/v1/train/retraining', retrainingListHandler)
    ..get('/v1/train/retraining/:id', retrainingGetHandler)
    ..post('/v1/train/retraining/:id/cancel', retrainingCancelHandler);
}
