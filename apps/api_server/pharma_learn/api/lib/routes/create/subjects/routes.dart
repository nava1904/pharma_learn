import 'package:relic/relic.dart';

import 'subjects_handler.dart';

/// Mounts /v1/subjects routes
void mountSubjectsRoutes(RelicApp app) {
  app.get('/v1/subjects', subjectsListHandler);
  app.get('/v1/subjects/:id', subjectGetHandler);
  app.post('/v1/subjects', subjectCreateHandler);
  app.put('/v1/subjects/:id', subjectUpdateHandler);
  app.delete('/v1/subjects/:id', subjectDeleteHandler);
  app.post('/v1/subjects/:id/submit', subjectSubmitHandler);
  app.post('/v1/subjects/:id/approve', subjectApproveHandler);
}
