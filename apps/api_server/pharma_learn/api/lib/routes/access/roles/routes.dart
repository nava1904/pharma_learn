import 'package:relic/relic.dart';

import 'roles_handler.dart';
import 'role_handler.dart';

void mountRoleRoutes(RelicApp app) {
  app
    ..get('/v1/roles', rolesListHandler)
    ..post('/v1/roles', rolesCreateHandler)
    ..get('/v1/roles/:id', roleGetHandler)
    ..patch('/v1/roles/:id', rolePatchHandler)
    ..delete('/v1/roles/:id', roleDeleteHandler);
}
