import 'package:relic/relic.dart';

import 'scorm_handler.dart';

void mountScormRoutes(RelicApp app) {
  // SCORM package management
  app.get('/v1/scorm/packages', scormPackagesListHandler);
  app.post('/v1/scorm/packages', scormUploadHandler);
  
  // Individual package operations
  app.get('/v1/scorm/:id', scormPackageGetHandler);
  app.delete('/v1/scorm/:id', scormDeleteHandler);
  
  // SCORM runtime
  app.get('/v1/scorm/:id/launch', scormLaunchHandler);
  app.post('/v1/scorm/:id/initialize', scormInitializeHandler);
  app.post('/v1/scorm/:id/commit', scormCommitHandler);
  app.get('/v1/scorm/:id/progress', scormProgressHandler);
}
