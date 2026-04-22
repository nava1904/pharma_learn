import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'schedules_handler.dart';
import 'schedule_workflow_handler.dart';
import 'schedule_enrollment_handler.dart';
import 'schedule_invitations_handler.dart';
import 'schedule_self_nominate_handler.dart';
import 'batches_handler.dart';

void mountScheduleRoutes(RelicApp app) {
  // List and create schedules
  app.get('/v1/train/schedules', schedulesListHandler);
  app.post('/v1/train/schedules', scheduleCreateHandler);
  
  // Individual schedule operations
  app.get('/v1/train/schedules/:id', scheduleGetHandler);
  app.patch('/v1/train/schedules/:id', scheduleUpdateHandler);
  app.delete('/v1/train/schedules/:id', scheduleCancelHandler);
  
  // Workflow transitions
  app.post('/v1/train/schedules/:id/submit', scheduleSubmitHandler);
  app.post('/v1/train/schedules/:id/approve', withEsig(scheduleApproveHandler));
  app.post('/v1/train/schedules/:id/reject', withEsig(scheduleRejectHandler));
  
  // Assignment and enrollment
  app.post('/v1/train/schedules/:id/assign', scheduleAssignHandler);
  app.post('/v1/train/schedules/:id/enroll', scheduleEnrollHandler);
  app.delete('/v1/train/schedules/:id/enroll', scheduleUnenrollHandler);
  app.get('/v1/train/schedules/:id/enrollments', scheduleEnrollmentsListHandler);
  
  // Invitations
  app.get('/v1/train/schedules/:id/invitations', scheduleInvitationsListHandler);
  app.post('/v1/train/schedules/:id/invitations', scheduleInvitationsHandler);
  app.post('/v1/train/invitations/:id/respond', invitationRespondHandler);
  
  // GAP-H6: Self-nomination
  app.post('/v1/train/schedules/:id/self-nominate', scheduleSelfNominateHandler);
  app.delete('/v1/train/schedules/:id/self-nominate', scheduleWithdrawNominationHandler);
  app.get('/v1/train/schedules/:id/nominations', scheduleNominationsListHandler);
  app.post('/v1/train/schedules/:id/nominations/:nominationId/approve', withEsig(scheduleNominationAcceptHandler));
  app.post('/v1/train/schedules/:id/nominations/:nominationId/reject', scheduleNominationRejectHandler);
  
  // Batches (batch training)
  app.get('/v1/train/batches', batchesListHandler);
  app.post('/v1/train/batches', batchCreateHandler);
  app.get('/v1/train/batches/:id', batchGetHandler);
  app.patch('/v1/train/batches/:id', batchUpdateHandler);
  app.post('/v1/train/batches/:id/schedules', batchAddScheduleHandler);
  app.delete('/v1/train/batches/:id/schedules/:scheduleId', batchRemoveScheduleHandler);
  app.post('/v1/train/batches/:id/complete', withEsig(batchCompleteHandler));
}
