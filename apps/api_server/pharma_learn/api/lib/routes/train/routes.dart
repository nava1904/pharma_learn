import 'package:relic/relic.dart';

import 'coordinators/routes.dart';
import 'evaluations/routes.dart';
import 'external/routes.dart';
import 'feedback/routes.dart';
import 'induction/routes.dart';
import 'me/routes.dart';
import 'obligations/routes.dart';
import 'ojt/routes.dart';
import 'retraining/routes.dart';
import 'schedules/routes.dart';
import 'self_learning/routes.dart';
import 'self_study/routes.dart';
import 'sessions/routes.dart';
import 'triggers/routes.dart';
import 'triggers_handler.dart';

import 'induction/induction_coordinator_handler.dart';
import 'induction/induction_trainer_handler.dart';
import 'schedules/schedule_self_nominate_handler.dart';
import 'sessions/session_doc_reading_handler.dart';
import 'batches/batch_attendance_sheet_handler.dart';

/// Mounts all /v1/train/* routes.
void mountTrainRoutes(RelicApp app) {
  // Employee's personal training dashboard
  mountMeRoutes(app);
  
  // Induction flow (required before accessing other features)
  mountInductionRoutes(app);
  
  // Induction coordinator/trainer routes (GAP-M1, M2, M3)
  app
    ..post('/v1/train/induction', inductionCoordinatorCreateHandler)
    ..get('/v1/train/induction', inductionCoordinatorListHandler)
    ..get('/v1/train/induction/:id', inductionCoordinatorGetHandler)
    ..post('/v1/train/induction/:id/record', inductionRecordCompleteHandler)
    ..post('/v1/train/induction/:id/trainer-respond', inductionTrainerRespondHandler)
    ..get('/v1/train/induction/trainer/pending', inductionTrainerPendingHandler)
    ..post('/v1/train/induction/:id/trainer-reassign', inductionTrainerReassignHandler);
  
  // Training schedules (admin/coordinator)
  mountScheduleRoutes(app);
  
  // Self-nomination for schedules (GAP-H6)
  app
    ..post('/v1/train/schedules/:id/self-nominate', scheduleSelfNominateHandler)
    ..delete('/v1/train/schedules/:id/self-nominate', scheduleWithdrawNominationHandler)
    ..get('/v1/train/schedules/:id/nominations', scheduleNominationsListHandler)
    ..post('/v1/train/schedules/:id/nominations/:employeeId/accept', scheduleNominationAcceptHandler)
    ..post('/v1/train/schedules/:id/nominations/:employeeId/reject', scheduleNominationRejectHandler);
  
  // Training sessions and attendance
  mountSessionRoutes(app);
  
  // Offline document reading (GAP-M4)
  app
    ..post('/v1/train/sessions/:id/doc-reading/offline', sessionDocReadingOfflineHandler)
    ..post('/v1/train/sessions/:id/doc-reading/terminate', sessionDocReadingTerminateHandler);
  
  // Session feedback (GAP-H2)
  mountTrainFeedbackRoutes(app);
  
  // Short-term and long-term evaluations (GAP-H3, H4)
  mountEvaluationRoutes(app);
  
  // Employee obligations
  mountObligationsRoutes(app);
  
  // Self-paced learning
  mountSelfLearningRoutes(app);
  
  // Self-study open courses (GAP-L1)
  mountSelfStudyRoutes(app);
  
  // On-the-job training
  mountOjtRoutes(app);
  
  // Training coordinators
  mountCoordinatorRoutes(app);
  
  // External training (GAP-H5)
  mountExternalTrainingRoutes(app);
  
  // Retraining assignments (GAP-M5)
  mountRetrainingRoutes(app);
  
  // Batch attendance sheet (GAP-L3)
  app.get('/v1/train/batches/:id/attendance-sheet', batchAttendanceSheetHandler);
  
  // Training triggers - full management API
  mountTriggersRoutes(app);
  
  // Legacy trigger endpoint (backward compatibility)
  app.post('/v1/train/triggers/process', triggersProcessHandler);
}
