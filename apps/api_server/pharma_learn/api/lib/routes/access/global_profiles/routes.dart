import 'package:relic/relic.dart';

import 'global_profiles_handler.dart';

void mountGlobalProfileRoutes(RelicApp app) {
  // Collection
  app.get('/v1/access/global-profiles', globalProfilesListHandler);
  app.post('/v1/access/global-profiles', globalProfileCreateHandler);

  // Individual profile
  app.get('/v1/access/global-profiles/:id', globalProfileGetHandler);
  app.patch('/v1/access/global-profiles/:id', globalProfileUpdateHandler);
  app.delete('/v1/access/global-profiles/:id', globalProfileDeleteHandler);

  // Workflow
  app.post('/v1/access/global-profiles/:id/submit', globalProfileSubmitHandler);
  app.post('/v1/access/global-profiles/:id/approve', globalProfileApproveHandler);

  // Permission check
  app.post('/v1/access/global-profiles/:id/permissions/check', globalProfileCheckPermissionHandler);

  // Role-specific
  app.get('/v1/access/roles/:id/profile', roleGlobalProfileHandler);
}
