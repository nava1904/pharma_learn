import 'package:relic/relic.dart';

import 'job_responsibilities_handler.dart';

void mountJobResponsibilityRoutes(RelicApp app) {
  // Collection (admin)
  app.get('/v1/access/job-responsibilities', jobResponsibilitiesListHandler);
  app.post('/v1/access/job-responsibilities', jobResponsibilityCreateHandler);

  // Individual job responsibility
  app.get('/v1/access/job-responsibilities/:id', jobResponsibilityGetHandler);
  app.patch('/v1/access/job-responsibilities/:id', jobResponsibilityUpdateHandler);

  // Workflow
  app.post('/v1/access/job-responsibilities/:id/submit', jobResponsibilitySubmitHandler);
  app.post('/v1/access/job-responsibilities/:id/approve', jobResponsibilityApproveHandler);
  app.post('/v1/access/job-responsibilities/:id/accept', jobResponsibilityAcceptHandler);
  app.post('/v1/access/job-responsibilities/:id/reject', jobResponsibilityRejectHandler);

  // Employee-specific routes
  app.get('/v1/access/employees/:id/job-responsibility', employeeJobResponsibilityHandler);
  app.get('/v1/access/employees/:id/job-responsibility/history', employeeJobResponsibilityHistoryHandler);
}
