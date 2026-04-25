import 'package:relic/relic.dart';

import 'reauth_create_handler.dart';
import 'reauth_validate_handler.dart';

void mountReauthRoutes(RelicApp app) {
  app
    ..post('/v1/reauth/create', reauthCreateHandler)
    ..post('/v1/reauth/validate', reauthValidateHandler);
}
