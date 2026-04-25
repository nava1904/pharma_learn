import 'package:relic/relic.dart';
import 'advance_step_handler.dart';

void mountInternalRoutes(RelicApp app) {
  app.post('/internal/workflow/advance-step', advanceStepHandler);
}
