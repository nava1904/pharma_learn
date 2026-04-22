import 'package:relic/relic.dart';

import 'mail_settings_handler.dart';

void mountMailSettingsRoutes(RelicApp app) {
  // Event codes reference
  app.get('/v1/access/mail-settings/event-codes', mailEventCodesListHandler);

  // Templates (admin)
  app.get('/v1/access/mail-settings/templates', mailTemplatesListHandler);
  app.post('/v1/access/mail-settings/templates', mailTemplateCreateHandler);
  app.get('/v1/access/mail-settings/templates/:id', mailTemplateGetHandler);
  app.patch('/v1/access/mail-settings/templates/:id', mailTemplateUpdateHandler);
  app.delete('/v1/access/mail-settings/templates/:id', mailTemplateDeleteHandler);
  app.post('/v1/access/mail-settings/templates/:id/test', mailTemplateTestHandler);

  // Subscriptions (user)
  app.get('/v1/access/mail-settings/subscriptions', mailSubscriptionsListHandler);
  app.post('/v1/access/mail-settings/subscriptions', mailSubscriptionUpsertHandler);
  app.delete('/v1/access/mail-settings/subscriptions/:eventCode', mailSubscriptionDeleteHandler);
}
