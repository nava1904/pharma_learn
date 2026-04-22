/// Standardized API response wrapper.
/// Matches the {data, meta, error} envelope from the server.
class ApiResponse<T> {
  final T? data;
  final Map<String, dynamic>? meta;
  final ApiError? error;
  
  const ApiResponse({
    this.data,
    this.meta,
    this.error,
  });
  
  bool get isSuccess => error == null;
  bool get isError => error != null;
  
  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJson,
  ) {
    return ApiResponse(
      data: json['data'] != null && fromJson != null 
          ? fromJson(json['data']) 
          : json['data'] as T?,
      meta: json['meta'] as Map<String, dynamic>?,
      error: json['error'] != null 
          ? ApiError.fromJson(json['error']) 
          : null,
    );
  }
}

/// API error details following RFC 7807.
class ApiError {
  final String type;
  final String title;
  final int status;
  final String? detail;
  final String? instance;
  final Map<String, dynamic>? extensions;
  
  const ApiError({
    required this.type,
    required this.title,
    required this.status,
    this.detail,
    this.instance,
    this.extensions,
  });
  
  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      type: json['type'] ?? 'about:blank',
      title: json['title'] ?? 'Unknown Error',
      status: json['status'] ?? 500,
      detail: json['detail'],
      instance: json['instance'],
      extensions: Map<String, dynamic>.from(json)
        ..remove('type')
        ..remove('title')
        ..remove('status')
        ..remove('detail')
        ..remove('instance'),
    );
  }
  
  @override
  String toString() => detail ?? title;
}

/// Pagination metadata.
class Pagination {
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  
  const Pagination({
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });
  
  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      page: json['page'] ?? 1,
      perPage: json['per_page'] ?? 20,
      total: json['total'] ?? 0,
      totalPages: json['total_pages'] ?? 0,
    );
  }
  
  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;
}
