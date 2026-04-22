import 'dart:convert';

import 'package:relic/relic.dart';

import '../models/error_response.dart';

// ---------------------------------------------------------------------------
// Custom exception hierarchy
// ---------------------------------------------------------------------------

/// Base class for all domain-specific exceptions in PharmaLearn.
abstract class PharmaLearnException implements Exception {
  final String message;
  const PharmaLearnException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class NotFoundException extends PharmaLearnException {
  const NotFoundException(super.message);
}

class PermissionDeniedException extends PharmaLearnException {
  const PermissionDeniedException(super.message);
}

class ValidationException extends PharmaLearnException {
  final Map<String, dynamic> errors;
  ValidationException(this.errors) : super('Validation failed');
}

class EsigRequiredException extends PharmaLearnException {
  const EsigRequiredException(super.message);
}

class SessionTimeoutException extends PharmaLearnException {
  const SessionTimeoutException([
    super.message = 'Your session has expired. Please log in again.',
  ]);
}

class AccountLockedException extends PharmaLearnException {
  const AccountLockedException(super.message);
}

class ConflictException extends PharmaLearnException {
  const ConflictException(super.message);
}

class ImmutableRecordException extends PharmaLearnException {
  const ImmutableRecordException(super.message);
}

class InductionGateException extends PharmaLearnException {
  const InductionGateException([
    super.message =
        'You must complete mandatory induction training before accessing this resource.',
  ]);
}

class AuthException extends PharmaLearnException {
  const AuthException(super.message);
}

class RateLimitException extends PharmaLearnException {
  const RateLimitException([super.message = 'Rate limit exceeded.']);
}

// ---------------------------------------------------------------------------
// Error handler middleware
// ---------------------------------------------------------------------------

/// Wraps [handler] to catch all [PharmaLearnException]s (and unexpected errors)
/// and return the appropriate RFC 7807 [Response].
Handler withErrorHandler(Handler handler) {
  return (Request request) async {
    try {
      return await handler(request);
    } on NotFoundException catch (e) {
      return _problem(ErrorResponse.notFound(e.message));
    } on PermissionDeniedException catch (e) {
      return _problem(ErrorResponse.permissionDenied(e.message));
    } on ValidationException catch (e) {
      return _problem(ErrorResponse.validation(e.errors));
    } on EsigRequiredException catch (e) {
      return _problem(ErrorResponse.esigRequired(e.message));
    } on SessionTimeoutException {
      return _problem(ErrorResponse.sessionTimeout());
    } on AccountLockedException catch (e) {
      return _problem(ErrorResponse.accountLocked(e.message));
    } on ConflictException catch (e) {
      return _problem(ErrorResponse.conflict(e.message));
    } on ImmutableRecordException catch (e) {
      return _problem(ErrorResponse.immutableRecord(e.message));
    } on InductionGateException catch (e) {
      return _problem(ErrorResponse.inductionRequired(e.message));
    } on AuthException catch (e) {
      return _problem(ErrorResponse.unauthorized(e.message));
    } on RateLimitException {
      return Response(
        429,
        headers: Headers.build((h) {
          h['retry-after'] = ['60'];
        }),
        body: Body.fromString(
          jsonEncode(ErrorResponse.rateLimit().toJson()),
          mimeType: MimeType.json,
        ),
      );
    } catch (_) {
      return _problem(ErrorResponse.internalError());
    }
  };
}

Response _problem(ErrorResponse err) {
  return Response(
    err.status,
    body: Body.fromString(
      jsonEncode(err.toJson()),
      mimeType: MimeType.json,
    ),
  );
}
