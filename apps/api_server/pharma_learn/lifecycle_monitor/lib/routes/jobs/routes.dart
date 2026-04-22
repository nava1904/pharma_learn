import 'package:relic/relic.dart';

import 'report_generation_handler.dart';
import 'integrity_check_handler.dart';
import 'overdue_training_handler.dart';
import 'archive_job_handler.dart';
import 'compliance_metrics_handler.dart';
import 'expiry_handlers.dart';
import 'events_fanout_handler.dart';
import 'periodic_review_handler.dart';

void mountJobRoutes(RelicApp app) {
  // Report generation (runs on schedule)
  app.post('/jobs/generate-reports', reportGenerationHandler);
  
  // Integrity check - 21 CFR §11.10(c) (daily)
  app.post('/jobs/integrity-check', integrityCheckHandler);
  
  // Overdue training escalation - Alfa §4.3.3 (hourly)
  app.post('/jobs/overdue-training', overdueTrainingHandler);
  
  // Archive job - EE §5.13.4 (daily)
  app.post('/jobs/archive', archiveJobHandler);
  
  // Compliance metrics - G5 migration (every 6 hours)
  app.post('/jobs/compliance-metrics', complianceMetricsHandler);
  
  // Certificate expiry notifications (hourly)
  app.post('/jobs/cert-expiry', certExpiryHandler);
  
  // Password expiry notifications (hourly)
  app.post('/jobs/password-expiry', passwordExpiryHandler);
  
  // Session cleanup / idle timeout (every 15 min)
  app.post('/jobs/session-cleanup', sessionCleanupHandler);
  
  // Events outbox fanout - Cross-domain event coordination (every 1 min)
  app.post('/jobs/events', eventsFanoutHandler);
  
  // Periodic review scheduler - WHO GMP §4.3.4 (daily)
  app.post('/jobs/periodic-review', periodicReviewHandler);
}
