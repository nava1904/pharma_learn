import 'package:relic/relic.dart';

import 'notification_handler.dart';

/// Mounts /v1/notifications/* routes.
void mountWorkflowNotificationRoutes(RelicApp app) {
  app.get('/v1/notifications', notificationsListHandler);
  app.post('/v1/notifications/:id/read', notificationReadHandler);
  app.post('/v1/notifications/read-all', notificationsReadAllHandler);
  app.get('/v1/notifications/preferences', notificationPrefsGetHandler);
  app.patch('/v1/notifications/preferences', notificationPrefsPatchHandler);
}
