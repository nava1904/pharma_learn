// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ojt_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$OjtStore on _OjtStoreBase, Store {
  Computed<int>? _$totalTasksComputed;

  @override
  int get totalTasks => (_$totalTasksComputed ??= Computed<int>(
    () => super.totalTasks,
    name: '_OjtStoreBase.totalTasks',
  )).value;
  Computed<int>? _$completedTasksComputed;

  @override
  int get completedTasks => (_$completedTasksComputed ??= Computed<int>(
    () => super.completedTasks,
    name: '_OjtStoreBase.completedTasks',
  )).value;
  Computed<double>? _$progressComputed;

  @override
  double get progress => (_$progressComputed ??= Computed<double>(
    () => super.progress,
    name: '_OjtStoreBase.progress',
  )).value;
  Computed<List<OjtTask>>? _$pendingTasksComputed;

  @override
  List<OjtTask> get pendingTasks =>
      (_$pendingTasksComputed ??= Computed<List<OjtTask>>(
        () => super.pendingTasks,
        name: '_OjtStoreBase.pendingTasks',
      )).value;
  Computed<List<OjtAssignment>>? _$activeAssignmentsComputed;

  @override
  List<OjtAssignment> get activeAssignments =>
      (_$activeAssignmentsComputed ??= Computed<List<OjtAssignment>>(
        () => super.activeAssignments,
        name: '_OjtStoreBase.activeAssignments',
      )).value;

  late final _$isLoadingAtom = Atom(
    name: '_OjtStoreBase.isLoading',
    context: context,
  );

  @override
  bool get isLoading {
    _$isLoadingAtom.reportRead();
    return super.isLoading;
  }

  @override
  set isLoading(bool value) {
    _$isLoadingAtom.reportWrite(value, super.isLoading, () {
      super.isLoading = value;
    });
  }

  late final _$errorMessageAtom = Atom(
    name: '_OjtStoreBase.errorMessage',
    context: context,
  );

  @override
  String? get errorMessage {
    _$errorMessageAtom.reportRead();
    return super.errorMessage;
  }

  @override
  set errorMessage(String? value) {
    _$errorMessageAtom.reportWrite(value, super.errorMessage, () {
      super.errorMessage = value;
    });
  }

  late final _$assignmentsAtom = Atom(
    name: '_OjtStoreBase.assignments',
    context: context,
  );

  @override
  ObservableList<OjtAssignment> get assignments {
    _$assignmentsAtom.reportRead();
    return super.assignments;
  }

  @override
  set assignments(ObservableList<OjtAssignment> value) {
    _$assignmentsAtom.reportWrite(value, super.assignments, () {
      super.assignments = value;
    });
  }

  late final _$selectedAssignmentAtom = Atom(
    name: '_OjtStoreBase.selectedAssignment',
    context: context,
  );

  @override
  OjtAssignment? get selectedAssignment {
    _$selectedAssignmentAtom.reportRead();
    return super.selectedAssignment;
  }

  @override
  set selectedAssignment(OjtAssignment? value) {
    _$selectedAssignmentAtom.reportWrite(value, super.selectedAssignment, () {
      super.selectedAssignment = value;
    });
  }

  late final _$tasksAtom = Atom(name: '_OjtStoreBase.tasks', context: context);

  @override
  ObservableList<OjtTask> get tasks {
    _$tasksAtom.reportRead();
    return super.tasks;
  }

  @override
  set tasks(ObservableList<OjtTask> value) {
    _$tasksAtom.reportWrite(value, super.tasks, () {
      super.tasks = value;
    });
  }

  late final _$isSigningOffAtom = Atom(
    name: '_OjtStoreBase.isSigningOff',
    context: context,
  );

  @override
  bool get isSigningOff {
    _$isSigningOffAtom.reportRead();
    return super.isSigningOff;
  }

  @override
  set isSigningOff(bool value) {
    _$isSigningOffAtom.reportWrite(value, super.isSigningOff, () {
      super.isSigningOff = value;
    });
  }

  late final _$loadAssignmentsAsyncAction = AsyncAction(
    '_OjtStoreBase.loadAssignments',
    context: context,
  );

  @override
  Future<void> loadAssignments() {
    return _$loadAssignmentsAsyncAction.run(() => super.loadAssignments());
  }

  late final _$loadAssignmentDetailAsyncAction = AsyncAction(
    '_OjtStoreBase.loadAssignmentDetail',
    context: context,
  );

  @override
  Future<void> loadAssignmentDetail(String assignmentId) {
    return _$loadAssignmentDetailAsyncAction.run(
      () => super.loadAssignmentDetail(assignmentId),
    );
  }

  late final _$signOffTaskAsyncAction = AsyncAction(
    '_OjtStoreBase.signOffTask',
    context: context,
  );

  @override
  Future<bool> signOffTask({
    required String taskId,
    required String esigPassword,
    required String meaning,
    String? comments,
  }) {
    return _$signOffTaskAsyncAction.run(
      () => super.signOffTask(
        taskId: taskId,
        esigPassword: esigPassword,
        meaning: meaning,
        comments: comments,
      ),
    );
  }

  late final _$completeAssignmentAsyncAction = AsyncAction(
    '_OjtStoreBase.completeAssignment',
    context: context,
  );

  @override
  Future<bool> completeAssignment({
    required String assignmentId,
    required String esigPassword,
    required String meaning,
  }) {
    return _$completeAssignmentAsyncAction.run(
      () => super.completeAssignment(
        assignmentId: assignmentId,
        esigPassword: esigPassword,
        meaning: meaning,
      ),
    );
  }

  late final _$_OjtStoreBaseActionController = ActionController(
    name: '_OjtStoreBase',
    context: context,
  );

  @override
  void clearSelectedAssignment() {
    final _$actionInfo = _$_OjtStoreBaseActionController.startAction(
      name: '_OjtStoreBase.clearSelectedAssignment',
    );
    try {
      return super.clearSelectedAssignment();
    } finally {
      _$_OjtStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_OjtStoreBaseActionController.startAction(
      name: '_OjtStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_OjtStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
assignments: ${assignments},
selectedAssignment: ${selectedAssignment},
tasks: ${tasks},
isSigningOff: ${isSigningOff},
totalTasks: ${totalTasks},
completedTasks: ${completedTasks},
progress: ${progress},
pendingTasks: ${pendingTasks},
activeAssignments: ${activeAssignments}
    ''';
  }
}
