import 'dart:io';

import 'package:pharma_learn_workflow_engine/workflow_engine.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';
import 'package:relic/relic.dart';

Future<void> main() async {
  final port =
      int.tryParse(Platform.environment['WORKFLOW_ENGINE_PORT'] ?? '8085') ??
          8085;

  final supabase = SupabaseService.client;

  final app = RelicApp();
  app
    ..use('/', loggerMiddleware())
    ..use('/', corsMiddleware())
    ..use('/', withErrorHandler);

  mountAllRoutes(app);

  // Start the workflow event listener (pg_notify + 5 s poll)
  final listener = WorkflowListenerService(
    supabase,
    internalBaseUrl: 'http://localhost:$port',
  );
  await listener.start();

  await app.serve(port: port);
  print('Workflow Engine running on http://0.0.0.0:$port');
  print('Health: http://0.0.0.0:$port/health');
}
