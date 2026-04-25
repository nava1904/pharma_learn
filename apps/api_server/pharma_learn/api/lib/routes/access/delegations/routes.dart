import 'package:relic/relic.dart';

import 'delegations_handler.dart';

void mountDelegationRoutes(RelicApp app) {
  app.get('/v1/delegations', delegationsListHandler);
  app.get('/v1/delegations/:id', delegationGetHandler);
  app.post('/v1/delegations', delegationCreateHandler);
  app.patch('/v1/delegations/:id', delegationUpdateHandler);
  app.delete('/v1/delegations/:id', delegationRevokeHandler);
}
