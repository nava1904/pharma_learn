// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waiver_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$WaiverStore on _WaiverStoreBase, Store {
  Computed<List<WaiverRequest>>? _$filteredWaiversComputed;

  @override
  List<WaiverRequest> get filteredWaivers =>
      (_$filteredWaiversComputed ??= Computed<List<WaiverRequest>>(
        () => super.filteredWaivers,
        name: '_WaiverStoreBase.filteredWaivers',
      )).value;
  Computed<int>? _$pendingCountComputed;

  @override
  int get pendingCount => (_$pendingCountComputed ??= Computed<int>(
    () => super.pendingCount,
    name: '_WaiverStoreBase.pendingCount',
  )).value;
  Computed<int>? _$approvedCountComputed;

  @override
  int get approvedCount => (_$approvedCountComputed ??= Computed<int>(
    () => super.approvedCount,
    name: '_WaiverStoreBase.approvedCount',
  )).value;
  Computed<int>? _$rejectedCountComputed;

  @override
  int get rejectedCount => (_$rejectedCountComputed ??= Computed<int>(
    () => super.rejectedCount,
    name: '_WaiverStoreBase.rejectedCount',
  )).value;
  Computed<bool>? _$hasPendingComputed;

  @override
  bool get hasPending => (_$hasPendingComputed ??= Computed<bool>(
    () => super.hasPending,
    name: '_WaiverStoreBase.hasPending',
  )).value;

  late final _$isLoadingAtom = Atom(
    name: '_WaiverStoreBase.isLoading',
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
    name: '_WaiverStoreBase.errorMessage',
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

  late final _$waiversAtom = Atom(
    name: '_WaiverStoreBase.waivers',
    context: context,
  );

  @override
  ObservableList<WaiverRequest> get waivers {
    _$waiversAtom.reportRead();
    return super.waivers;
  }

  @override
  set waivers(ObservableList<WaiverRequest> value) {
    _$waiversAtom.reportWrite(value, super.waivers, () {
      super.waivers = value;
    });
  }

  late final _$selectedWaiverAtom = Atom(
    name: '_WaiverStoreBase.selectedWaiver',
    context: context,
  );

  @override
  WaiverRequest? get selectedWaiver {
    _$selectedWaiverAtom.reportRead();
    return super.selectedWaiver;
  }

  @override
  set selectedWaiver(WaiverRequest? value) {
    _$selectedWaiverAtom.reportWrite(value, super.selectedWaiver, () {
      super.selectedWaiver = value;
    });
  }

  late final _$isSubmittingAtom = Atom(
    name: '_WaiverStoreBase.isSubmitting',
    context: context,
  );

  @override
  bool get isSubmitting {
    _$isSubmittingAtom.reportRead();
    return super.isSubmitting;
  }

  @override
  set isSubmitting(bool value) {
    _$isSubmittingAtom.reportWrite(value, super.isSubmitting, () {
      super.isSubmitting = value;
    });
  }

  late final _$filterStatusAtom = Atom(
    name: '_WaiverStoreBase.filterStatus',
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

  late final _$loadMyWaiversAsyncAction = AsyncAction(
    '_WaiverStoreBase.loadMyWaivers',
    context: context,
  );

  @override
  Future<void> loadMyWaivers() {
    return _$loadMyWaiversAsyncAction.run(() => super.loadMyWaivers());
  }

  late final _$submitWaiverAsyncAction = AsyncAction(
    '_WaiverStoreBase.submitWaiver',
    context: context,
  );

  @override
  Future<bool> submitWaiver({
    required String obligationId,
    required String reason,
    required String justification,
  }) {
    return _$submitWaiverAsyncAction.run(
      () => super.submitWaiver(
        obligationId: obligationId,
        reason: reason,
        justification: justification,
      ),
    );
  }

  late final _$_WaiverStoreBaseActionController = ActionController(
    name: '_WaiverStoreBase',
    context: context,
  );

  @override
  void setFilter(String status) {
    final _$actionInfo = _$_WaiverStoreBaseActionController.startAction(
      name: '_WaiverStoreBase.setFilter',
    );
    try {
      return super.setFilter(status);
    } finally {
      _$_WaiverStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void selectWaiver(WaiverRequest waiver) {
    final _$actionInfo = _$_WaiverStoreBaseActionController.startAction(
      name: '_WaiverStoreBase.selectWaiver',
    );
    try {
      return super.selectWaiver(waiver);
    } finally {
      _$_WaiverStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearSelectedWaiver() {
    final _$actionInfo = _$_WaiverStoreBaseActionController.startAction(
      name: '_WaiverStoreBase.clearSelectedWaiver',
    );
    try {
      return super.clearSelectedWaiver();
    } finally {
      _$_WaiverStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_WaiverStoreBaseActionController.startAction(
      name: '_WaiverStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_WaiverStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
waivers: ${waivers},
selectedWaiver: ${selectedWaiver},
isSubmitting: ${isSubmitting},
filterStatus: ${filterStatus},
filteredWaivers: ${filteredWaivers},
pendingCount: ${pendingCount},
approvedCount: ${approvedCount},
rejectedCount: ${rejectedCount},
hasPending: ${hasPending}
    ''';
  }
}
