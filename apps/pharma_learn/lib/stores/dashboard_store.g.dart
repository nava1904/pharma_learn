// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashboard_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$DashboardStore on _DashboardStoreBase, Store {
  Computed<int>? _$pendingCountComputed;

  @override
  int get pendingCount => (_$pendingCountComputed ??= Computed<int>(
    () => super.pendingCount,
    name: '_DashboardStoreBase.pendingCount',
  )).value;
  Computed<int>? _$overdueCountComputed;

  @override
  int get overdueCount => (_$overdueCountComputed ??= Computed<int>(
    () => super.overdueCount,
    name: '_DashboardStoreBase.overdueCount',
  )).value;
  Computed<double>? _$compliancePercentComputed;

  @override
  double get compliancePercent =>
      (_$compliancePercentComputed ??= Computed<double>(
        () => super.compliancePercent,
        name: '_DashboardStoreBase.compliancePercent',
      )).value;
  Computed<List<UpcomingSession>>? _$upcomingSessionsComputed;

  @override
  List<UpcomingSession> get upcomingSessions =>
      (_$upcomingSessionsComputed ??= Computed<List<UpcomingSession>>(
        () => super.upcomingSessions,
        name: '_DashboardStoreBase.upcomingSessions',
      )).value;
  Computed<List<TrainingObligation>>? _$urgentObligationsComputed;

  @override
  List<TrainingObligation> get urgentObligations =>
      (_$urgentObligationsComputed ??= Computed<List<TrainingObligation>>(
        () => super.urgentObligations,
        name: '_DashboardStoreBase.urgentObligations',
      )).value;
  Computed<bool>? _$needsRefreshComputed;

  @override
  bool get needsRefresh => (_$needsRefreshComputed ??= Computed<bool>(
    () => super.needsRefresh,
    name: '_DashboardStoreBase.needsRefresh',
  )).value;

  late final _$isLoadingAtom = Atom(
    name: '_DashboardStoreBase.isLoading',
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
    name: '_DashboardStoreBase.errorMessage',
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

  late final _$lastRefreshedAtom = Atom(
    name: '_DashboardStoreBase.lastRefreshed',
    context: context,
  );

  @override
  DateTime? get lastRefreshed {
    _$lastRefreshedAtom.reportRead();
    return super.lastRefreshed;
  }

  @override
  set lastRefreshed(DateTime? value) {
    _$lastRefreshedAtom.reportWrite(value, super.lastRefreshed, () {
      super.lastRefreshed = value;
    });
  }

  late final _$dataAtom = Atom(
    name: '_DashboardStoreBase.data',
    context: context,
  );

  @override
  DashboardData? get data {
    _$dataAtom.reportRead();
    return super.data;
  }

  @override
  set data(DashboardData? value) {
    _$dataAtom.reportWrite(value, super.data, () {
      super.data = value;
    });
  }

  late final _$loadDashboardAsyncAction = AsyncAction(
    '_DashboardStoreBase.loadDashboard',
    context: context,
  );

  @override
  Future<void> loadDashboard({bool forceRefresh = false}) {
    return _$loadDashboardAsyncAction.run(
      () => super.loadDashboard(forceRefresh: forceRefresh),
    );
  }

  late final _$_DashboardStoreBaseActionController = ActionController(
    name: '_DashboardStoreBase',
    context: context,
  );

  @override
  void clearError() {
    final _$actionInfo = _$_DashboardStoreBaseActionController.startAction(
      name: '_DashboardStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_DashboardStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
lastRefreshed: ${lastRefreshed},
data: ${data},
pendingCount: ${pendingCount},
overdueCount: ${overdueCount},
compliancePercent: ${compliancePercent},
upcomingSessions: ${upcomingSessions},
urgentObligations: ${urgentObligations},
needsRefresh: ${needsRefresh}
    ''';
  }
}
