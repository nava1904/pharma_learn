/// Supabase service for PharmaLearn LMS
/// Provides typed access to all Supabase functionality
library;

import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration constants
class SupabaseConstants {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_SUPABASE_URL',
  );
  
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );
}

/// Main Supabase service singleton
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  bool _initialized = false;

  /// Initialize Supabase
  Future<void> initialize() async {
    if (_initialized) return;

    await Supabase.initialize(
      url: SupabaseConstants.supabaseUrl,
      anonKey: SupabaseConstants.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 2,
      ),
    );

    _initialized = true;
  }

  /// Get Supabase client
  SupabaseClient get client => Supabase.instance.client;

  /// Get current user
  User? get currentUser => client.auth.currentUser;

  /// Get current session
  Session? get currentSession => client.auth.currentSession;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Auth state stream
  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ============================================
  // AUTH METHODS
  // ============================================

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: metadata,
    );
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    return await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // ============================================
  // DATABASE METHODS
  // ============================================

  /// Get table reference
  SupabaseQueryBuilder from(String table) => client.from(table);

  /// Execute RPC function
  Future<T> rpc<T>(String functionName, {Map<String, dynamic>? params}) async {
    final response = await client.rpc(functionName, params: params);
    return response as T;
  }

  // ============================================
  // STORAGE METHODS
  // ============================================

  /// Get storage bucket
  StorageFileApi storage(String bucket) => client.storage.from(bucket);

  /// Upload file to storage
  Future<String> uploadFile({
    required String bucket,
    required String path,
    required Uint8List fileBytes,
    String? contentType,
  }) async {
    await client.storage.from(bucket).uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return client.storage.from(bucket).getPublicUrl(path);
  }

  /// Delete file from storage
  Future<void> deleteFile({
    required String bucket,
    required String path,
  }) async {
    await client.storage.from(bucket).remove([path]);
  }

  /// Get signed URL for private file
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresIn = 3600,
  }) async {
    return await client.storage.from(bucket).createSignedUrl(path, expiresIn);
  }

  // ============================================
  // REALTIME METHODS
  // ============================================

  /// Subscribe to table changes
  RealtimeChannel subscribeToTable({
    required String table,
    required void Function(PostgresChangePayload payload) callback,
    PostgresChangeEvent event = PostgresChangeEvent.all,
    String? filter,
  }) {
    final channel = client.channel('public:$table').onPostgresChanges(
      event: event,
      schema: 'public',
      table: table,
      callback: callback,
    );
    return channel.subscribe();
  }

  /// Unsubscribe from channel
  Future<void> unsubscribe(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }

  // ============================================
  // EDGE FUNCTIONS
  // ============================================

  /// Call edge function
  Future<FunctionResponse> callFunction(
    String functionName, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    return await client.functions.invoke(
      functionName,
      body: body,
      headers: headers,
    );
  }

  /// E-Signature verification
  Future<Map<String, dynamic>> verifyESignature({
    required String entityType,
    required String entityId,
    required String action,
    required String meaning,
    required String password,
    String? reasonId,
    String? customReason,
  }) async {
    final response = await callFunction(
      'esignature-verify',
      body: {
        'entityType': entityType,
        'entityId': entityId,
        'action': action,
        'meaning': meaning,
        'password': password,
        'reasonId': reasonId,
        'customReason': customReason,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'E-signature failed');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Generate certificate
  Future<Map<String, dynamic>> generateCertificate({
    required String trainingRecordId,
    String? templateId,
  }) async {
    final response = await callFunction(
      'generate-certificate',
      body: {
        'trainingRecordId': trainingRecordId,
        'templateId': templateId,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Certificate generation failed');
    }

    return response.data as Map<String, dynamic>;
  }

  /// Send notification
  Future<Map<String, dynamic>> sendNotification({
    required String templateCode,
    required String recipientId,
    required Map<String, String> variables,
    List<String>? channels,
    int? priority,
  }) async {
    final response = await callFunction(
      'send-notification',
      body: {
        'templateCode': templateCode,
        'recipientId': recipientId,
        'variables': variables,
        'channels': channels,
        'priority': priority,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Notification failed');
    }

    return response.data as Map<String, dynamic>;
  }
}
