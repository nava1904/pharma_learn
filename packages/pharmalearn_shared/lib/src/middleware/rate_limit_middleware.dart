import 'dart:convert';
import 'dart:io';

import 'package:relic/relic.dart';

import '../context/request_context.dart';
import '../models/error_response.dart';

// ---------------------------------------------------------------------------
// Rate Limit Middleware — per-user token bucket
// ---------------------------------------------------------------------------

/// In-process token bucket rate limiter.
///
/// Default: 100 requests per 60 seconds per employee (or per IP for
/// unauthenticated requests). Exceeding the limit returns 429 with a
/// `Retry-After: 60` header.
///
/// Thresholds are read from environment variables:
/// - `RATE_LIMIT_MAX_REQUESTS` (default 100)
/// - `RATE_LIMIT_WINDOW_SECONDS` (default 60)
Handler Function(Handler) rateLimitMiddleware() {
  final int maxRequests =
      int.tryParse(Platform.environment['RATE_LIMIT_MAX_REQUESTS'] ?? '') ??
          100;
  final int windowSeconds =
      int.tryParse(Platform.environment['RATE_LIMIT_WINDOW_SECONDS'] ?? '') ??
          60;

  final buckets = <String, _Bucket>{};

  return (Handler innerHandler) {
    return (Request request) async {
      // Key by employeeId (authenticated) or client IP (anonymous)
      final auth = RequestContext.authOrNull;
      final key = auth?.employeeId.isNotEmpty == true
          ? 'emp:${auth!.employeeId}'
          : 'ip:${request.connectionInfo.remote.address}';

      final now = DateTime.now();
      final bucket = buckets.putIfAbsent(key, () => _Bucket(maxRequests));

      // Refill tokens if the window has elapsed
      if (now.difference(bucket.windowStart).inSeconds >= windowSeconds) {
        bucket.tokens = maxRequests;
        bucket.windowStart = now;
      }

      if (bucket.tokens <= 0) {
        return Response(
          429,
          headers: Headers.build((h) {
            h['retry-after'] = [windowSeconds.toString()];
          }),
          body: Body.fromString(
            jsonEncode(ErrorResponse.rateLimit().toJson()),
            mimeType: MimeType.json,
          ),
        );
      }

      bucket.tokens--;
      return innerHandler(request);
    };
  };
}

class _Bucket {
  int tokens;
  DateTime windowStart = DateTime.now();

  _Bucket(this.tokens);
}
