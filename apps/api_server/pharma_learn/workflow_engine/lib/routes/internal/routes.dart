import 'package:relic/relic.dart';
import 'advance_step_handler.dart';
import 'approve_step_handler.dart';
import 'reject_workflow_handler.dart';
import 'complete_workflow_handler.dart';

void mountInternalRoutes(RelicApp app) {
  // Triggered by WorkflowListenerService on *.submitted events
  app.post('/internal/workflow/advance-step', advanceStepHandler);
  
  // Called by API when approver approves a step
  app.post('/internal/workflow/approve-step', approveStepHandler);
  
  // Called by API when approver rejects a step
  app.post('/internal/workflow/reject', rejectWorkflowHandler);
  
  // Finalizes workflow after all approvals (or bypass)
  app.post('/internal/workflow/complete', completeWorkflowHandler);
}
