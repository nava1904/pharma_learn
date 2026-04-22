import 'package:hive_flutter/hive_flutter.dart';
import 'package:injectable/injectable.dart';

/// Offline cache service using Hive.
/// 
/// Implements the 4 caching scenarios from plan.md:
/// 1. Session check-in - Until synced, server-wins conflict
/// 2. Dashboard data - 30 min TTL, stale-while-revalidate
/// 3. Viewed PDFs - LRU 20 docs
/// 4. SCORM CMI commits - Until synced, sequential order
@singleton
class OfflineCacheService {
  static const String _checkInBox = 'checkin_cache';
  static const String _dashboardBox = 'dashboard_cache';
  static const String _pdfBox = 'pdf_cache';
  static const String _scormCmiBox = 'scorm_cmi_cache';
  static const String _metaBox = 'cache_meta';
  
  late Box<Map> _checkInCache;
  late Box<Map> _dashboardCache;
  late Box<Map> _pdfCache;
  late Box<Map> _scormCmiCache;
  late Box<Map> _metaCache;
  
  bool _initialized = false;
  
  /// Initialize all Hive boxes.
  Future<void> initialize() async {
    if (_initialized) return;
    
    _checkInCache = await Hive.openBox<Map>(_checkInBox);
    _dashboardCache = await Hive.openBox<Map>(_dashboardBox);
    _pdfCache = await Hive.openBox<Map>(_pdfBox);
    _scormCmiCache = await Hive.openBox<Map>(_scormCmiBox);
    _metaCache = await Hive.openBox<Map>(_metaBox);
    
    _initialized = true;
  }
  
  // ---------------------------------------------------------------------------
  // 1. SESSION CHECK-IN CACHE
  // Cache key: checkin_{sessionId}_{employeeId}
  // Strategy: Server-wins - if server has record, discard cached
  // ---------------------------------------------------------------------------
  
  Future<void> cacheCheckIn({
    required String sessionId,
    required String employeeId,
    required DateTime checkedInAt,
    String? qrToken,
  }) async {
    final key = 'checkin_${sessionId}_$employeeId';
    await _checkInCache.put(key, {
      'session_id': sessionId,
      'employee_id': employeeId,
      'checked_in_at': checkedInAt.toIso8601String(),
      'qr_token': qrToken,
      'cached_at': DateTime.now().toIso8601String(),
      'synced': false,
    });
  }
  
  List<Map<String, dynamic>> getPendingCheckIns() {
    return _checkInCache.values
        .where((m) => m['synced'] != true)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
  
  Future<void> markCheckInSynced(String sessionId, String employeeId) async {
    final key = 'checkin_${sessionId}_$employeeId';
    final entry = _checkInCache.get(key);
    if (entry != null) {
      entry['synced'] = true;
      await _checkInCache.put(key, entry);
    }
  }
  
  Future<void> deleteCheckIn(String sessionId, String employeeId) async {
    final key = 'checkin_${sessionId}_$employeeId';
    await _checkInCache.delete(key);
  }
  
  // ---------------------------------------------------------------------------
  // 2. DASHBOARD DATA CACHE
  // Cache key: dashboard_{employeeId}
  // TTL: 30 minutes
  // Strategy: Stale-while-revalidate
  // ---------------------------------------------------------------------------
  
  static const Duration _dashboardTtl = Duration(minutes: 30);
  
  Future<void> cacheDashboard(String employeeId, Map<String, dynamic> data) async {
    final key = 'dashboard_$employeeId';
    await _dashboardCache.put(key, {
      'data': data,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }
  
  Map<String, dynamic>? getDashboard(String employeeId) {
    final key = 'dashboard_$employeeId';
    final entry = _dashboardCache.get(key);
    if (entry == null) return null;
    return Map<String, dynamic>.from(entry['data'] as Map);
  }
  
  bool isDashboardStale(String employeeId) {
    final key = 'dashboard_$employeeId';
    final entry = _dashboardCache.get(key);
    if (entry == null) return true;
    
    final cachedAt = DateTime.parse(entry['cached_at'] as String);
    return DateTime.now().difference(cachedAt) > _dashboardTtl;
  }
  
  DateTime? getDashboardCacheTime(String employeeId) {
    final key = 'dashboard_$employeeId';
    final entry = _dashboardCache.get(key);
    if (entry == null) return null;
    return DateTime.parse(entry['cached_at'] as String);
  }
  
  // ---------------------------------------------------------------------------
  // 3. PDF CACHE (LRU 20 docs)
  // Cache key: pdf_{documentId}_{version}
  // Strategy: LRU eviction, keep 20 most recent
  // ---------------------------------------------------------------------------
  
  static const int _maxPdfCacheSize = 20;
  
  Future<void> cachePdf({
    required String documentId,
    required String version,
    required String filePath,
    required String title,
  }) async {
    final key = 'pdf_${documentId}_$version';
    
    // Update access order in meta
    await _updatePdfAccessOrder(key);
    
    // Evict oldest if over limit
    await _evictOldestPdfs();
    
    await _pdfCache.put(key, {
      'document_id': documentId,
      'version': version,
      'file_path': filePath,
      'title': title,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }
  
  Map<String, dynamic>? getPdf(String documentId, String version) {
    final key = 'pdf_${documentId}_$version';
    final entry = _pdfCache.get(key);
    if (entry == null) return null;
    
    // Update access time
    _updatePdfAccessOrder(key);
    
    return Map<String, dynamic>.from(entry);
  }
  
  List<Map<String, dynamic>> getCachedPdfs() {
    return _pdfCache.values
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
  
  Future<void> _updatePdfAccessOrder(String key) async {
    final meta = _metaCache.get('pdf_access_order') ?? {'order': <String>[]};
    final order = List<String>.from(meta['order'] as List);
    
    order.remove(key);
    order.insert(0, key); // Most recent first
    
    await _metaCache.put('pdf_access_order', {'order': order});
  }
  
  Future<void> _evictOldestPdfs() async {
    final meta = _metaCache.get('pdf_access_order') ?? {'order': <String>[]};
    final order = List<String>.from(meta['order'] as List);
    
    while (order.length > _maxPdfCacheSize) {
      final oldestKey = order.removeLast();
      await _pdfCache.delete(oldestKey);
    }
    
    await _metaCache.put('pdf_access_order', {'order': order});
  }
  
  // ---------------------------------------------------------------------------
  // 4. SCORM CMI COMMITS CACHE
  // Cache key: scorm_cmi_{sessionId}_{sequenceNumber}
  // Strategy: Buffer until synced, replay in sequence order
  // ---------------------------------------------------------------------------
  
  Future<void> cacheScormCmi({
    required String sessionId,
    required String packageId,
    required int sequenceNumber,
    required Map<String, dynamic> cmiData,
  }) async {
    final key = 'scorm_cmi_${sessionId}_$sequenceNumber';
    await _scormCmiCache.put(key, {
      'session_id': sessionId,
      'package_id': packageId,
      'sequence_number': sequenceNumber,
      'cmi_data': cmiData,
      'cached_at': DateTime.now().toIso8601String(),
      'synced': false,
    });
  }
  
  /// Gets pending SCORM commits for a session, ordered by sequence.
  List<Map<String, dynamic>> getPendingScormCmis(String sessionId) {
    final commits = _scormCmiCache.values
        .where((m) => m['session_id'] == sessionId && m['synced'] != true)
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    
    commits.sort((a, b) => 
        (a['sequence_number'] as int).compareTo(b['sequence_number'] as int));
    
    return commits;
  }
  
  /// Gets all pending SCORM commits across all sessions.
  List<Map<String, dynamic>> getAllPendingScormCmis() {
    return _scormCmiCache.values
        .where((m) => m['synced'] != true)
        .map((m) => Map<String, dynamic>.from(m))
        .toList()
      ..sort((a, b) {
        // Sort by session, then by sequence
        final sessionCmp = (a['session_id'] as String)
            .compareTo(b['session_id'] as String);
        if (sessionCmp != 0) return sessionCmp;
        return (a['sequence_number'] as int)
            .compareTo(b['sequence_number'] as int);
      });
  }
  
  Future<void> markScormCmiSynced(String sessionId, int sequenceNumber) async {
    final key = 'scorm_cmi_${sessionId}_$sequenceNumber';
    final entry = _scormCmiCache.get(key);
    if (entry != null) {
      entry['synced'] = true;
      await _scormCmiCache.put(key, entry);
    }
  }
  
  Future<void> deleteScormCmi(String sessionId, int sequenceNumber) async {
    final key = 'scorm_cmi_${sessionId}_$sequenceNumber';
    await _scormCmiCache.delete(key);
  }
  
  /// Clears all synced SCORM commits older than 24 hours.
  Future<void> cleanupSyncedScormCmis() async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final keysToDelete = <String>[];
    
    for (final key in _scormCmiCache.keys) {
      final entry = _scormCmiCache.get(key);
      if (entry != null && entry['synced'] == true) {
        final cachedAt = DateTime.parse(entry['cached_at'] as String);
        if (cachedAt.isBefore(cutoff)) {
          keysToDelete.add(key as String);
        }
      }
    }
    
    for (final key in keysToDelete) {
      await _scormCmiCache.delete(key);
    }
  }
  
  // ---------------------------------------------------------------------------
  // GENERAL UTILITIES
  // ---------------------------------------------------------------------------
  
  /// Clears all caches. Use with caution.
  Future<void> clearAll() async {
    await _checkInCache.clear();
    await _dashboardCache.clear();
    await _pdfCache.clear();
    await _scormCmiCache.clear();
    await _metaCache.clear();
  }
  
  /// Gets total cache size for diagnostics.
  Map<String, int> getCacheSizes() {
    return {
      'check_ins': _checkInCache.length,
      'dashboards': _dashboardCache.length,
      'pdfs': _pdfCache.length,
      'scorm_cmis': _scormCmiCache.length,
    };
  }
}
