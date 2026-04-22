import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'approval_handler.dart';

void mountApprovalRoutes(RelicApp app) {
  // List pending approvals for authenticated user
  app.get('/v1/workflow/approvals', approvalListHandler);
  
  // View approval history (past approvals/rejections by user)
  app.get('/v1/workflow/approvals/history', approvalHistoryHandler);
  
  // Get specific approval details
  app.get('/v1/workflow/approvals/:id', approvalGetHandler);
  
  // Approve a step (with e-signature middleware if required)
  app.post(
    '/v1/workflow/approvals/:id/approve',
    withEsig(approvalApproveHandler),
  );
  
  // Reject a step (with e-signature middleware if required)
  app.post(
    '/v1/workflow/approvals/:id/reject',
    withEsig(approvalRejectHandler),
  );
  
  // Return for corrections (soft reject - allows resubmission)
  app.post(
    '/v1/workflow/approvals/:id/return',
    approvalReturnHandler,
  );
}
