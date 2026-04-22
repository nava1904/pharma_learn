import 'package:dio/dio.dart';

import 'api_response.dart';

/// Base exception for API errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiError? error;
  final dynamic originalError;
  
  const ApiException({
    required this.message,
    this.statusCode,
    this.error,
    this.originalError,
  });
  
  factory ApiException.fromDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    
    ApiError? error;
    if (data is Map<String, dynamic> && data['error'] != null) {
      error = ApiError.fromJson(data['error']);
    }
    
    String message;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timed out. Please try again.';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection. Please check your network.';
        break;
      case DioExceptionType.badResponse:
        message = error?.detail ?? 'Server error occurred.';
        break;
      case DioExceptionType.cancel:
        message = 'Request was cancelled.';
        break;
      default:
        message = e.message ?? 'An unexpected error occurred.';
    }
    
    return ApiException(
      message: message,
      statusCode: statusCode,
      error: error,
      originalError: e,
    );
  }
  
  @override
  String toString() => message;
}

/// Authentication-specific exception.
class AuthException extends ApiException {
  const AuthException({
    required super.message,
    super.statusCode,
    super.error,
    super.originalError,
  });
  
  factory AuthException.sessionExpired() {
    return const AuthException(
      message: 'Your session has expired. Please log in again.',
      statusCode: 401,
    );
  }
}

/// Validation exception with field-level errors.
class ValidationException extends ApiException {
  final Map<String, String> fieldErrors;
  
  const ValidationException({
    required super.message,
    required this.fieldErrors,
    super.statusCode = 400,
    super.error,
  });
  
  factory ValidationException.fromApiError(ApiError error) {
    final fieldErrors = <String, String>{};
    if (error.extensions != null) {
      for (final entry in error.extensions!.entries) {
        if (entry.value is String) {
          fieldErrors[entry.key] = entry.value as String;
        }
      }
    }
    return ValidationException(
      message: error.detail ?? 'Validation failed',
      fieldErrors: fieldErrors,
      error: error,
    );
  }
}

/// Permission denied exception.
class PermissionDeniedException extends ApiException {
  const PermissionDeniedException({
    super.message = 'You do not have permission to perform this action.',
    super.statusCode = 403,
    super.error,
  });
}

/// Resource not found exception.
class NotFoundException extends ApiException {
  const NotFoundException({
    super.message = 'The requested resource was not found.',
    super.statusCode = 404,
    super.error,
  });
}
