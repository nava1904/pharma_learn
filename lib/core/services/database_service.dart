import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Database service for Supabase operations
class DatabaseService {
  static final _client = SupabaseService.client;

  /// Get a reference to a table
  static SupabaseQueryBuilder from(String table) {
    return _client.from(table);
  }

  /// Select data from a table
  /// Example: DatabaseService.select('users', columns: 'id, name, email')
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String columns = '*',
  }) async {
    final response = await _client.from(table).select(columns);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Insert data into a table
  /// Example: DatabaseService.insert('users', {'name': 'John', 'email': 'john@example.com'})
  static Future<Map<String, dynamic>?> insert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.from(table).insert(data).select().single();
    return response;
  }

  /// Update data in a table
  /// Example: DatabaseService.update('users', {'name': 'Jane'}, 'id', 1)
  static Future<List<Map<String, dynamic>>> update(
    String table,
    Map<String, dynamic> data,
    String column,
    dynamic value,
  ) async {
    final response = await _client.from(table).update(data).eq(column, value).select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Delete data from a table
  /// Example: DatabaseService.delete('users', 'id', 1)
  static Future<void> delete(
    String table,
    String column,
    dynamic value,
  ) async {
    await _client.from(table).delete().eq(column, value);
  }

  /// Upload a file to storage
  static Future<String> uploadFile(
    String bucket,
    String path,
    Uint8List fileBytes,
  ) async {
    await _client.storage.from(bucket).uploadBinary(path, fileBytes);
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Get public URL for a file
  static String getPublicUrl(String bucket, String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}
