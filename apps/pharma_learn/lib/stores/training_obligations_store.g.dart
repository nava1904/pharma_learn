// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_obligations_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$TrainingObligationsStore on _TrainingObligationsStoreBase, Store {
  Computed<List<Obligation>>? _$filteredObligationsComputed;

  @override
  List<Obligation> get filteredObligations =>
      (_$filteredObligationsComputed ??= Computed<List<Obligation>>(
        () => super.filteredObligations,
        name: '_TrainingObligationsStoreBase.filteredObligations',
      )).value;
  Computed<int>? _$pendingCountComputed;

  @override
  int get pendingCount => (_$pendingCountComputed ??= Computed<int>(
    () => super.pendingCount,
    name: '_TrainingObligationsStoreBase.pendingCount',
  )).value;
  Computed<int>? _$overdueCountComputed;

  @override
  int get overdueCount => (_$overdueCountComputed ??= Computed<int>(
    () => super.overdueCount,
    name: '_TrainingObligationsStoreBase.overdueCount',
  )).value;
  Computed<int>? _$inProgressCountComputed;

  @override
  int get inProgressCount => (_$inProgressCountComputed ??= Computed<int>(
    () => super.inProgressCount,
    name: '_TrainingObligationsStoreBase.inProgressCount',
  )).value;
  Computed<List<Obligation>>? _$urgentObligationsComputed;

  @override
  List<Obligation> get urgentObligations =>
      (_$urgentObligationsComputed ??= Computed<List<Obligation>>(
        () => super.urgentObligations,
        name: '_TrainingObligationsStoreBase.urgentObligations',
      )).value;
  Computed<bool>? _$hasOverdueComputed;

  @override
  bool get hasOverdue => (_$hasOverdueComputed ??= Computed<bool>(
    () => super.hasOverdue,
    name: '_TrainingObligationsStoreBase.hasOverdue',
  )).value;

  late final _$isLoadingAtom = Atom(
    name: '_TrainingObligationsStoreBase.isLoading',
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
    name: '_TrainingObligationsStoreBase.errorMessage',
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

  late final _$obligationsAtom = Atom(
    name: '_TrainingObligationsStoreBase.obligations',
    context: context,
  );

  @override
  ObservableList<Obligation> get obligations {
    _$obligationsAtom.reportRead();
    return super.obligations;
  }

  @override
  set obligations(ObservableList<Obligation> value) {
    _$obligationsAtom.reportWrite(value, super.obligations, () {
      super.obligations = value;
    });
  }

  late final _$selectedObligationAtom = Atom(
    name: '_TrainingObligationsStoreBase.selectedObligation',
    context: context,
  );

  @override
  Obligation? get selectedObligation {
    _$selectedObligationAtom.reportRead();
    return super.selectedObligation;
  }

  @override
  set selectedObligation(Obligation? value) {
    _$selectedObligationAtom.reportWrite(value, super.selectedObligation, () {
      super.selectedObligation = value;
    });
  }

  late final _$isSubmittingWaiverAtom = Atom(
    name: '_TrainingObligationsStoreBase.isSubmittingWaiver',
    context: context,
  );

  @override
  bool get isSubmittingWaiver {
    _$isSubmittingWaiverAtom.reportRead();
    return super.isSubmittingWaiver;
  }

  @override
  set isSubmittingWaiver(bool value) {
    _$isSubmittingWaiverAtom.reportWrite(value, super.isSubmittingWaiver, () {
      super.isSubmittingWaiver = value;
    });
  }

  late final _$waiverErrorAtom = Atom(
    name: '_TrainingObligationsStoreBase.waiverError',
    context: context,
  );

  @override
  String? get waiverError {
    _$waiverErrorAtom.reportRead();
    return super.waiverError;
  }

  @override
  set waiverError(String? value) {
    _$waiverErrorAtom.reportWrite(value, super.waiverError, () {
      super.waiverError = value;
    });
  }

  late final _$filterStatusAtom = Atom(
    name: '_TrainingObligationsStoreBase.filterStatus',
    context: context,
  );

  @override
  String get filterStatus {
    _$filterStatusAtom.reportRead();
    return super.filterStatus;
  }

  @override
  set filterStatus(String value) {
    _$filterStatusAtom.reportWrite(value, super.filterStatus, () {
      super.filterStatus = value;
    });
  }

  late final _$loadObligationsAsyncAction = AsyncAction(
    '_TrainingObligationsStoreBase.loadObligations',
    context: context,
  );

  @override
  Future<void> loadObligations({bool forceRefresh = false}) {
    return _$loadObligationsAsyncAction.run(
      () => super.loadObligations(forceRefresh: forceRefresh),
    );
  }

  late final _$loadObligationDetailAsyncAction = AsyncAction(
    '_TrainingObligationsStoreBase.loadObligationDetail',
    context: context,
  );

  @override
  Future<void> loadObligationDetail(String id) {
    return _$loadObligationDetailAsyncAction.run(
      () => super.loadObligationDetail(id),
    );
  }

  late final _$submitWaiverRequestAsyncAction = AsyncAction(
    '_TrainingObligationsStoreBase.submitWaiverRequest',
    context: context,
  );

  @override
  Future<bool> submitWaiverRequest({
    required String obligationId,
    required String reason,
    required String justification,
  }) {
    return _$submitWaiverRequestAsyncAction.run(
      () => super.submitWaiverRequest(
        obligationId: obligationId,
        reason: reason,
        justification: justification,
      ),
    );
  }

  late final _$_TrainingObligationsStoreBaseActionController = ActionController(
    name: '_TrainingObligationsStoreBase',
    context: context,
  );

  @override
  void setFilter(String status) {
    final _$actionInfo = _$_TrainingObligationsStoreBaseActionController
        .startAction(name: '_TrainingObligationsStoreBase.setFilter');
    try {
      return super.setFilter(status);
    } finally {
      _$_TrainingObligationsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSelectedObligation() {
    final _$actionInfo = _$_TrainingObligationsStoreBaseActionController
        .startAction(
          name: '_TrainingObligationsStoreBase.clearSelectedObligation',
        );
    try {
      return super.clearSelectedObligation();
    } finally {
      _$_TrainingObligationsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_TrainingObligationsStoreBaseActionController
        .startAction(name: '_TrainingObligationsStoreBase.clearError');
    try {
      return super.clearError();
    } finally {
      _$_TrainingObligationsStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
obligations: ${obligations},
selectedObligation: ${selectedObligation},
isSubmittingWaiver: ${isSubmittingWaiver},
waiverError: ${waiverError},
filterStatus: ${filterStatus},
filteredObligations: ${filteredObligations},
pendingCount: ${pendingCount},
overdueCount: ${overdueCount},
inProgressCount: ${inProgressCount},
urgentObligations: ${urgentObligations},
hasOverdue: ${hasOverdue}
    ''';
  }
}
