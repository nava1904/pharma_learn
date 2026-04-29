import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../core/api/api_client.dart';

part 'ojt_store.g.dart';

/// Store for OJT (On-the-Job Training) management.
/// Handles task list, per-task sign-off with e-signature.
@singleton
class OjtStore = _OjtStoreBase with _$OjtStore;

abstract class _OjtStoreBase with Store {
  final ApiClient _api;
  
  _OjtStoreBase(this._api);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  ObservableList<OjtAssignment> assignments = ObservableList<OjtAssignment>();
  
  @observable
  OjtAssignment? selectedAssignment;
  
  @observable
  ObservableList<OjtTask> tasks = ObservableList<OjtTask>();
  
  @observable
  bool isSigningOff = false;
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  int get totalTasks => tasks.length;
  
  @computed
  int get completedTasks => tasks.where((t) => t.isCompleted).length;
  
  @computed
  double get progress {
    if (totalTasks == 0) return 0.0;
    return completedTasks / totalTasks;
  }
  
  @computed
  List<OjtTask> get pendingTasks => tasks.where((t) => !t.isCompleted).toList();
  
  @computed
  List<OjtAssignment> get activeAssignments =>
      assignments.where((a) => a.status == 'in_progress' || a.status == 'pending').toList();
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<void> loadAssignments() async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final response = await _api.get('/v1/train/ojt/my');
      final data = response.data as Map<String, dynamic>;
      final list = data['data']?['assignments'] ?? data['assignments'] ?? [];
      assignments = ObservableList.of(
        (list as List).map((a) => OjtAssignment.fromJson(a)).toList(),
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> loadAssignmentDetail(String assignmentId) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final response = await _api.get('/v1/train/ojt/$assignmentId');
      final data = response.data as Map<String, dynamic>;
      selectedAssignment = OjtAssignment.fromJson(data['data'] ?? data);
      
      // Load tasks for this assignment
      final taskList = data['data']?['tasks'] ?? data['tasks'] ?? [];
      tasks = ObservableList.of(
        (taskList as List).map((t) => OjtTask.fromJson(t)).toList(),
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<bool> signOffTask({
    required String taskId,
    required String esigPassword,
    required String meaning,
    String? comments,
  }) async {
    isSigningOff = true;
    errorMessage = null;
    
    try {
      await _api.post(
        '/v1/train/ojt/tasks/$taskId/sign-off',
        data: {
          'esig_password': esigPassword,
          'meaning': meaning,
          'comments': ?comments,
        },
      );
      
      // Update task in local state
      final index = tasks.indexWhere((t) => t.id == taskId);
      if (index >= 0) {
        tasks[index] = tasks[index].copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
        );
      }
      
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isSigningOff = false;
    }
  }
  
  @action
  Future<bool> completeAssignment({
    required String assignmentId,
    required String esigPassword,
    required String meaning,
  }) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      await _api.post(
        '/v1/train/ojt/$assignmentId/complete',
        data: {
          'esig_password': esigPassword,
          'meaning': meaning,
        },
      );
      
      await loadAssignments(); // Refresh
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
    }
  }
  
  @action
  void clearSelectedAssignment() {
    selectedAssignment = null;
    tasks.clear();
  }
  
  @action
  void clearError() {
    errorMessage = null;
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class OjtAssignment {
  final String id;
  final String ojtName;
  final String ojtCode;
  final String status;
  final DateTime? dueDate;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int totalTasks;
  final int completedTasks;
  final String? supervisorName;
  
  OjtAssignment({
    required this.id,
    required this.ojtName,
    required this.ojtCode,
    required this.status,
    this.dueDate,
    this.startedAt,
    this.completedAt,
    required this.totalTasks,
    required this.completedTasks,
    this.supervisorName,
  });
  
  double get progress {
    if (totalTasks == 0) return 0.0;
    return completedTasks / totalTasks;
  }
  
  factory OjtAssignment.fromJson(Map<String, dynamic> json) {
    return OjtAssignment(
      id: json['id'],
      ojtName: json['ojt_name'] ?? json['name'] ?? '',
      ojtCode: json['ojt_code'] ?? json['code'] ?? '',
      status: json['status'] ?? 'pending',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      totalTasks: json['total_tasks'] ?? 0,
      completedTasks: json['completed_tasks'] ?? 0,
      supervisorName: json['supervisor_name'],
    );
  }
}

class OjtTask {
  final String id;
  final String title;
  final String? description;
  final int order;
  final bool isCompleted;
  final DateTime? completedAt;
  final String? completedByName;
  final String? signOffType; // 'trainee' | 'supervisor' | 'both'
  
  OjtTask({
    required this.id,
    required this.title,
    this.description,
    required this.order,
    required this.isCompleted,
    this.completedAt,
    this.completedByName,
    this.signOffType,
  });
  
  OjtTask copyWith({bool? isCompleted, DateTime? completedAt}) {
    return OjtTask(
      id: id,
      title: title,
      description: description,
      order: order,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      completedByName: completedByName,
      signOffType: signOffType,
    );
  }
  
  factory OjtTask.fromJson(Map<String, dynamic> json) {
    return OjtTask(
      id: json['id'],
      title: json['title'] ?? json['name'] ?? '',
      description: json['description'],
      order: json['order'] ?? 0,
      isCompleted: json['is_completed'] ?? json['completed'] ?? false,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : null,
      completedByName: json['completed_by_name'],
      signOffType: json['sign_off_type'],
    );
  }
}
