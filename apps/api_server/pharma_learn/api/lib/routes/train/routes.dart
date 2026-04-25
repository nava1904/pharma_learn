import 'package:relic/relic.dart';

import 'induction/routes.dart';
import 'me/routes.dart';
import 'schedules/routes.dart';
import 'sessions/routes.dart';

/// Mounts all /v1/train/* routes.
void mountTrainRoutes(RelicApp app) {
  // Employee's personal training dashboard
  mountMeRoutes(app);
  
  // Induction flow (required before accessing other features)
  mountInductionRoutes(app);
  
  // Training schedules (admin/coordinator)
  mountScheduleRoutes(app);
  
  // Training sessions and attendance
  mountSessionRoutes(app);
  
  // TODO: Add these as they are implemented
  // mountObligationRoutes(app);
  // mountSelfLearningRoutes(app);
  // mountOjtRoutes(app);
  // mountCoordinatorRoutes(app);
}
