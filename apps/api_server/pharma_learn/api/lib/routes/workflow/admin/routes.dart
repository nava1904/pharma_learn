import 'package:relic/relic.dart';

import 'admin_events_handler.dart';

/// Mounts /v1/admin/* routes for administrative operations.
void mountAdminRoutes(RelicApp app) {
  // Event system monitoring
  app.get('/v1/admin/events/status', adminEventsStatusHandler);
  app.get('/v1/admin/events/dead-letter', adminDeadLetterListHandler);
  app.post('/v1/admin/events/dead-letter/:id/retry', adminDeadLetterRetryHandler);
}
