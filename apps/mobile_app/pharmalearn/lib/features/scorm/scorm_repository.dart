import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for SCORM package and session operations.
///
/// Handles API communication and offline CMI commit buffering.
class ScormRepository {
  final SupabaseClient _supabase;
  
  static const String _bufferBoxName = 'scorm_offline_commits';
  Box<Map>? _offlineBuffer;
  Timer? _syncTimer;
  bool _isSyncing = false;
  
  ScormRepository(this._supabase);
  
  /// Initialize offline buffer and start sync timer.
  Future<void> initialize() async {
    if (!Hive.isBoxOpen(_bufferBoxName)) {
      _offlineBuffer = await Hive.openBox<Map>(_bufferBoxName);
    } else {
      _offlineBuffer = Hive.box<Map>(_bufferBoxName);
    }
    
    // Start periodic sync
    _syncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => syncBufferedCommits(),
    );
    
    // Initial sync
    syncBufferedCommits();
  }
  
  void dispose() {
    _syncTimer?.cancel();
  }
  
  // ---------------------------------------------------------------------------
  // PACKAGES
  // ---------------------------------------------------------------------------
  
  /// Lists SCORM packages with optional filters.
  Future<ScormPackageListResult> listPackages({
    String? courseId,
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (courseId != null) params['course_id'] = courseId;
    if (status != null) params['status'] = status;
    
    final response = await _supabase.functions.invoke(
      'v1/scorm/packages',
      method: HttpMethod.get,
      queryParameters: params,
    );
    
    if (response.status != 200) {
      throw ScormException('Failed to list packages: ${response.data}');
    }
    
    final data = response.data as Map<String, dynamic>;
    return ScormPackageListResult.fromJson(data);
  }
  
  /// Gets a single SCORM package.
  Future<ScormPackage> getPackage(String packageId) async {
    final response = await _supabase.functions.invoke(
      'v1/scorm/$packageId',
      method: HttpMethod.get,
    );
    
    if (response.status != 200) {
      throw ScormException('Failed to get package: ${response.data}');
    }
    
    final data = response.data as Map<String, dynamic>;
    return ScormPackage.fromJson(data['package']);
  }
  
  // ---------------------------------------------------------------------------
  // LAUNCH
  // ---------------------------------------------------------------------------
  
  /// Gets launch parameters for a SCORM package.
  /// Creates or resumes a session for the current user.
  Future<ScormLaunchResult> launch(
    String packageId, {
    String? trainingRecordId,
  }) async {
    final params = <String, String>{};
    if (trainingRecordId != null) {
      params['training_record_id'] = trainingRecordId;
    }
    
    final response = await _supabase.functions.invoke(
      'v1/scorm/$packageId/launch',
      method: HttpMethod.get,
      queryParameters: params,
    );
    
    if (response.status != 200) {
      throw ScormException('Failed to launch: ${response.data}');
    }
    
    final data = response.data as Map<String, dynamic>;
    return ScormLaunchResult.fromJson(data);
  }
  
  // ---------------------------------------------------------------------------
  // COMMIT
  // ---------------------------------------------------------------------------
  
  /// Commits CMI data for a SCORM session.
  /// Returns true if successful.
  Future<bool> commit({
    required String packageId,
    required String sessionId,
    required Map<String, dynamic> cmiData,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'v1/scorm/$packageId/commit',
        method: HttpMethod.post,
        body: {
          'session_id': sessionId,
          'cmi_data': cmiData,
        },
      );
      
      return response.status == 200;
    } catch (e) {
      debugPrint('[ScormRepository] Commit failed: $e');
      return false;
    }
  }
  
  // ---------------------------------------------------------------------------
  // PROGRESS
  // ---------------------------------------------------------------------------
  
  /// Gets progress for a SCORM package.
  Future<ScormProgress> getProgress(String packageId) async {
    final response = await _supabase.functions.invoke(
      'v1/scorm/$packageId/progress',
      method: HttpMethod.get,
    );
    
    if (response.status != 200) {
      throw ScormException('Failed to get progress: ${response.data}');
    }
    
    final data = response.data as Map<String, dynamic>;
    return ScormProgress.fromJson(data);
  }
  
  // ---------------------------------------------------------------------------
  // OFFLINE SYNC
  // ---------------------------------------------------------------------------
  
  /// Syncs buffered CMI commits to server.
  Future<int> syncBufferedCommits() async {
    if (_isSyncing || _offlineBuffer == null) return 0;
    
    _isSyncing = true;
    int synced = 0;
    
    try {
      final keys = _offlineBuffer!.keys.toList();
      
      for (final key in keys) {
        final entry = _offlineBuffer!.get(key);
        if (entry == null) continue;
        
        final sessionId = entry['session_id'] as String?;
        final packageId = entry['package_id'] as String?;
        final cmiData = entry['cmi_data'] as Map<String, dynamic>?;
        
        if (sessionId == null || packageId == null || cmiData == null) {
          await _offlineBuffer!.delete(key);
          continue;
        }
        
        final success = await commit(
          packageId: packageId,
          sessionId: sessionId,
          cmiData: cmiData,
        );
        
        if (success) {
          await _offlineBuffer!.delete(key);
          synced++;
        }
      }
    } catch (e) {
      debugPrint('[ScormRepository] Sync error: $e');
    } finally {
      _isSyncing = false;
    }
    
    if (synced > 0) {
      debugPrint('[ScormRepository] Synced $synced buffered commits');
    }
    
    return synced;
  }
  
  /// Gets count of buffered commits pending sync.
  int get pendingCommits => _offlineBuffer?.length ?? 0;
}

// ---------------------------------------------------------------------------
// MODELS
// ---------------------------------------------------------------------------

class ScormPackage {
  final String id;
  final String? courseId;
  final String? title;
  final String? fileName;
  final String scormVersion;
  final String status;
  final int? fileSizeBytes;
  final double? masteryThreshold;
  final Map<String, dynamic>? manifestJson;
  final DateTime? createdAt;

  ScormPackage({
    required this.id,
    this.courseId,
    this.title,
    this.fileName,
    required this.scormVersion,
    required this.status,
    this.fileSizeBytes,
    this.masteryThreshold,
    this.manifestJson,
    this.createdAt,
  });

  factory ScormPackage.fromJson(Map<String, dynamic> json) => ScormPackage(
    id: json['id'],
    courseId: json['course_id'],
    title: json['title'],
    fileName: json['file_name'],
    scormVersion: json['scorm_version'] ?? '1.2',
    status: json['status'] ?? 'processing',
    fileSizeBytes: json['file_size_bytes'],
    masteryThreshold: (json['mastery_threshold'] as num?)?.toDouble(),
    manifestJson: json['manifest_json'],
    createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : null,
  );
}

class ScormPackageListResult {
  final List<ScormPackage> packages;
  final int total;
  final int page;
  final int perPage;

  ScormPackageListResult({
    required this.packages,
    required this.total,
    required this.page,
    required this.perPage,
  });

  factory ScormPackageListResult.fromJson(Map<String, dynamic> json) {
    final packagesJson = json['packages'] as List? ?? [];
    return ScormPackageListResult(
      packages: packagesJson.map((p) => ScormPackage.fromJson(p)).toList(),
      total: json['pagination']?['total'] ?? packagesJson.length,
      page: json['pagination']?['page'] ?? 1,
      perPage: json['pagination']?['per_page'] ?? 20,
    );
  }
}

class ScormLaunchResult {
  final String sessionId;
  final int attemptNumber;
  final bool isNewSession;
  final String status;
  final Map<String, dynamic> cmiData;
  final String launchUrl;
  final String baseUrl;
  final DateTime expiresAt;
  final Map<String, dynamic>? packageInfo;

  ScormLaunchResult({
    required this.sessionId,
    required this.attemptNumber,
    required this.isNewSession,
    required this.status,
    required this.cmiData,
    required this.launchUrl,
    required this.baseUrl,
    required this.expiresAt,
    this.packageInfo,
  });

  factory ScormLaunchResult.fromJson(Map<String, dynamic> json) {
    final launch = json['launch'] as Map<String, dynamic>? ?? {};
    return ScormLaunchResult(
      sessionId: json['session_id'],
      attemptNumber: json['attempt_number'] ?? 1,
      isNewSession: json['is_new_session'] ?? true,
      status: json['status'] ?? 'not_attempted',
      cmiData: json['cmi_data'] ?? {},
      launchUrl: launch['launch_url'] ?? '',
      baseUrl: launch['base_url'] ?? '',
      expiresAt: launch['expires_at'] != null
          ? DateTime.parse(launch['expires_at'])
          : DateTime.now().add(const Duration(hours: 1)),
      packageInfo: json['package'],
    );
  }
}

class ScormProgress {
  final String packageId;
  final int attempts;
  final double? bestScore;
  final bool hasCompleted;
  final List<ScormSession> sessions;

  ScormProgress({
    required this.packageId,
    required this.attempts,
    this.bestScore,
    required this.hasCompleted,
    required this.sessions,
  });

  factory ScormProgress.fromJson(Map<String, dynamic> json) {
    final sessionsJson = json['sessions'] as List? ?? [];
    return ScormProgress(
      packageId: json['package_id'],
      attempts: json['attempts'] ?? 0,
      bestScore: (json['best_score'] as num?)?.toDouble(),
      hasCompleted: json['has_completed'] ?? false,
      sessions: sessionsJson.map((s) => ScormSession.fromJson(s)).toList(),
    );
  }
}

class ScormSession {
  final String id;
  final int attemptNumber;
  final String status;
  final double? scoreRaw;
  final String? totalTime;
  final DateTime? createdAt;
  final DateTime? lastAccessedAt;
  final DateTime? completedAt;

  ScormSession({
    required this.id,
    required this.attemptNumber,
    required this.status,
    this.scoreRaw,
    this.totalTime,
    this.createdAt,
    this.lastAccessedAt,
    this.completedAt,
  });

  factory ScormSession.fromJson(Map<String, dynamic> json) => ScormSession(
    id: json['id'],
    attemptNumber: json['attempt_number'] ?? 1,
    status: json['status'] ?? 'not_attempted',
    scoreRaw: (json['score_raw'] as num?)?.toDouble(),
    totalTime: json['total_time'],
    createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at']) 
        : null,
    lastAccessedAt: json['last_accessed_at'] != null 
        ? DateTime.parse(json['last_accessed_at']) 
        : null,
    completedAt: json['completed_at'] != null 
        ? DateTime.parse(json['completed_at']) 
        : null,
  );
}

class ScormException implements Exception {
  final String message;
  const ScormException(this.message);
  
  @override
  String toString() => 'ScormException: $message';
}
