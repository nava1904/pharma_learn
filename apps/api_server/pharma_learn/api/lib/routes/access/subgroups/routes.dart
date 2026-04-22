import 'package:relic/relic.dart';

import 'subgroups_handler.dart';

void mountSubgroupRoutes(RelicApp app) {
  // Collection
  app.get('/v1/access/subgroups', subgroupsListHandler);
  app.post('/v1/access/subgroups', subgroupCreateHandler);

  // Individual subgroup
  app.get('/v1/access/subgroups/:id', subgroupGetHandler);
  app.patch('/v1/access/subgroups/:id', subgroupUpdateHandler);
  app.delete('/v1/access/subgroups/:id', subgroupDeleteHandler);

  // Workflow
  app.post('/v1/access/subgroups/:id/submit', subgroupSubmitHandler);
  app.post('/v1/access/subgroups/:id/approve', subgroupApproveHandler);

  // Members
  app.get('/v1/access/subgroups/:id/members', subgroupMembersListHandler);
  app.post('/v1/access/subgroups/:id/members', subgroupMemberAddHandler);
  app.delete('/v1/access/subgroups/:id/members/:employeeId', subgroupMemberRemoveHandler);
}
