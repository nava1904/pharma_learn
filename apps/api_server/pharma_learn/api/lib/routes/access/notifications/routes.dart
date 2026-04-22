import 'package:relic/relic.dart';

import 'notification_handler.dart';

void mountNotificationRoutes(RelicApp app) {
  // List notifications (with filtering)
  app.get('/v1/access/notifications', notificationListHandler);
  
  // Get unread count (for badge display)
  app.get('/v1/access/notifications/unread-count', notificationUnreadCountHandler);
  
  // Mark single notification as read
  app.patch('/v1/access/notifications/:id/read', notificationMarkReadHandler);
  
  // Mark all notifications as read
  app.patch('/v1/access/notifications/read-all', notificationMarkAllReadHandler);
  
  // Delete (soft) a notification
  app.delete('/v1/access/notifications/:id', notificationDeleteHandler);
  
  // Notification settings
  app.get('/v1/access/notifications/settings', notificationSettingsGetHandler);
  app.patch('/v1/access/notifications/settings', notificationSettingsPatchHandler);
}
