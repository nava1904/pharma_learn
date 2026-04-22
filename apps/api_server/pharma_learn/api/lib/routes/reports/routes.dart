import 'package:relic/relic.dart';

import 'report_run_download_handler.dart';
import 'report_run_handler.dart';
import 'report_run_status_handler.dart';
import 'report_runs_handler.dart';
import 'report_schedule_handler.dart';
import 'report_schedules_handler.dart';
import 'report_template_handler.dart';
import 'report_templates_handler.dart';

/// Mounts /v1/reports routes
void mountReportsRoutes(RelicApp app) {
  // Templates (read-only)
  app.get('/v1/reports/templates', reportTemplatesListHandler);
  app.get('/v1/reports/templates/:id', reportTemplateGetHandler);
  
  // Report runs (job execution)
  app.post('/v1/reports/:templateId/run', reportRunHandler);
  app.get('/v1/reports/runs', reportRunsListHandler);
  app.get('/v1/reports/runs/:id', reportRunStatusHandler);
  app.get('/v1/reports/runs/:id/download', reportRunDownloadHandler);
  
  // Schedules (recurring reports)
  app.get('/v1/reports/schedules', reportSchedulesListHandler);
  app.post('/v1/reports/schedules', reportSchedulesCreateHandler);
  app.get('/v1/reports/schedules/:id', reportScheduleGetHandler);
  app.patch('/v1/reports/schedules/:id', reportScheduleUpdateHandler);
  app.delete('/v1/reports/schedules/:id', reportScheduleDeleteHandler);
}
