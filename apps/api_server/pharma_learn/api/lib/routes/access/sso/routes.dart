import 'package:relic/relic.dart';

import 'sso_handler.dart';

void mountSsoRoutes(RelicApp app) {
  // SSO Configuration management
  app.get('/v1/sso/configurations', ssoConfigurationsListHandler);
  app.get('/v1/sso/configurations/:id', ssoConfigurationGetHandler);
  app.post('/v1/sso/configurations', ssoConfigurationCreateHandler);
  app.patch('/v1/sso/configurations/:id', ssoConfigurationUpdateHandler);
  app.delete('/v1/sso/configurations/:id', ssoConfigurationDeleteHandler);
  app.post('/v1/sso/configurations/:id/test', ssoConfigurationTestHandler);
  
  // SSO Login flow
  app.post('/v1/auth/sso/login', ssoLoginInitHandler);
  app.post('/v1/auth/sso/callback', ssoCallbackHandler);
}
