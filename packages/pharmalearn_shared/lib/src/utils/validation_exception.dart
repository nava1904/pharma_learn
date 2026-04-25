/// Thrown when request input fails validation.
///
/// [fieldErrors] maps field names to human-readable error messages.
class ValidationException implements Exception {
  final Map<String, dynamic> fieldErrors;

  const ValidationException(this.fieldErrors);

  @override
  String toString() => 'ValidationException($fieldErrors)';
}
