import 'package:supabase/supabase.dart';

/// User-scoped Supabase client that uses the user's JWT token
/// for RLS (Row Level Security) enforcement.
class SupabaseUserClient {
  final SupabaseClient _client;

  SupabaseUserClient._(this._client);

  /// Create a user-scoped client with the provided JWT token.
  ///
  /// [url] - Supabase project URL
  /// [anonKey] - Supabase anonymous key
  /// [accessToken] - User's JWT access token
  static SupabaseUserClient create({
    required String url,
    required String anonKey,
    required String accessToken,
  }) {
    final client = SupabaseClient(
      url,
      anonKey,
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );
    return SupabaseUserClient._(client);
  }

  /// Get the underlying Supabase client.
  SupabaseClient get client => _client;

  /// Access the database with RLS applied.
  SupabaseQueryBuilder from(String table) => _client.from(table);

  /// Access storage with user context.
  SupabaseStorageClient get storage => _client.storage;

  /// Access realtime with user context.
  RealtimeClient get realtime => _client.realtime;

  /// Invoke an edge function with user context.
  Future<FunctionResponse> invokeFunction(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    return _client.functions.invoke(
      functionName,
      body: body,
      headers: headers,
    );
  }

  /// Call an RPC function with user context.
  Future<dynamic> rpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) {
    return _client.rpc(functionName, params: params);
  }
}

/// Factory for creating user-scoped Supabase clients.
class SupabaseUserClientFactory {
  final String _url;
  final String _anonKey;

  SupabaseUserClientFactory({
    required String url,
    required String anonKey,
  }) : _url = url,
       _anonKey = anonKey;

  /// Create a new user-scoped client for the given access token.
  SupabaseUserClient forToken(String accessToken) {
    return SupabaseUserClient.create(
      url: _url,
      anonKey: _anonKey,
      accessToken: accessToken,
    );
  }

  /// Create from environment variables.
  factory SupabaseUserClientFactory.fromEnvironment() {
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'http://localhost:54321',
    );
    const anonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );

    if (anonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY environment variable is not set');
    }

    return SupabaseUserClientFactory(url: url, anonKey: anonKey);
  }
}
