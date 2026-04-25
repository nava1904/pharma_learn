import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'induction_handler.dart';

void mountInductionRoutes(RelicApp app) {
  // Get current induction status
  app.get('/v1/induction/status', inductionStatusHandler);
  
  // List available induction modules
  app.get('/v1/induction/modules', inductionModulesHandler);
  
  // Get specific module details
  app.get('/v1/induction/modules/:id', inductionModuleDetailHandler);
  
  // Complete induction - requires e-signature
  app.post('/v1/induction/complete', withEsig(inductionCompleteHandler));
}
