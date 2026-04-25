import 'package:relic/relic.dart';

import 'groups_handler.dart';

void mountGroupRoutes(RelicApp app) {
  app.get('/v1/groups', groupsListHandler);
  app.get('/v1/groups/:id', groupGetHandler);
  app.post('/v1/groups', groupCreateHandler);
  app.patch('/v1/groups/:id', groupUpdateHandler);
  app.delete('/v1/groups/:id', groupDeleteHandler);
  
  // Group members
  app.post('/v1/groups/:id/members', groupAddMembersHandler);
  app.delete('/v1/groups/:id/members/:employeeId', groupRemoveMemberHandler);
}
