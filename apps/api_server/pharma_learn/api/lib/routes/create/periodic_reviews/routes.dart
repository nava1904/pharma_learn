import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'periodic_reviews_handler.dart';

void mountPeriodicReviewRoutes(RelicApp app) {
  app.get('/v1/periodic-reviews', periodicReviewsListHandler);
  app.get('/v1/periodic-reviews/:id', periodicReviewGetHandler);
  app.post('/v1/periodic-reviews', periodicReviewCreateHandler);
  app.patch('/v1/periodic-reviews/:id', periodicReviewUpdateHandler);
  app.delete('/v1/periodic-reviews/:id', periodicReviewDeleteHandler);
  
  // Complete a review (requires e-sig)
  app.post('/v1/periodic-reviews/:id/complete', withEsig(periodicReviewCompleteHandler));
}
