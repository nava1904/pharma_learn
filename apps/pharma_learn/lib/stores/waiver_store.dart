import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../repositories/training_repository.dart';

part 'waiver_store.g.dart';

/// Store for waiver request management.
/// Handles waiver submission and status tracking.
@singleton
class WaiverStore = _WaiverStoreBase with _$WaiverStore;

abstract class _WaiverStoreBase with Store {
  final TrainingRepository _repository;
  
  _WaiverStoreBase(this._repository);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  ObservableList<WaiverRequest> waivers = ObservableList<WaiverRequest>();
  
  @observable
  WaiverRequest? selectedWaiver;
  
  @observable
  bool isSubmitting = false;
  
  @observable
  String filterStatus = 'all'; // all, pending_approval, approved, rejected
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  List<WaiverRequest> get filteredWaivers {
    if (filterStatus == 'all') return waivers.toList();
    return waivers.where((w) => w.status == filterStatus).toList();
  }
  
  @computed
  int get pendingCount => 
      waivers.where((w) => w.status == 'pending_approval').length;
  
  @computed
  int get approvedCount => 
      waivers.where((w) => w.status == 'approved').length;
  
  @computed
  int get rejectedCount => 
      waivers.where((w) => w.status == 'rejected').length;
  
  @computed
  bool get hasPending => pendingCount > 0;
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<void> loadMyWaivers() async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final list = await _repository.getMyWaivers();
      waivers = ObservableList.of(list);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<bool> submitWaiver({
    required String obligationId,
    required String reason,
    required String justification,
  }) async {
    isSubmitting = true;
    errorMessage = null;
    
    try {
      await _repository.submitWaiver(
        obligationId: obligationId,
        reason: reason,
        justification: justification,
      );
      
      // Refresh list
      await loadMyWaivers();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isSubmitting = false;
    }
  }
  
  @action
  void setFilter(String status) {
    filterStatus = status;
  }
  
  @action
  void selectWaiver(WaiverRequest waiver) {
    selectedWaiver = waiver;
  }
  
  @action
  void clearSelectedWaiver() {
    selectedWaiver = null;
  }
  
  @action
  void clearError() {
    errorMessage = null;
  }
}
