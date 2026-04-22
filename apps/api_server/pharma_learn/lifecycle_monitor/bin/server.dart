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

  // Initialize event router
  final eventRouter = LifecycleEventRouter(supabase);

  final listener = PgListenerService(supabase, onEvent: (event) async {
    // Route events through the lifecycle event router
    await eventRouter.route(event);
  });
  await listener.start();

  await app.serve(port: port);
  print('Lifecycle Monitor running on http://0.0.0.0:$port');
}
