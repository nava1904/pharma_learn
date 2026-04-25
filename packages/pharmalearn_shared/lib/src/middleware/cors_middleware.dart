import 'dart:io';

import 'package:relic/relic.dart';

/// CORS middleware for Relic.
///
/// Reads the `ALLOWED_ORIGINS` environment variable (comma-separated list of
/// allowed origins) and sets the appropriate CORS response headers.
///
/// Preflight `OPTIONS` requests receive a `204 No Content` response
/// immediately — the actual handler is not invoked.
Handler Function(Handler) corsMiddleware() {
  final rawOrigins = Platform.environment['ALLOWED_ORIGINS'] ?? '*';
  final allowedOrigins = rawOrigins
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();

  const allowedMethods = 'GET,POST,PATCH,PUT,DELETE,OPTIONS';
  const allowedHeaders = 'Authorization,Content-Type,Authorization-Reauth';

  return (Handler innerHandler) {
    return (Request request) async {
      final originValues = request.headers['origin'];
      final origin = originValues?.firstOrNull;
      final effectiveOrigin = _resolveOrigin(origin, allowedOrigins);

      // Handle preflight.
      if (request.method.value.toUpperCase() == 'OPTIONS') {
        return Response(
          204,
          headers: Headers.build((h) {
            if (effectiveOrigin != null) {
              h['access-control-allow-origin'] = [effectiveOrigin];
            }
            h['access-control-allow-methods'] = [allowedMethods];
            h['access-control-allow-headers'] = [allowedHeaders];
            h['access-control-max-age'] = ['86400'];
          }),
        );
      }

      final result = await innerHandler(request);

      // Result might be a Response - add CORS headers if it is
      if (result is Response) {
        final newHeaders = Headers.build((h) {
          // Copy existing headers
          for (final entry in result.headers.entries) {
            h[entry.key] = entry.value.toList();
          }
          // Add CORS headers
          if (effectiveOrigin != null) {
            h['access-control-allow-origin'] = [effectiveOrigin];
          }
          h['access-control-allow-methods'] = [allowedMethods];
          h['access-control-allow-headers'] = [allowedHeaders];
        });

        return Response(
          result.statusCode,
          headers: newHeaders,
          body: result.body,
        );
      }

      return result;
    };
  };
}

/// Returns the allowed origin string to echo back, or `null` if the
/// request's origin is not permitted.
String? _resolveOrigin(String? requestOrigin, Set<String> allowedOrigins) {
  if (allowedOrigins.contains('*')) return '*';
  if (requestOrigin == null) return null;
  if (allowedOrigins.contains(requestOrigin)) return requestOrigin;
  return null;
}
