import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// API client wrapper using Dio.
/// Handles authentication headers and token refresh.
@singleton
class ApiClient {
  final SupabaseClient _supabase;
  late final Dio _dio;
  
  ApiClient(this._supabase) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.current.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    
    _dio.interceptors.add(_AuthInterceptor(_supabase));
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (o) => print('[API] $o'),
    ));
  }
  
  Dio get dio => _dio;
  
  // ---------------------------------------------------------------------------
  // HTTP Methods
  // ---------------------------------------------------------------------------
  
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.get<T>(path, queryParameters: queryParameters, options: options);
  
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);
  
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options);
  
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);
  
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) => _dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);
}

/// Interceptor that adds auth headers and handles token refresh.
class _AuthInterceptor extends Interceptor {
  final SupabaseClient _supabase;
  
  _AuthInterceptor(this._supabase);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Try to refresh token
      try {
        await _supabase.auth.refreshSession();
        
        // Retry request with new token
        final token = _supabase.auth.currentSession?.accessToken;
        if (token != null) {
          final opts = err.requestOptions;
          opts.headers['Authorization'] = 'Bearer $token';
          
          final response = await Dio().fetch(opts);
          handler.resolve(response);
          return;
        }
      } catch (_) {
        // Refresh failed, let error propagate
      }
    }
    handler.next(err);
  }
}
