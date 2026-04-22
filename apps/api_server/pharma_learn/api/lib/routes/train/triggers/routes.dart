import 'package:relic/relic.dart';

import 'training_triggers_handler.dart';

/// Mounts /v1/train/triggers routes for training trigger management.
void mountTriggersRoutes(RelicApp app) {
  // Trigger rules CRUD
  app.get('/v1/train/triggers/rules', triggerRulesListHandler);
  app.post('/v1/train/triggers/rules', triggerRuleCreateHandler);
  app.get('/v1/train/triggers/rules/:id', triggerRuleGetHandler);
  app.patch('/v1/train/triggers/rules/:id', triggerRuleUpdateHandler);
  app.delete('/v1/train/triggers/rules/:id', triggerRuleDeleteHandler);
  
  // Trigger events (audit log)
  app.get('/v1/train/triggers/events', triggerEventsListHandler);
  app.post('/v1/train/triggers/events/:id/reprocess', triggerEventReprocessHandler);
  
  // Manual trigger firing
  app.post('/v1/train/triggers/fire', triggerFireHandler);
  
  // Statistics
  app.get('/v1/train/triggers/stats', triggerStatsHandler);
}
