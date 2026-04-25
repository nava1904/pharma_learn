import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'routes/routes.dart';

/// Creates and configures the [RelicApp] with all middleware and routes.
///
/// Middleware is applied in order:
/// 1. Logger — structured request/response logging
/// 2. CORS  — cross-origin headers
/// 3. Error handler — converts exceptions to RFC 7807 JSON error responses
/// 4. Auth  — JWT verification, session validation, idle-timeout, induction gate
/// 5. Rate limiter — per-user/per-IP throttling
RelicApp createApp() {
  final app = RelicApp();

  // Global middleware (order matters)
  app
    ..use('/', loggerMiddleware())
    ..use('/', corsMiddleware())
    ..use('/', withErrorHandler)
    ..use('/', authMiddleware())
    ..use('/', rateLimitMiddleware());

  // Mount all domain routes
  mountAllRoutes(app);

  return app;
}
