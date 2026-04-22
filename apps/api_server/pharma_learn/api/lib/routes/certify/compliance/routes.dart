import 'package:relic/relic.dart';

import 'compliance_handler.dart';
import 'compliance_report_handler.dart';

/// Mounts /v1/certify/compliance routes
void mountComplianceRoutes(RelicApp app) {
  // Employee's own compliance
  app.get('/v1/certify/compliance/my', complianceMyHandler);
  
  // Admin compliance dashboard
  app.get('/v1/certify/compliance/dashboard', complianceDashboardHandler);
  app.get('/v1/certify/compliance/employees/:id', complianceEmployeeHandler);
  app.get('/v1/certify/compliance/reports/summary', complianceSummaryReportHandler);
  
  // Compliance reports (run/download)
  app.get('/v1/certify/compliance/reports', complianceReportsListHandler);
  app.post('/v1/certify/compliance/reports/run', complianceReportRunHandler);
  app.get('/v1/certify/compliance/reports/:id', complianceReportGetHandler);
  app.get('/v1/certify/compliance/reports/:id/download', complianceReportDownloadHandler);
}
