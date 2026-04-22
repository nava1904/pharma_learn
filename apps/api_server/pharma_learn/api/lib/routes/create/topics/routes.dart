import 'package:relic/relic.dart';

import 'topics_handler.dart';

/// Mounts /v1/topics routes
void mountTopicsRoutes(RelicApp app) {
  app.get('/v1/topics', topicsListHandler);
  app.get('/v1/topics/:id', topicGetHandler);
  app.post('/v1/topics', topicCreateHandler);
  app.put('/v1/topics/:id', topicUpdateHandler);
  app.delete('/v1/topics/:id', topicDeleteHandler);
  app.post('/v1/topics/:id/submit', topicSubmitHandler);
  app.post('/v1/topics/:id/approve', topicApproveHandler);
  app.post('/v1/topics/:id/documents', topicLinkDocumentHandler);
  app.delete('/v1/topics/:id/documents/:documentId', topicUnlinkDocumentHandler);
}
