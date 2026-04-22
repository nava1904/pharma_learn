import 'package:relic/relic.dart';

import '../context/request_context.dart';
import '../models/error_response.dart';

/// Middleware that blocks uninducted employees from accessing protected routes.
///
/// Employees who haven't completed their induction training can only access:
/// - /health (system health)
/// - /v1/auth/* (authentication)
/// - /v1/train/induction/* (induction content)
/// - /v1/access/me (own profile)
/// - /v1/certify/certificates (own certificates - may have pre-hire certs)
///
/// All other routes return 403 Forbidden until induction is complete.
///
/// Usage in server setup:
/// ```dart
/// app.use(authMiddleware);
/// app.use(inductionGateMiddleware());
/// ```
Middleware inductionGateMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      // Check if route is whitelisted
      final path = request.url.path;
      if (_isWhitelisted(path)) {
        return inner(request);
      }

      // Get auth context (set by authMiddleware)
      final auth = RequestContext.authOrNull;
      if (auth == null) {
        // No auth context - let authMiddleware handle it
        return inner(request);
      }

      // Check induction status
      if (auth.inductionCompleted) {
        return inner(request);
      }

      // Block access - induction not complete
      return ErrorResponse.inductionRequired(
        'Induction not completed. Complete your induction training to access this feature.',
      ).toResponse();
    };
  };
}

/// Routes that uninducted employees can access
const _inductionWhitelist = [
  'health',
  'v1/auth/',
  'v1/train/induction/',
  'v1/access/me',
  'v1/certify/certificates',
];

bool _isWhitelisted(String path) {
  // Normalize path (remove leading slash)
  final normalizedPath = path.startsWith('/') ? path.substring(1) : path;

  for (final allowed in _inductionWhitelist) {
    if (normalizedPath == allowed ||
        normalizedPath.startsWith(allowed) ||
        normalizedPath.startsWith('$allowed/')) {
      return true;
    }
  }

  return false;
}
