import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../repositories/training_repository.dart';

part 'training_obligations_store.g.dart';

/// Store for managing employee training obligations (to-do list).
/// Handles obligation listing, waiver submission, and obligation details.
@singleton
class TrainingObligationsStore = _TrainingObligationsStoreBase with _$TrainingObligationsStore;

abstract class _TrainingObligationsStoreBase with Store {
  final TrainingRepository _repository;
  
  _TrainingObligationsStoreBase(this._repository);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  ObservableList<Obligation> obligations = ObservableList<Obligation>();
  
  @observable
  Obligation? selectedObligation;
  
  @observable
  bool isSubmittingWaiver = false;
  
  @observable
  String? waiverError;
  
  @observable
  String filterStatus = 'all'; // all, pending, in_progress, overdue, completed
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  List<Obligation> get filteredObligations {
    if (filterStatus == 'all') return obligations.toList();
    return obligations.where((o) => o.status == filterStatus).toList();
  }
  
  @computed
  int get pendingCount => obligations.where((o) => o.status == 'pending').length;
  
  @computed
  int get overdueCount => obligations.where((o) => o.status == 'overdue').length;
  
  @computed
  int get inProgressCount => obligations.where((o) => o.status == 'in_progress').length;
  
  @computed
  List<Obligation> get urgentObligations {
    return obligations
        .where((o) => o.isUrgent || o.status == 'overdue')
        .take(5)
        .toList();
  }
  
  @computed
  bool get hasOverdue => overdueCount > 0;
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<void> loadObligations({bool forceRefresh = false}) async {
    if (isLoading && !forceRefresh) return;
    
    isLoading = true;
    errorMessage = null;
    
    try {
      final result = await _repository.getObligations();
      obligations = ObservableList.of(result);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> loadObligationDetail(String id) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      selectedObligation = await _repository.getObligation(id);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  void setFilter(String status) {
    filterStatus = status;
  }
  
  @action
  Future<bool> submitWaiverRequest({
    required String obligationId,
    required String reason,
    required String justification,
  }) async {
    isSubmittingWaiver = true;
    waiverError = null;
    
    try {
      await _repository.submitWaiver(
        obligationId: obligationId,
        reason: reason,
        justification: justification,
      );
      // Refresh obligations after waiver submission
      await loadObligations(forceRefresh: true);
      return true;
    } catch (e) {
      waiverError = e.toString();
      return false;
    } finally {
      isSubmittingWaiver = false;
    }
  }
  
  @action
  void clearSelectedObligation() {
    selectedObligation = null;
  }
  
  @action
  void clearError() {
    errorMessage = null;
    waiverError = null;
  }
}
