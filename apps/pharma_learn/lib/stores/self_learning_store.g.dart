// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'self_learning_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$SelfLearningStore on _SelfLearningStoreBase, Store {
  Computed<bool>? _$hasActiveSessionComputed;

  @override
  bool get hasActiveSession => (_$hasActiveSessionComputed ??= Computed<bool>(
    () => super.hasActiveSession,
    name: '_SelfLearningStoreBase.hasActiveSession',
  )).value;
  Computed<String>? _$lessonStatusComputed;

  @override
  String get lessonStatus => (_$lessonStatusComputed ??= Computed<String>(
    () => super.lessonStatus,
    name: '_SelfLearningStoreBase.lessonStatus',
  )).value;
  Computed<double>? _$progressComputed;

  @override
  double get progress => (_$progressComputed ??= Computed<double>(
    () => super.progress,
    name: '_SelfLearningStoreBase.progress',
  )).value;
  Computed<int?>? _$scoreRawComputed;

  @override
  int? get scoreRaw => (_$scoreRawComputed ??= Computed<int?>(
    () => super.scoreRaw,
    name: '_SelfLearningStoreBase.scoreRaw',
  )).value;
  Computed<bool>? _$isCompletedComputed;

  @override
  bool get isCompleted => (_$isCompletedComputed ??= Computed<bool>(
    () => super.isCompleted,
    name: '_SelfLearningStoreBase.isCompleted',
  )).value;

  late final _$isLoadingAtom = Atom(
    name: '_SelfLearningStoreBase.isLoading',
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
    name: '_SelfLearningStoreBase.errorMessage',
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

  late final _$currentSessionAtom = Atom(
    name: '_SelfLearningStoreBase.currentSession',
    context: context,
  );

  @override
  ScormSession? get currentSession {
    _$currentSessionAtom.reportRead();
    return super.currentSession;
  }

  @override
  set currentSession(ScormSession? value) {
    _$currentSessionAtom.reportWrite(value, super.currentSession, () {
      super.currentSession = value;
    });
  }

  late final _$launchUrlAtom = Atom(
    name: '_SelfLearningStoreBase.launchUrl',
    context: context,
  );

  @override
  String? get launchUrl {
    _$launchUrlAtom.reportRead();
    return super.launchUrl;
  }

  @override
  set launchUrl(String? value) {
    _$launchUrlAtom.reportWrite(value, super.launchUrl, () {
      super.launchUrl = value;
    });
  }

  late final _$cmiDataAtom = Atom(
    name: '_SelfLearningStoreBase.cmiData',
    context: context,
  );

  @override
  ObservableMap<String, dynamic> get cmiData {
    _$cmiDataAtom.reportRead();
    return super.cmiData;
  }

  @override
  set cmiData(ObservableMap<String, dynamic> value) {
    _$cmiDataAtom.reportWrite(value, super.cmiData, () {
      super.cmiData = value;
    });
  }

  late final _$isSyncingAtom = Atom(
    name: '_SelfLearningStoreBase.isSyncing',
    context: context,
  );

  @override
  bool get isSyncing {
    _$isSyncingAtom.reportRead();
    return super.isSyncing;
  }

  @override
  set isSyncing(bool value) {
    _$isSyncingAtom.reportWrite(value, super.isSyncing, () {
      super.isSyncing = value;
    });
  }

  late final _$pendingCommitsAtom = Atom(
    name: '_SelfLearningStoreBase.pendingCommits',
    context: context,
  );

  @override
  int get pendingCommits {
    _$pendingCommitsAtom.reportRead();
    return super.pendingCommits;
  }

  @override
  set pendingCommits(int value) {
    _$pendingCommitsAtom.reportWrite(value, super.pendingCommits, () {
      super.pendingCommits = value;
    });
  }

  late final _$launchContentAsyncAction = AsyncAction(
    '_SelfLearningStoreBase.launchContent',
    context: context,
  );

  @override
  Future<bool> launchContent(String scormPackageId) {
    return _$launchContentAsyncAction.run(
      () => super.launchContent(scormPackageId),
    );
  }

  late final _$commitCmiAsyncAction = AsyncAction(
    '_SelfLearningStoreBase.commitCmi',
    context: context,
  );

  @override
  Future<bool> commitCmi() {
    return _$commitCmiAsyncAction.run(() => super.commitCmi());
  }

  late final _$syncPendingCommitsAsyncAction = AsyncAction(
    '_SelfLearningStoreBase.syncPendingCommits',
    context: context,
  );

  @override
  Future<void> syncPendingCommits() {
    return _$syncPendingCommitsAsyncAction.run(
      () => super.syncPendingCommits(),
    );
  }

  late final _$finishSessionAsyncAction = AsyncAction(
    '_SelfLearningStoreBase.finishSession',
    context: context,
  );

  @override
  Future<void> finishSession({String? status}) {
    return _$finishSessionAsyncAction.run(
      () => super.finishSession(status: status),
    );
  }

  late final _$_SelfLearningStoreBaseActionController = ActionController(
    name: '_SelfLearningStoreBase',
    context: context,
  );

  @override
  void updateCmiValue(String key, dynamic value) {
    final _$actionInfo = _$_SelfLearningStoreBaseActionController.startAction(
      name: '_SelfLearningStoreBase.updateCmiValue',
    );
    try {
      return super.updateCmiValue(key, value);
    } finally {
      _$_SelfLearningStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void endSession() {
    final _$actionInfo = _$_SelfLearningStoreBaseActionController.startAction(
      name: '_SelfLearningStoreBase.endSession',
    );
    try {
      return super.endSession();
    } finally {
      _$_SelfLearningStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_SelfLearningStoreBaseActionController.startAction(
      name: '_SelfLearningStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_SelfLearningStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
currentSession: ${currentSession},
launchUrl: ${launchUrl},
cmiData: ${cmiData},
isSyncing: ${isSyncing},
pendingCommits: ${pendingCommits},
hasActiveSession: ${hasActiveSession},
lessonStatus: ${lessonStatus},
progress: ${progress},
scoreRaw: ${scoreRaw},
isCompleted: ${isCompleted}
    ''';
  }
}
