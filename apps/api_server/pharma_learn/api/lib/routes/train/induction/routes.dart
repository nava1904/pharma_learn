import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'induction_handler.dart';
import 'induction_coordinator_handler.dart';
import 'induction_trainer_handler.dart';

void mountInductionRoutes(RelicApp app) {
  // Get current induction status
  app.get('/v1/train/induction/status', inductionStatusHandler);
  
  // List available induction modules
  app.get('/v1/train/induction/modules', inductionModulesHandler);
  
  // Get specific module details
  app.get('/v1/train/induction/modules/:id', inductionModuleDetailHandler);
  
  // Complete induction - requires e-signature
  app.post('/v1/train/induction/complete', withEsig(inductionCompleteHandler));
  
  // GAP-M1: Coordinator induction registration
  app.post('/v1/train/induction/register', inductionCoordinatorCreateHandler);
  app.get('/v1/train/induction/registrations', inductionCoordinatorListHandler);
  app.get('/v1/train/induction/registrations/:id', inductionCoordinatorGetHandler);
  app.post('/v1/train/induction/registrations/:id/complete', withEsig(inductionRecordCompleteHandler));
  
  // GAP-M2 & M3: Trainer accept/decline and item reassignment
  app.get('/v1/train/induction/trainer/pending', inductionTrainerPendingHandler);
  app.post('/v1/train/induction/:id/trainer-respond', inductionTrainerRespondHandler);
  app.post('/v1/train/induction/:id/reassign', inductionTrainerReassignHandler);
}
