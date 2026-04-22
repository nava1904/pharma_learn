// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'induction_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$InductionStore on _InductionStoreBase, Store {
  Computed<bool>? _$isInductionCompletedComputed;

  @override
  bool get isInductionCompleted =>
      (_$isInductionCompletedComputed ??= Computed<bool>(
        () => super.isInductionCompleted,
        name: '_InductionStoreBase.isInductionCompleted',
      )).value;
  Computed<int>? _$completedCountComputed;

  @override
  int get completedCount => (_$completedCountComputed ??= Computed<int>(
    () => super.completedCount,
    name: '_InductionStoreBase.completedCount',
  )).value;
  Computed<int>? _$totalCountComputed;

  @override
  int get totalCount => (_$totalCountComputed ??= Computed<int>(
    () => super.totalCount,
    name: '_InductionStoreBase.totalCount',
  )).value;
  Computed<double>? _$progressComputed;

  @override
  double get progress => (_$progressComputed ??= Computed<double>(
    () => super.progress,
    name: '_InductionStoreBase.progress',
  )).value;
  Computed<InductionModule?>? _$nextModuleComputed;

  @override
  InductionModule? get nextModule =>
      (_$nextModuleComputed ??= Computed<InductionModule?>(
        () => super.nextModule,
        name: '_InductionStoreBase.nextModule',
      )).value;
  Computed<bool>? _$allModulesCompletedComputed;

  @override
  bool get allModulesCompleted =>
      (_$allModulesCompletedComputed ??= Computed<bool>(
        () => super.allModulesCompleted,
        name: '_InductionStoreBase.allModulesCompleted',
      )).value;

  late final _$isLoadingAtom = Atom(
    name: '_InductionStoreBase.isLoading',
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
    name: '_InductionStoreBase.errorMessage',
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

  late final _$statusAtom = Atom(
    name: '_InductionStoreBase.status',
    context: context,
  );

  @override
  InductionStatus? get status {
    _$statusAtom.reportRead();
    return super.status;
  }

  @override
  set status(InductionStatus? value) {
    _$statusAtom.reportWrite(value, super.status, () {
      super.status = value;
    });
  }

  late final _$modulesAtom = Atom(
    name: '_InductionStoreBase.modules',
    context: context,
  );

  @override
  ObservableList<InductionModule> get modules {
    _$modulesAtom.reportRead();
    return super.modules;
  }

  @override
  set modules(ObservableList<InductionModule> value) {
    _$modulesAtom.reportWrite(value, super.modules, () {
      super.modules = value;
    });
  }

  late final _$currentModuleAtom = Atom(
    name: '_InductionStoreBase.currentModule',
    context: context,
  );

  @override
  InductionModule? get currentModule {
    _$currentModuleAtom.reportRead();
    return super.currentModule;
  }

  @override
  set currentModule(InductionModule? value) {
    _$currentModuleAtom.reportWrite(value, super.currentModule, () {
      super.currentModule = value;
    });
  }

  late final _$isCompletingAtom = Atom(
    name: '_InductionStoreBase.isCompleting',
    context: context,
  );

  @override
  bool get isCompleting {
    _$isCompletingAtom.reportRead();
    return super.isCompleting;
  }

  @override
  set isCompleting(bool value) {
    _$isCompletingAtom.reportWrite(value, super.isCompleting, () {
      super.isCompleting = value;
    });
  }

  late final _$loadInductionStatusAsyncAction = AsyncAction(
    '_InductionStoreBase.loadInductionStatus',
    context: context,
  );

  @override
  Future<void> loadInductionStatus() {
    return _$loadInductionStatusAsyncAction.run(
      () => super.loadInductionStatus(),
    );
  }

  late final _$loadModuleDetailAsyncAction = AsyncAction(
    '_InductionStoreBase.loadModuleDetail',
    context: context,
  );

  @override
  Future<void> loadModuleDetail(String moduleId) {
    return _$loadModuleDetailAsyncAction.run(
      () => super.loadModuleDetail(moduleId),
    );
  }

  late final _$completeModuleAsyncAction = AsyncAction(
    '_InductionStoreBase.completeModule',
    context: context,
  );

  @override
  Future<bool> completeModule(String moduleId) {
    return _$completeModuleAsyncAction.run(
      () => super.completeModule(moduleId),
    );
  }

  late final _$completeInductionAsyncAction = AsyncAction(
    '_InductionStoreBase.completeInduction',
    context: context,
  );

  @override
  Future<bool> completeInduction({
    required String esigPassword,
    required String meaning,
  }) {
    return _$completeInductionAsyncAction.run(
      () =>
          super.completeInduction(esigPassword: esigPassword, meaning: meaning),
    );
  }

  late final _$_InductionStoreBaseActionController = ActionController(
    name: '_InductionStoreBase',
    context: context,
  );

  @override
  void clearCurrentModule() {
    final _$actionInfo = _$_InductionStoreBaseActionController.startAction(
      name: '_InductionStoreBase.clearCurrentModule',
    );
    try {
      return super.clearCurrentModule();
    } finally {
      _$_InductionStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_InductionStoreBaseActionController.startAction(
      name: '_InductionStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_InductionStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
status: ${status},
modules: ${modules},
currentModule: ${currentModule},
isCompleting: ${isCompleting},
isInductionCompleted: ${isInductionCompleted},
completedCount: ${completedCount},
totalCount: ${totalCount},
progress: ${progress},
nextModule: ${nextModule},
allModulesCompleted: ${allModulesCompleted}
    ''';
  }
}
