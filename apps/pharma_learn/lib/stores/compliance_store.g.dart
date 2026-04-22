// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'compliance_store.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$ComplianceStore on _ComplianceStoreBase, Store {
  Computed<double>? _$overallComplianceComputed;

  @override
  double get overallCompliance =>
      (_$overallComplianceComputed ??= Computed<double>(
        () => super.overallCompliance,
        name: '_ComplianceStoreBase.overallCompliance',
      )).value;
  Computed<int>? _$totalEmployeesComputed;

  @override
  int get totalEmployees => (_$totalEmployeesComputed ??= Computed<int>(
    () => super.totalEmployees,
    name: '_ComplianceStoreBase.totalEmployees',
  )).value;
  Computed<int>? _$compliantEmployeesComputed;

  @override
  int get compliantEmployees => (_$compliantEmployeesComputed ??= Computed<int>(
    () => super.compliantEmployees,
    name: '_ComplianceStoreBase.compliantEmployees',
  )).value;
  Computed<int>? _$overdueCountComputed;

  @override
  int get overdueCount => (_$overdueCountComputed ??= Computed<int>(
    () => super.overdueCount,
    name: '_ComplianceStoreBase.overdueCount',
  )).value;
  Computed<List<DepartmentCompliance>>? _$sortedDepartmentsComputed;

  @override
  List<DepartmentCompliance> get sortedDepartments =>
      (_$sortedDepartmentsComputed ??= Computed<List<DepartmentCompliance>>(
        () => super.sortedDepartments,
        name: '_ComplianceStoreBase.sortedDepartments',
      )).value;
  Computed<List<EmployeeGap>>? _$criticalGapsComputed;

  @override
  List<EmployeeGap> get criticalGaps =>
      (_$criticalGapsComputed ??= Computed<List<EmployeeGap>>(
        () => super.criticalGaps,
        name: '_ComplianceStoreBase.criticalGaps',
      )).value;

  late final _$isLoadingAtom = Atom(
    name: '_ComplianceStoreBase.isLoading',
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
    name: '_ComplianceStoreBase.errorMessage',
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

  late final _$dashboardAtom = Atom(
    name: '_ComplianceStoreBase.dashboard',
    context: context,
  );

  @override
  ComplianceDashboard? get dashboard {
    _$dashboardAtom.reportRead();
    return super.dashboard;
  }

  @override
  set dashboard(ComplianceDashboard? value) {
    _$dashboardAtom.reportWrite(value, super.dashboard, () {
      super.dashboard = value;
    });
  }

  late final _$departmentStatsAtom = Atom(
    name: '_ComplianceStoreBase.departmentStats',
    context: context,
  );

  @override
  ObservableList<DepartmentCompliance> get departmentStats {
    _$departmentStatsAtom.reportRead();
    return super.departmentStats;
  }

  @override
  set departmentStats(ObservableList<DepartmentCompliance> value) {
    _$departmentStatsAtom.reportWrite(value, super.departmentStats, () {
      super.departmentStats = value;
    });
  }

  late final _$roleStatsAtom = Atom(
    name: '_ComplianceStoreBase.roleStats',
    context: context,
  );

  @override
  ObservableList<RoleCompliance> get roleStats {
    _$roleStatsAtom.reportRead();
    return super.roleStats;
  }

  @override
  set roleStats(ObservableList<RoleCompliance> value) {
    _$roleStatsAtom.reportWrite(value, super.roleStats, () {
      super.roleStats = value;
    });
  }

  late final _$employeeGapsAtom = Atom(
    name: '_ComplianceStoreBase.employeeGaps',
    context: context,
  );

  @override
  ObservableList<EmployeeGap> get employeeGaps {
    _$employeeGapsAtom.reportRead();
    return super.employeeGaps;
  }

  @override
  set employeeGaps(ObservableList<EmployeeGap> value) {
    _$employeeGapsAtom.reportWrite(value, super.employeeGaps, () {
      super.employeeGaps = value;
    });
  }

  late final _$selectedDepartmentIdAtom = Atom(
    name: '_ComplianceStoreBase.selectedDepartmentId',
    context: context,
  );

  @override
  String? get selectedDepartmentId {
    _$selectedDepartmentIdAtom.reportRead();
    return super.selectedDepartmentId;
  }

  @override
  set selectedDepartmentId(String? value) {
    _$selectedDepartmentIdAtom.reportWrite(
      value,
      super.selectedDepartmentId,
      () {
        super.selectedDepartmentId = value;
      },
    );
  }

  late final _$selectedRoleIdAtom = Atom(
    name: '_ComplianceStoreBase.selectedRoleId',
    context: context,
  );

  @override
  String? get selectedRoleId {
    _$selectedRoleIdAtom.reportRead();
    return super.selectedRoleId;
  }

  @override
  set selectedRoleId(String? value) {
    _$selectedRoleIdAtom.reportWrite(value, super.selectedRoleId, () {
      super.selectedRoleId = value;
    });
  }

  late final _$loadDashboardAsyncAction = AsyncAction(
    '_ComplianceStoreBase.loadDashboard',
    context: context,
  );

  @override
  Future<void> loadDashboard() {
    return _$loadDashboardAsyncAction.run(() => super.loadDashboard());
  }

  late final _$loadDepartmentStatsAsyncAction = AsyncAction(
    '_ComplianceStoreBase.loadDepartmentStats',
    context: context,
  );

  @override
  Future<void> loadDepartmentStats() {
    return _$loadDepartmentStatsAsyncAction.run(
      () => super.loadDepartmentStats(),
    );
  }

  late final _$loadRoleStatsAsyncAction = AsyncAction(
    '_ComplianceStoreBase.loadRoleStats',
    context: context,
  );

  @override
  Future<void> loadRoleStats({String? departmentId}) {
    return _$loadRoleStatsAsyncAction.run(
      () => super.loadRoleStats(departmentId: departmentId),
    );
  }

  late final _$loadEmployeeGapsAsyncAction = AsyncAction(
    '_ComplianceStoreBase.loadEmployeeGaps',
    context: context,
  );

  @override
  Future<void> loadEmployeeGaps({String? departmentId, String? roleId}) {
    return _$loadEmployeeGapsAsyncAction.run(
      () => super.loadEmployeeGaps(departmentId: departmentId, roleId: roleId),
    );
  }

  late final _$_ComplianceStoreBaseActionController = ActionController(
    name: '_ComplianceStoreBase',
    context: context,
  );

  @override
  void setDepartmentFilter(String? departmentId) {
    final _$actionInfo = _$_ComplianceStoreBaseActionController.startAction(
      name: '_ComplianceStoreBase.setDepartmentFilter',
    );
    try {
      return super.setDepartmentFilter(departmentId);
    } finally {
      _$_ComplianceStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void setRoleFilter(String? roleId) {
    final _$actionInfo = _$_ComplianceStoreBaseActionController.startAction(
      name: '_ComplianceStoreBase.setRoleFilter',
    );
    try {
      return super.setRoleFilter(roleId);
    } finally {
      _$_ComplianceStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  void clearError() {
    final _$actionInfo = _$_ComplianceStoreBaseActionController.startAction(
      name: '_ComplianceStoreBase.clearError',
    );
    try {
      return super.clearError();
    } finally {
      _$_ComplianceStoreBaseActionController.endAction(_$actionInfo);
    }
  }

  @override
  String toString() {
    return '''
isLoading: ${isLoading},
errorMessage: ${errorMessage},
dashboard: ${dashboard},
departmentStats: ${departmentStats},
roleStats: ${roleStats},
employeeGaps: ${employeeGaps},
selectedDepartmentId: ${selectedDepartmentId},
selectedRoleId: ${selectedRoleId},
overallCompliance: ${overallCompliance},
totalEmployees: ${totalEmployees},
compliantEmployees: ${compliantEmployees},
overdueCount: ${overdueCount},
sortedDepartments: ${sortedDepartments},
criticalGaps: ${criticalGaps}
    ''';
  }
}
