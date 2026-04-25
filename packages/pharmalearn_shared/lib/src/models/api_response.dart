import 'dart:convert';

import 'package:relic/relic.dart';

import 'error_response.dart';
import 'pagination.dart';

/// Standard API response envelope: `{data, meta, error}`.
class ApiResponse<T> {
  final T? data;
  final Map<String, dynamic>? meta;
  final ErrorResponse? error;
  final int _statusCode;

  const ApiResponse._({
    this.data,
    this.meta,
    this.error,
    required int statusCode,
  }) : _statusCode = statusCode;

  /// 200 OK response with [data].
  factory ApiResponse.ok(T data) => ApiResponse._(
        data: data,
        statusCode: 200,
      );

  /// 201 Created response with [data].
  factory ApiResponse.created(T data) => ApiResponse._(
        data: data,
        statusCode: 201,
      );

  /// 204 No Content response.
  factory ApiResponse.noContent() => ApiResponse._(
        statusCode: 204,
      );

  /// 200 OK response with [data] and [pagination] in meta.
  factory ApiResponse.paginated(T data, Pagination pagination) => ApiResponse._(
        data: data,
        meta: {'pagination': pagination.toJson()},
        statusCode: 200,
      );

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{};
    if (data != null) body['data'] = data;
    if (meta != null) body['meta'] = meta;
    if (error != null) body['error'] = error!.toJson();
    return body;
  }

  /// Returns a Relic [Response] with a JSON body and the appropriate status code.
  Response toResponse() {
    if (_statusCode == 204) {
      return Response(204);
    }

    return Response(
      _statusCode,
      body: Body.fromString(
        jsonEncode(toJson()),
        mimeType: MimeType.json,
      ),
    );
  }
}
