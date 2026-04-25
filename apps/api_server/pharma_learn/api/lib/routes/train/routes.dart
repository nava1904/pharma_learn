import 'package:relic/relic.dart';

import 'induction/routes.dart';
import 'me/routes.dart';
import 'obligations/routes.dart';
import 'ojt/routes.dart';
import 'schedules/routes.dart';
import 'self_learning/routes.dart';
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
  
  // Employee obligations
  mountObligationsRoutes(app);
  
  // Self-paced learning
  mountSelfLearningRoutes(app);
  
  // On-the-job training
  mountOjtRoutes(app);
  
  // TODO: Add these as they are implemented
  // mountCoordinatorRoutes(app);
}
