import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// Validate and return a UUID path parameter (from a nullable Symbol-keyed path param).
///
/// Throws [ValidationException] if [raw] is null, empty, or not a valid UUID.
String parsePathUuid(String? raw, {String fieldName = 'id'}) {
  if (raw == null || raw.isEmpty) {
    throw ValidationException({fieldName: 'Required'});
  }
  final uuidRegex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  if (!uuidRegex.hasMatch(raw)) {
    throw ValidationException({fieldName: 'Must be a valid UUID'});
  }
  return raw.toLowerCase();
}

/// Extract and validate an integer query parameter, returning [defaultValue]
/// when the key is absent or unparseable.
int parseInt(
  Map<String, String> queryParams,
  String key, {
  int defaultValue = 1,
}) {
  final raw = queryParams[key];
  if (raw == null || raw.isEmpty) return defaultValue;
  return int.tryParse(raw) ?? defaultValue;
}
