import 'dart:io';
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';
import 'package:pharma_learn_lifecycle_monitor/lifecycle_monitor.dart';

Future<void> main() async {
  final port =
      int.tryParse(Platform.environment['LIFECYCLE_MONITOR_PORT'] ?? '8086') ??
          8086;

  // Initialize Supabase
  final supabase = SupabaseService.client;

  final app = RelicApp();
  app
    ..use('/', loggerMiddleware())
    ..use('/', corsMiddleware());

  mountAllRoutes(app);

  // Start background services
  final scheduler = JobSchedulerService(supabase);
  scheduler.start();

  final listener = PgListenerService(supabase, onEvent: (event) async {
    // Events consumed by lifecycle_monitor (not workflow events — those go to workflow_engine)
    // Workflow events (document.submitted etc.) are filtered to workflow_engine channel
  });
  await listener.start();

  await app.serve(port: port);
  print('Lifecycle Monitor running on http://0.0.0.0:$port');
}
