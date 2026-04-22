import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../core/api/api_client.dart';
import '../core/cache/offline_cache_service.dart';

part 'self_learning_store.g.dart';

/// Store for self-learning / SCORM content.
/// Handles SCORM launch, CMI progress commits, offline caching.
@singleton
class SelfLearningStore = _SelfLearningStoreBase with _$SelfLearningStore;

abstract class _SelfLearningStoreBase with Store {
  final ApiClient _api;
  final OfflineCacheService _cache;
  
  _SelfLearningStoreBase(this._api, this._cache);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  ScormSession? currentSession;
  
  @observable
  String? launchUrl;
  
  @observable
  ObservableMap<String, dynamic> cmiData = ObservableMap<String, dynamic>();
  
  @observable
  bool isSyncing = false;
  
  @observable
  int pendingCommits = 0;
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  bool get hasActiveSession => currentSession != null;
  
  @computed
  String get lessonStatus => cmiData['cmi.core.lesson_status'] as String? ?? 'not attempted';
  
  @computed
  double get progress {
    // Parse progress from CMI data if available
    final progressStr = cmiData['cmi.progress_measure'] as String?;
    if (progressStr != null) {
      return double.tryParse(progressStr) ?? 0.0;
    }
    return 0.0;
  }
  
  @computed
  int? get scoreRaw {
    final score = cmiData['cmi.core.score.raw'];
    if (score == null) return null;
    return int.tryParse(score.toString());
  }
  
  @computed
  bool get isCompleted => lessonStatus == 'completed' || lessonStatus == 'passed';
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<bool> launchContent(String scormPackageId) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final response = await _api.post('/v1/scorm/$scormPackageId/launch');
      final data = response.data as Map<String, dynamic>;
      
      currentSession = ScormSession(
        id: data['session_id'],
        scormPackageId: scormPackageId,
        startedAt: DateTime.now(),
      );
      
      launchUrl = data['launch_url'];
      cmiData.clear();
      
      // Load any existing CMI data (for resume)
      if (data['cmi_data'] != null) {
        cmiData.addAll(Map<String, dynamic>.from(data['cmi_data']));
      }
      
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }
  
  @action
  void updateCmiValue(String key, dynamic value) {
    cmiData[key] = value;
  }
  
  @action
  Future<bool> commitCmi() async {
    if (currentSession == null) return false;
    
    isSyncing = true;
    
    try {
      await _api.post(
        '/v1/scorm/${currentSession!.id}/commit',
        data: {
          'cmi_data': Map<String, dynamic>.from(cmiData),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      // Cache for offline sync
      pendingCommits++;
      await _cacheCommit();
      return false;
    } finally {
      isSyncing = false;
    }
  }
  
  Future<void> _cacheCommit() async {
    if (currentSession == null) return;
    
    await _cache.cacheScormCmi(
      sessionId: currentSession!.id,
      packageId: currentSession!.scormPackageId,
      sequenceNumber: pendingCommits,
      cmiData: Map<String, dynamic>.from(cmiData),
    );
  }
  
  @action
  Future<void> syncPendingCommits() async {
    if (currentSession == null) return;
    
    final pending = _cache.getPendingScormCmis(currentSession!.id);
    
    for (final commit in pending) {
      try {
        await _api.post(
          '/v1/scorm/${currentSession!.id}/commit',
          data: commit,
        );
        await _cache.markScormCmiSynced(
          currentSession!.id,
          commit['sequence_number'] as int,
        );
        pendingCommits--;
      } catch (e) {
        break; // Stop on first failure, maintain order
      }
    }
  }
  
  @action
  Future<void> finishSession({String? status}) async {
    if (currentSession == null) return;
    
    try {
      await _api.post(
        '/v1/scorm/${currentSession!.id}/finish',
        data: {
          'final_cmi': Map<String, dynamic>.from(cmiData),
          'status': status ?? lessonStatus,
        },
      );
    } catch (e) {
      errorMessage = e.toString();
    }
  }
  
  @action
  void endSession() {
    currentSession = null;
    launchUrl = null;
    cmiData.clear();
    pendingCommits = 0;
  }
  
  @action
  void clearError() {
    errorMessage = null;
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class ScormSession {
  final String id;
  final String scormPackageId;
  final DateTime startedAt;
  
  ScormSession({
    required this.id,
    required this.scormPackageId,
    required this.startedAt,
  });
}
