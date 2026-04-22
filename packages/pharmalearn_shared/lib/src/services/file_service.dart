import 'dart:typed_data';
import 'package:supabase/supabase.dart';

/// Service for Supabase Storage operations.
/// Handles file upload, download, and signed URL generation.
class FileService {
  final SupabaseClient _supabase;

  FileService(this._supabase);

  /// Upload a file to a bucket.
  ///
  /// [bucket] - Storage bucket name
  /// [path] - File path within the bucket
  /// [fileBytes] - File content as bytes
  /// [contentType] - MIME type of the file
  /// [upsert] - If true, overwrites existing file
  Future<String> upload({
    required String bucket,
    required String path,
    required Uint8List fileBytes,
    required String contentType,
    bool upsert = false,
  }) async {
    final result = await _supabase.storage.from(bucket).uploadBinary(
      path,
      fileBytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: upsert,
      ),
    );
    return result;
  }

  /// Upload a file using base64 encoded string.
  ///
  /// [bucket] - Storage bucket name
  /// [path] - File path within the bucket
  /// [base64Data] - File content as base64 string
  /// [contentType] - MIME type of the file
  Future<String> uploadBase64({
    required String bucket,
    required String path,
    required String base64Data,
    required String contentType,
  }) async {
    final bytes = _decodeBase64(base64Data);
    return upload(
      bucket: bucket,
      path: path,
      fileBytes: bytes,
      contentType: contentType,
    );
  }

  /// Download a file as bytes.
  ///
  /// [bucket] - Storage bucket name
  /// [path] - File path within the bucket
  Future<Uint8List> download({
    required String bucket,
    required String path,
  }) async {
    return await _supabase.storage.from(bucket).download(path);
  }

  /// Generate a signed URL for temporary access.
  ///
  /// [bucket] - Storage bucket name
  /// [path] - File path within the bucket
  /// [expiresInSeconds] - URL validity duration (default 1 hour)
  Future<String> getSignedUrl({
    required String bucket,
    required String path,
    int expiresInSeconds = 3600,
  }) async {
    return await _supabase.storage.from(bucket).createSignedUrl(
      path,
      expiresInSeconds,
    );
  }

  /// Generate multiple signed URLs.
  ///
  /// [bucket] - Storage bucket name
  /// [paths] - List of file paths within the bucket
  /// [expiresInSeconds] - URL validity duration (default 1 hour)
  Future<List<SignedUrl>> getSignedUrls({
    required String bucket,
    required List<String> paths,
    int expiresInSeconds = 3600,
  }) async {
    return await _supabase.storage.from(bucket).createSignedUrls(
      paths,
      expiresInSeconds,
    );
  }

  /// Get public URL for a file (requires public bucket).
  ///
  /// [bucket] - Storage bucket name
  /// [path] - File path within the bucket
  String getPublicUrl({
    required String bucket,
    required String path,
  }) {
    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  /// Delete a file from storage.
  ///
  /// [bucket] - Storage bucket name
  /// [paths] - List of file paths to delete
  Future<List<FileObject>> delete({
    required String bucket,
    required List<String> paths,
  }) async {
    return await _supabase.storage.from(bucket).remove(paths);
  }

  /// Move/rename a file.
  ///
  /// [bucket] - Storage bucket name
  /// [fromPath] - Current file path
  /// [toPath] - New file path
  Future<String> move({
    required String bucket,
    required String fromPath,
    required String toPath,
  }) async {
    return await _supabase.storage.from(bucket).move(fromPath, toPath);
  }

  /// Copy a file.
  ///
  /// [bucket] - Storage bucket name
  /// [fromPath] - Source file path
  /// [toPath] - Destination file path
  Future<String> copy({
    required String bucket,
    required String fromPath,
    required String toPath,
  }) async {
    return await _supabase.storage.from(bucket).copy(fromPath, toPath);
  }

  /// List files in a bucket folder.
  ///
  /// [bucket] - Storage bucket name
  /// [path] - Folder path (empty string for root)
  Future<List<FileObject>> list({
    required String bucket,
    String path = '',
  }) async {
    return await _supabase.storage.from(bucket).list(path: path);
  }

  // Storage bucket constants
  static const String documentsBucket = 'documents';
  static const String coursesBucket = 'courses';
  static const String scormBucket = 'scorm-packages';
  static const String certificatesBucket = 'certificates';
  static const String avatarsBucket = 'avatars';
  static const String attachmentsBucket = 'attachments';
  static const String exportsBucket = 'exports';

  /// Upload a document file.
  Future<String> uploadDocument({
    required String documentId,
    required String fileName,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    final path = '$documentId/$fileName';
    return upload(
      bucket: documentsBucket,
      path: path,
      fileBytes: fileBytes,
      contentType: contentType,
    );
  }

  /// Get signed URL for certificate download.
  Future<String> getCertificateDownloadUrl(String certificateId) async {
    return getSignedUrl(
      bucket: certificatesBucket,
      path: '$certificateId.pdf',
      expiresInSeconds: 300, // 5 minutes
    );
  }

  /// Upload SCORM package.
  Future<String> uploadScormPackage({
    required String packageId,
    required Uint8List fileBytes,
  }) async {
    return upload(
      bucket: scormBucket,
      path: '$packageId.zip',
      fileBytes: fileBytes,
      contentType: 'application/zip',
    );
  }

  /// Get signed URL for SCORM package.
  Future<String> getScormPackageUrl(String packageId) async {
    return getSignedUrl(
      bucket: scormBucket,
      path: '$packageId.zip',
      expiresInSeconds: 3600,
    );
  }

  /// Upload employee avatar.
  Future<String> uploadAvatar({
    required String employeeId,
    required Uint8List fileBytes,
    required String contentType,
  }) async {
    final extension = _getExtension(contentType);
    return upload(
      bucket: avatarsBucket,
      path: '$employeeId.$extension',
      fileBytes: fileBytes,
      contentType: contentType,
      upsert: true,
    );
  }

  String _getExtension(String contentType) {
    return switch (contentType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'application/pdf' => 'pdf',
      _ => 'bin',
    };
  }

  Uint8List _decodeBase64(String base64Data) {
    // Remove data URL prefix if present
    final data = base64Data.contains(',')
        ? base64Data.split(',').last
        : base64Data;
    return Uint8List.fromList(
      List<int>.from(Uri.parse('data:;base64,$data').data!.contentAsBytes()),
    );
  }
}
