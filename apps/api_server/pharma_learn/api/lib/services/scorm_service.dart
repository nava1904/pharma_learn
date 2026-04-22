import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:supabase/supabase.dart';
import 'package:xml/xml.dart';

/// Service for SCORM package operations: parsing, storage, manifest extraction.
///
/// SCORM 1.2 only. Handles ZIP extraction and imsmanifest.xml parsing.
class ScormService {
  final SupabaseClient _supabase;
  
  /// Storage bucket for SCORM content
  static const String bucket = 'scorm-content';
  
  ScormService(this._supabase);

  /// Processes an uploaded SCORM ZIP package.
  ///
  /// 1. Validates ZIP structure (must have imsmanifest.xml at root)
  /// 2. Parses manifest to extract launch URL, title, mastery score
  /// 3. Uploads extracted files to Storage
  /// 4. Returns parsed manifest data
  ///
  /// Throws [ScormValidationException] if package is invalid.
  Future<ScormManifest> processPackage({
    required Uint8List zipBytes,
    required String orgId,
    required String packageId,
  }) async {
    // Decode ZIP
    final archive = ZipDecoder().decodeBytes(zipBytes);
    
    // Find imsmanifest.xml (case-insensitive, can be at root or in folder)
    ArchiveFile? manifestFile;
    for (final file in archive.files) {
      final name = file.name.toLowerCase();
      if (name == 'imsmanifest.xml' || name.endsWith('/imsmanifest.xml')) {
        manifestFile = file;
        break;
      }
    }
    
    if (manifestFile == null) {
      throw ScormValidationException(
        'Invalid SCORM package: imsmanifest.xml not found',
      );
    }
    
    // Parse manifest
    final manifestXml = utf8.decode(manifestFile.content as List<int>);
    final manifest = _parseManifest(manifestXml);
    
    // Validate launch URL exists in archive
    bool launchFileFound = false;
    for (final file in archive.files) {
      if (file.name == manifest.launchUrl || 
          file.name.endsWith('/${manifest.launchUrl}')) {
        launchFileFound = true;
        break;
      }
    }
    
    if (!launchFileFound) {
      throw ScormValidationException(
        'Invalid SCORM package: launch URL "${manifest.launchUrl}" not found',
      );
    }
    
    // Upload all files to storage
    final storagePath = '$orgId/$packageId';
    for (final file in archive.files) {
      if (file.isFile) {
        final filePath = '$storagePath/${file.name}';
        final bytes = file.content as List<int>;
        
        await _supabase.storage.from(bucket).uploadBinary(
          filePath,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: _getMimeType(file.name),
            upsert: true,
          ),
        );
      }
    }
    
    return manifest;
  }

  /// Parses imsmanifest.xml and extracts SCORM 1.2 data.
  ScormManifest _parseManifest(String xml) {
    final document = XmlDocument.parse(xml);
    final root = document.rootElement;
    
    // Extract title from organizations/organization/title
    String? title;
    final organizations = root.findAllElements('organizations').firstOrNull;
    if (organizations != null) {
      final org = organizations.findAllElements('organization').firstOrNull;
      if (org != null) {
        final titleEl = org.findAllElements('title').firstOrNull;
        title = titleEl?.innerText.trim();
      }
    }
    
    // Extract launch URL from resources/resource[@scormtype='sco']
    String? launchUrl;
    final resources = root.findAllElements('resources').firstOrNull;
    if (resources != null) {
      for (final resource in resources.findAllElements('resource')) {
        // Check for scormtype or scormType (case varies in SCORM packages)
        final scormType = resource.getAttribute('scormtype') ?? 
                          resource.getAttribute('scormType') ??
                          resource.getAttribute('adlcp:scormtype') ??
                          resource.getAttribute('adlcp:scormType');
        
        if (scormType?.toLowerCase() == 'sco') {
          launchUrl = resource.getAttribute('href');
          break;
        }
      }
      
      // Fallback: first resource with href
      if (launchUrl == null) {
        final firstResource = resources.findAllElements('resource').firstOrNull;
        launchUrl = firstResource?.getAttribute('href');
      }
    }
    
    if (launchUrl == null) {
      throw ScormValidationException(
        'Invalid SCORM package: no launchable SCO found in manifest',
      );
    }
    
    // Extract mastery score from item/adlcp:masteryscore
    double? masteryScore;
    final items = root.findAllElements('item');
    for (final item in items) {
      final masteryEl = item.findAllElements('adlcp:masteryscore').firstOrNull ??
                        item.findAllElements('masteryscore').firstOrNull;
      if (masteryEl != null) {
        masteryScore = double.tryParse(masteryEl.innerText.trim());
        break;
      }
    }
    
    // Extract prerequisites
    String? prerequisites;
    for (final item in items) {
      prerequisites = item.getAttribute('prerequisites');
      if (prerequisites != null) break;
    }
    
    // Build SCO list
    final scoList = <Map<String, String>>[];
    if (resources != null) {
      for (final resource in resources.findAllElements('resource')) {
        final scormType = resource.getAttribute('scormtype') ?? 
                          resource.getAttribute('scormType') ??
                          resource.getAttribute('adlcp:scormtype');
        
        if (scormType?.toLowerCase() == 'sco') {
          scoList.add({
            'id': resource.getAttribute('identifier') ?? '',
            'href': resource.getAttribute('href') ?? '',
            'type': 'sco',
          });
        }
      }
    }
    
    return ScormManifest(
      title: title ?? 'Untitled SCORM Package',
      launchUrl: launchUrl,
      masteryScore: masteryScore,
      prerequisites: prerequisites,
      scoList: scoList,
      rawXml: xml,
    );
  }

  /// Gets a signed URL for SCORM content file.
  Future<String> getSignedUrl({
    required String orgId,
    required String packageId,
    required String filePath,
    int expiresInSeconds = 3600,
  }) async {
    final fullPath = '$orgId/$packageId/$filePath';
    final result = await _supabase.storage
        .from(bucket)
        .createSignedUrl(fullPath, expiresInSeconds);
    return result;
  }

  /// Gets signed URLs for the launch page.
  Future<ScormLaunchUrls> getLaunchUrls({
    required String orgId,
    required String packageId,
    required String launchUrl,
    int expiresInSeconds = 3600,
  }) async {
    // Create signed URL for launch file
    final launchSignedUrl = await getSignedUrl(
      orgId: orgId,
      packageId: packageId,
      filePath: launchUrl,
      expiresInSeconds: expiresInSeconds,
    );
    
    // For SCORM, we need a base URL that works for relative paths
    final baseUrl = launchSignedUrl.substring(
      0, 
      launchSignedUrl.lastIndexOf('/') + 1,
    );
    
    return ScormLaunchUrls(
      launchUrl: launchSignedUrl,
      baseUrl: baseUrl,
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
    );
  }

  /// Deletes all content for a SCORM package from storage.
  Future<void> deletePackageContent({
    required String orgId,
    required String packageId,
  }) async {
    final path = '$orgId/$packageId';
    
    // List all files in package directory
    final files = await _supabase.storage.from(bucket).list(path: path);
    
    if (files.isNotEmpty) {
      final paths = files.map((f) => '$path/${f.name}').toList();
      await _supabase.storage.from(bucket).remove(paths);
    }
  }

  /// Returns MIME type for common SCORM content files.
  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'html' || 'htm' => 'text/html',
      'js' => 'application/javascript',
      'css' => 'text/css',
      'xml' => 'application/xml',
      'json' => 'application/json',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      'mp3' => 'audio/mpeg',
      'mp4' => 'video/mp4',
      'swf' => 'application/x-shockwave-flash',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }
}

/// Parsed SCORM manifest data.
class ScormManifest {
  final String title;
  final String launchUrl;
  final double? masteryScore;
  final String? prerequisites;
  final List<Map<String, String>> scoList;
  final String rawXml;

  const ScormManifest({
    required this.title,
    required this.launchUrl,
    this.masteryScore,
    this.prerequisites,
    required this.scoList,
    required this.rawXml,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'launch_url': launchUrl,
    'mastery_score': masteryScore,
    'prerequisites': prerequisites,
    'sco_list': scoList,
  };
}

/// Signed URLs for SCORM launch.
class ScormLaunchUrls {
  final String launchUrl;
  final String baseUrl;
  final DateTime expiresAt;

  const ScormLaunchUrls({
    required this.launchUrl,
    required this.baseUrl,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
    'launch_url': launchUrl,
    'base_url': baseUrl,
    'expires_at': expiresAt.toIso8601String(),
  };
}

/// Exception thrown when SCORM package validation fails.
class ScormValidationException implements Exception {
  final String message;
  const ScormValidationException(this.message);
  
  @override
  String toString() => 'ScormValidationException: $message';
}
