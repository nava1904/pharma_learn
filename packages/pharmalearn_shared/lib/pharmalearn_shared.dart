/// PharmaLearn shared library.
///
/// Provides middleware, models, services and utilities consumed by all three
/// Relic servers (api, lifecycle_monitor, workflow_engine).
library;

// ── Client ──────────────────────────────────────────────────────────────────
export 'src/client/supabase_client.dart';
export 'src/client/supabase_user_client.dart';

// ── Context (Zone-based request-scoped storage + EsigContext) ───────────────
export 'src/context/request_context.dart';

// ── Events ───────────────────────────────────────────────────────────────────
export 'src/events/event_publisher.dart';

// ── Models ───────────────────────────────────────────────────────────────────
export 'src/models/api_response.dart';
export 'src/models/auth_context.dart';
export 'src/models/error_response.dart';
export 'src/models/esig_request.dart';
export 'src/models/pagination.dart';
export 'src/models/report_templates.dart';
export 'src/models/sort_options.dart';

// ── Middleware ────────────────────────────────────────────────────────────────
export 'src/middleware/audit_middleware.dart';
export 'src/middleware/auth_middleware.dart';
export 'src/middleware/cors_middleware.dart';
export 'src/middleware/esig_middleware.dart';
export 'src/middleware/induction_gate_middleware.dart';
export 'src/middleware/logger_middleware.dart';
export 'src/middleware/rate_limit_middleware.dart';

// ── Services ─────────────────────────────────────────────────────────────────
export 'src/services/certificate_service.dart';
export 'src/services/esig_service.dart';
export 'src/services/file_service.dart';
export 'src/services/jwt_service.dart';
export 'src/services/notification_service.dart';
export 'src/services/outbox_service.dart';
export 'src/services/password_service.dart';
export 'src/services/scorm_service.dart';

// ── Utilities ─────────────────────────────────────────────────────────────────
export 'src/utils/constants.dart';
export 'src/utils/error_handler.dart';
export 'src/utils/permission_checker.dart';
export 'src/utils/response_builder.dart';
