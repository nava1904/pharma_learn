import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../api/api_client.dart';
import 'offline_cache_service.dart';

/// Service that syncs offline-cached data when connectivity is restored.
/// 
/// Handles:
/// - Check-in records (server-wins conflict resolution)
/// - SCORM CMI commits (sequential replay)
@singleton
class OfflineSyncService {
  final OfflineCacheService _cache;
  final ApiClient _api;
  final Connectivity _connectivity;
  
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;
  
  OfflineSyncService(this._cache, this._api, this._connectivity);
  
  /// Start listening to connectivity changes.
  void startMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    
    // Initial sync if online
    _checkAndSync();
  }
  
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }
  
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => 
        r == ConnectivityResult.wifi || 
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
    
    if (isOnline) {
      _checkAndSync();
    }
  }
  
  Future<void> _checkAndSync() async {
    final results = await _connectivity.checkConnectivity();
    final isOnline = results.any((r) => 
        r == ConnectivityResult.wifi || 
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
    
    if (isOnline) {
      await syncAll();
    }
  }
  
  /// Manually trigger sync of all pending data.
  Future<SyncResult> syncAll() async {
    if (_isSyncing) {
      return SyncResult(
        checkInsAttempted: 0,
        checkInsSynced: 0,
        scormCommitsAttempted: 0,
        scormCommitsSynced: 0,
        errors: ['Sync already in progress'],
      );
    }
    
    _isSyncing = true;
    final errors = <String>[];
    
    int checkInsAttempted = 0;
    int checkInsSynced = 0;
    int scormAttempted = 0;
    int scormSynced = 0;
    
    try {
      // 1. Sync check-ins (server-wins)
      final checkIns = _cache.getPendingCheckIns();
      checkInsAttempted = checkIns.length;
      
      for (final checkIn in checkIns) {
        try {
          final sessionId = checkIn['session_id'] as String;
          final employeeId = checkIn['employee_id'] as String;
          
          // Check if server already has this record
          final exists = await _checkServerHasCheckIn(sessionId, employeeId);
          
          if (exists) {
            // Server-wins: discard local record
            await _cache.deleteCheckIn(sessionId, employeeId);
            debugPrint('[Sync] Check-in discarded (server-wins): $sessionId');
          } else {
            // Sync to server
            await _syncCheckIn(checkIn);
            await _cache.markCheckInSynced(sessionId, employeeId);
            checkInsSynced++;
            debugPrint('[Sync] Check-in synced: $sessionId');
          }
        } catch (e) {
          errors.add('Check-in sync failed: $e');
        }
      }
      
      // 2. Sync SCORM CMI commits (sequential)
      final scormCommits = _cache.getAllPendingScormCmis();
      scormAttempted = scormCommits.length;
      
      for (final commit in scormCommits) {
        try {
          final sessionId = commit['session_id'] as String;
          final packageId = commit['package_id'] as String;
          final seqNum = commit['sequence_number'] as int;
          final cmiData = Map<String, dynamic>.from(commit['cmi_data'] as Map);
          
          await _syncScormCmi(packageId, sessionId, cmiData);
          await _cache.markScormCmiSynced(sessionId, seqNum);
          scormSynced++;
          debugPrint('[Sync] SCORM CMI synced: $sessionId #$seqNum');
        } catch (e) {
          // Stop on error to maintain sequence order
          errors.add('SCORM CMI sync failed: $e');
          break;
        }
      }
      
      // Cleanup old synced data
      await _cache.cleanupSyncedScormCmis();
      
    } finally {
      _isSyncing = false;
    }
    
    return SyncResult(
      checkInsAttempted: checkInsAttempted,
      checkInsSynced: checkInsSynced,
      scormCommitsAttempted: scormAttempted,
      scormCommitsSynced: scormSynced,
      errors: errors,
    );
  }
  
  Future<bool> _checkServerHasCheckIn(String sessionId, String employeeId) async {
    try {
      final response = await _api.get(
        '/v1/train/sessions/$sessionId/attendance',
        queryParameters: {'employee_id': employeeId},
      );
      final data = response.data as Map<String, dynamic>;
      final attendance = data['data']?['attendance'] ?? data['attendance'];
      return attendance != null && (attendance as List).isNotEmpty;
    } catch (e) {
      // If we can't check, assume it doesn't exist
      return false;
    }
  }
  
  Future<void> _syncCheckIn(Map<String, dynamic> checkIn) async {
    final sessionId = checkIn['session_id'] as String;
    await _api.post(
      '/v1/train/sessions/$sessionId/check-in',
      data: {
        'qr_token': checkIn['qr_token'],
        'offline_checked_in_at': checkIn['checked_in_at'],
      },
    );
  }
  
  Future<void> _syncScormCmi(
    String packageId,
    String sessionId,
    Map<String, dynamic> cmiData,
  ) async {
    await _api.post(
      '/v1/scorm/$packageId/commit',
      data: {
        'session_id': sessionId,
        'cmi_data': cmiData,
      },
    );
  }
}

/// Result of a sync operation.
class SyncResult {
  final int checkInsAttempted;
  final int checkInsSynced;
  final int scormCommitsAttempted;
  final int scormCommitsSynced;
  final List<String> errors;
  
  SyncResult({
    required this.checkInsAttempted,
    required this.checkInsSynced,
    required this.scormCommitsAttempted,
    required this.scormCommitsSynced,
    required this.errors,
  });
  
  bool get hasErrors => errors.isNotEmpty;
  
  int get totalAttempted => checkInsAttempted + scormCommitsAttempted;
  int get totalSynced => checkInsSynced + scormCommitsSynced;
  
  @override
  String toString() {
    return 'SyncResult(checkIns: $checkInsSynced/$checkInsAttempted, '
        'scorm: $scormCommitsSynced/$scormCommitsAttempted, '
        'errors: ${errors.length})';
  }
}
