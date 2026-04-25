import 'package:relic/relic.dart';

import 'venues_handler.dart';

void mountVenueRoutes(RelicApp app) {
  app.get('/v1/venues', venuesListHandler);
  app.get('/v1/venues/:id', venueGetHandler);
  app.post('/v1/venues', venueCreateHandler);
  app.patch('/v1/venues/:id', venueUpdateHandler);
  app.delete('/v1/venues/:id', venueDeleteHandler);
}
