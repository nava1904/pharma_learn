import 'package:relic/relic.dart';

import 'sessions_handler.dart';
import 'session_checkin_handler.dart';
import 'session_checkout_handler.dart';

void mountSessionRoutes(RelicApp app) {
  // Collection
  app.get('/v1/sessions', sessionsListHandler);

  // Single session
  app.get('/v1/sessions/:id', sessionGetHandler);

  // Check-in / Check-out
  app.post('/v1/sessions/:id/check-in', sessionCheckinHandler);
  app.post('/v1/sessions/:id/check-out', sessionCheckoutHandler);
}
