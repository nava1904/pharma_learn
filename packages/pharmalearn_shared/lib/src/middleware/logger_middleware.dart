import 'dart:convert';

import 'package:logger/logger.dart' as logging;
import 'package:relic/relic.dart';

/// Creates a structured-JSON logger middleware for Relic.
///
/// Each request is logged with method, path, status, and duration_ms
/// as a JSON object on a single line, compatible with log aggregators
/// such as Cloud Logging or Datadog.
Handler Function(Handler) loggerMiddleware() {
  final logger = logging.Logger(
    printer: _JsonPrinter(),
    output: _ConsoleOutput(),
  );

  return (Handler innerHandler) {
    return (Request request) async {
      final start = DateTime.now();

      Result result;
      try {
        result = await innerHandler(request);
      } catch (e) {
        final duration = DateTime.now().difference(start).inMilliseconds;
        logger.e(
          jsonEncode({
            'level': 'ERROR',
            'method': request.method.value,
            'path': request.url.path,
            'status': 500,
            'duration_ms': duration,
            'timestamp': start.toUtc().toIso8601String(),
            'error': e.toString(),
          }),
        );
        rethrow;
      }

      final duration = DateTime.now().difference(start).inMilliseconds;
      
      // Get status code if result is a Response
      final statusCode = result is Response ? result.statusCode : 200;
      final level = statusCode >= 500
          ? 'ERROR'
          : statusCode >= 400
              ? 'WARN'
              : 'INFO';

      logger.i(
        jsonEncode({
          'level': level,
          'method': request.method.value,
          'path': request.url.path,
          'status': statusCode,
          'duration_ms': duration,
          'timestamp': start.toUtc().toIso8601String(),
        }),
      );

      return result;
    };
  };
}

/// Minimal printer that passes the message through unchanged — the message is
/// already a JSON string, so no extra formatting is needed.
class _JsonPrinter extends logging.LogPrinter {
  @override
  List<String> log(logging.LogEvent event) => [event.message.toString()];
}

/// Writes each log line to stdout.
class _ConsoleOutput extends logging.LogOutput {
  @override
  void output(logging.OutputEvent event) {
    for (final line in event.lines) {
      // ignore: avoid_print
      print(line);
    }
  }
}
