import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:uuid/uuid.dart';

import '../context/request_context.dart';
import 'error_handler.dart';

/// Reads the request body as a JSON object.
///
/// If the body has already been cached in the Zone context by esig_middleware
/// (via [RequestContext.body]), that cached value is returned to avoid
/// consuming the stream twice.
Future<Map<String, dynamic>> readJson(Request req) async {
  // Zone-based cache (set by esig_middleware)
  final cached = RequestContext.body;
  if (cached != null) return cached;

  final bodyString = await req.readAsString();
  if (bodyString.isEmpty) return {};

  final decoded = jsonDecode(bodyString);
  if (decoded is Map<String, dynamic>) return decoded;

  throw ValidationException({'_body': 'Expected a JSON object.'});
}

/// Returns the value of [key] from [body] as a [String].
///
/// Throws [ValidationException] if the key is missing or blank.
String requireString(Map<String, dynamic> body, String key) {
  final value = body[key];
  if (value == null) {
    throw ValidationException({key: 'Field "$key" is required.'});
  }
  if (value is! String || value.trim().isEmpty) {
    throw ValidationException({key: 'Field "$key" must be a non-empty string.'});
  }
  return value;
}

/// Returns the value of [key] from [body] as a [String], or `null` if absent.
String? optionalString(Map<String, dynamic> body, String key) {
  final value = body[key];
  if (value == null) return null;
  if (value is! String) {
    throw ValidationException({key: 'Field "$key" must be a string.'});
  }
  return value.isEmpty ? null : value;
}

/// Returns the value of [key] from [body] as a validated UUID [String].
///
/// Throws [ValidationException] if the key is missing or not a valid UUID.
String requireUuid(Map<String, dynamic> body, String key) {
  final raw = requireString(body, key);
  return parseUuid(raw, fieldName: key);
}

/// Validates that [raw] is a valid UUID v4 string.
///
/// Throws [ValidationException] with field name [fieldName] (defaults to
/// `'value'`) if the format is invalid.
String parseUuid(String raw, {String fieldName = 'value'}) {
  // Use the Uuid library's validation — it validates canonical UUID format.
  final isValid = Uuid.isValidUUID(fromString: raw);
  if (!isValid) {
    throw ValidationException({fieldName: '"$raw" is not a valid UUID.'});
  }
  return raw.toLowerCase();
}
