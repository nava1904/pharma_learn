import 'package:relic/relic.dart';

import 'schedules_handler.dart';

void mountScheduleRoutes(RelicApp app) {
  // List and create schedules
  app.get('/v1/schedules', schedulesListHandler);
  app.post('/v1/schedules', scheduleCreateHandler);
  
  // Individual schedule operations
  app.get('/v1/schedules/:id', scheduleGetHandler);
  app.patch('/v1/schedules/:id', scheduleUpdateHandler);
  app.delete('/v1/schedules/:id', scheduleCancelHandler);
}
