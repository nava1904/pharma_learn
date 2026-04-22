import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'sessions_handler.dart';
import 'session_checkin_handler.dart';
import 'session_checkout_handler.dart';
import 'session_attendance_handler.dart';
import 'session_qr_handler.dart';
import 'session_complete_handler.dart';
import 'session_doc_reading_handler.dart';

void mountSessionRoutes(RelicApp app) {
  // Collection
  app.get('/v1/train/sessions', sessionsListHandler);

  // Single session
  app.get('/v1/train/sessions/:id', sessionGetHandler);

  // Session lifecycle
  app.post('/v1/train/sessions/:id/start', sessionStartHandler);
  app.post('/v1/train/sessions/:id/complete', sessionCompleteHandler);
  app.post('/v1/train/sessions/:id/cancel', sessionCancelHandler);

  // Check-in / Check-out
  app.post('/v1/train/sessions/:id/check-in', sessionCheckinHandler);
  app.post('/v1/train/sessions/:id/check-out', sessionCheckoutHandler);

  // Attendance (trainer operations)
  app.get('/v1/train/sessions/:id/attendance', sessionAttendanceListHandler);
  app.post('/v1/train/sessions/:id/attendance', sessionAttendanceMarkHandler);
  app.patch('/v1/train/sessions/:id/attendance/:employeeId', sessionAttendanceCorrectionHandler);
  app.post('/v1/train/sessions/:id/attendance/upload', sessionAttendanceUploadHandler);

  // QR code for session check-in
  app.get('/v1/train/sessions/:id/qr', sessionQrGenerateHandler);
  app.post('/v1/train/sessions/:id/qr/validate', sessionQrValidateHandler);
  
  // GAP-M4: Offline document reading
  app.get('/v1/train/sessions/:id/documents/offline', sessionDocReadingOfflineHandler);
  app.post('/v1/train/sessions/:id/documents/reading-terminate', withEsig(sessionDocReadingTerminateHandler));
}
