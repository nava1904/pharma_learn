import 'dart:convert';

import 'package:relic/relic.dart';

/// RFC 7807 Problem Detail error response.
class ErrorResponse {
  final String type;
  final String title;
  final String detail;
  final int status;
  final String? instance;
  final Map<String, dynamic>? extensions;

  const ErrorResponse({
    required this.type,
    required this.title,
    required this.detail,
    required this.status,
    this.instance,
    this.extensions,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'title': title,
      'detail': detail,
      'status': status,
      if (instance != null) 'instance': instance,
      if (extensions != null) ...extensions!,
    };
  }

  /// Converts this error to a Relic [Response] with the appropriate status code.
  Response toResponse() {
    return Response(
      status,
      body: Body.fromString(
        jsonEncode({'error': toJson()}),
        mimeType: MimeType.json,
      ),
    );
  }

  factory ErrorResponse.notFound(String detail) => ErrorResponse(
        type: '/errors/not-found',
        title: 'Not Found',
        detail: detail,
        status: 404,
      );

  factory ErrorResponse.permissionDenied(String detail) => ErrorResponse(
        type: '/errors/permission-denied',
        title: 'Permission Denied',
        detail: detail,
        status: 403,
      );

  factory ErrorResponse.validation(Map<String, dynamic> errors) => ErrorResponse(
        type: '/errors/validation',
        title: 'Validation Failed',
        detail: 'One or more fields failed validation.',
        status: 422,
        extensions: {'field_errors': errors},
      );

  factory ErrorResponse.esigRequired(String detail) => ErrorResponse(
        type: '/errors/esig-required',
        title: 'Electronic Signature Required',
        detail: detail,
        status: 428,
      );

  factory ErrorResponse.sessionTimeout() => ErrorResponse(
        type: '/errors/session-timeout',
        title: 'Session Timeout',
        detail: 'Your session has expired. Please log in again.',
        status: 401,
      );

  factory ErrorResponse.accountLocked(String detail) => ErrorResponse(
        type: '/errors/account-locked',
        title: 'Account Locked',
        detail: detail,
        status: 423,
      );

  factory ErrorResponse.conflict(String detail) => ErrorResponse(
        type: '/errors/conflict',
        title: 'Conflict',
        detail: detail,
        status: 409,
      );

  factory ErrorResponse.immutableRecord(String detail) => ErrorResponse(
        type: '/errors/immutable-record',
        title: 'Immutable Record',
        detail: detail,
        status: 409,
      );

  factory ErrorResponse.rateLimit() => ErrorResponse(
        type: '/errors/rate-limit',
        title: 'Too Many Requests',
        detail: 'Rate limit exceeded. Please retry after 60 seconds.',
        status: 429,
      );

  factory ErrorResponse.internalError() => ErrorResponse(
        type: '/errors/internal',
        title: 'Internal Server Error',
        detail: 'An unexpected error occurred. Please try again later.',
        status: 500,
      );

  factory ErrorResponse.unauthorized(String detail) => ErrorResponse(
        type: '/errors/unauthorized',
        title: 'Unauthorized',
        detail: detail,
        status: 401,
      );

  factory ErrorResponse.inductionRequired(String detail) => ErrorResponse(
        type: '/errors/induction-required',
        title: 'Induction Required',
        detail: detail,
        status: 403,
      );
}
