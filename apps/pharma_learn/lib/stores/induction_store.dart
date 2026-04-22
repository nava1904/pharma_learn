import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../repositories/training_repository.dart';

part 'induction_store.g.dart';

/// Store for induction module progress.
/// Handles module completion tracking and induction gate.
@singleton
class InductionStore = _InductionStoreBase with _$InductionStore;

abstract class _InductionStoreBase with Store {
  final TrainingRepository _repository;
  
  _InductionStoreBase(this._repository);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  InductionStatus? status;
  
  @observable
  ObservableList<InductionModule> modules = ObservableList<InductionModule>();
  
  @observable
  InductionModule? currentModule;
  
  @observable
  bool isCompleting = false;
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  bool get isInductionCompleted => status?.isCompleted ?? false;
  
  @computed
  int get completedCount => status?.completedModules ?? 0;
  
  @computed
  int get totalCount => status?.totalModules ?? modules.length;
  
  @computed
  double get progress => status?.progress ?? 0.0;
  
  @computed
  InductionModule? get nextModule {
    try {
      return modules.firstWhere((m) => !m.isCompleted);
    } catch (_) {
      return null;
    }
  }
  
  @computed
  bool get allModulesCompleted => 
      modules.isNotEmpty && modules.every((m) => m.isCompleted);
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<void> loadInductionStatus() async {
    isLoading = true;
    errorMessage = null;
    
    try {
      status = await _repository.getInductionStatus();
      final moduleList = await _repository.getInductionModules();
      modules = ObservableList.of(moduleList);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> loadModuleDetail(String moduleId) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      currentModule = await _repository.getInductionModule(moduleId);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<bool> completeModule(String moduleId) async {
    isCompleting = true;
    errorMessage = null;
    
    try {
      await _repository.completeInductionModule(moduleId);
      
      // Update local state
      final index = modules.indexWhere((m) => m.id == moduleId);
      if (index >= 0) {
        // Refresh to get updated status
        await loadInductionStatus();
      }
      
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isCompleting = false;
    }
  }
  
  @action
  Future<bool> completeInduction({
    required String esigPassword,
    required String meaning,
  }) async {
    if (!allModulesCompleted) {
      errorMessage = 'Please complete all modules first';
      return false;
    }
    
    isCompleting = true;
    errorMessage = null;
    
    try {
      await _repository.completeInduction(
        esigPassword: esigPassword,
        meaning: meaning,
      );
      await loadInductionStatus(); // Refresh status
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isCompleting = false;
    }
  }
  
  @action
  void clearCurrentModule() {
    currentModule = null;
  }
  
  @action
  void clearError() {
    errorMessage = null;
  }
}
