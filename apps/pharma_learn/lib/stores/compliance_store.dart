import 'package:injectable/injectable.dart';
import 'package:mobx/mobx.dart';

import '../core/api/api_client.dart';

part 'compliance_store.g.dart';

/// Store for compliance coordinator dashboard.
/// Shows compliance % by department, role, and identifies gaps.
@singleton
class ComplianceStore = _ComplianceStoreBase with _$ComplianceStore;

abstract class _ComplianceStoreBase with Store {
  final ApiClient _api;
  
  _ComplianceStoreBase(this._api);
  
  // ---------------------------------------------------------------------------
  // Observable State
  // ---------------------------------------------------------------------------
  
  @observable
  bool isLoading = false;
  
  @observable
  String? errorMessage;
  
  @observable
  ComplianceDashboard? dashboard;
  
  @observable
  ObservableList<DepartmentCompliance> departmentStats = ObservableList<DepartmentCompliance>();
  
  @observable
  ObservableList<RoleCompliance> roleStats = ObservableList<RoleCompliance>();
  
  @observable
  ObservableList<EmployeeGap> employeeGaps = ObservableList<EmployeeGap>();
  
  @observable
  String? selectedDepartmentId;
  
  @observable
  String? selectedRoleId;
  
  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------
  
  @computed
  double get overallCompliance => dashboard?.compliancePercent ?? 0.0;
  
  @computed
  int get totalEmployees => dashboard?.totalEmployees ?? 0;
  
  @computed
  int get compliantEmployees => dashboard?.compliantEmployees ?? 0;
  
  @computed
  int get overdueCount => dashboard?.overdueCount ?? 0;
  
  @computed
  List<DepartmentCompliance> get sortedDepartments {
    final list = departmentStats.toList();
    list.sort((a, b) => a.compliancePercent.compareTo(b.compliancePercent));
    return list; // Worst first
  }
  
  @computed
  List<EmployeeGap> get criticalGaps =>
      employeeGaps.where((g) => g.gapPercent > 50).toList();
  
  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  
  @action
  Future<void> loadDashboard() async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final response = await _api.get('/v1/compliance/dashboard');
      final data = response.data as Map<String, dynamic>;
      dashboard = ComplianceDashboard.fromJson(data['data'] ?? data);
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> loadDepartmentStats() async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final response = await _api.get('/v1/compliance/departments');
      final data = response.data as Map<String, dynamic>;
      final list = data['data']?['departments'] ?? data['departments'] ?? [];
      departmentStats = ObservableList.of(
        (list as List).map((d) => DepartmentCompliance.fromJson(d)).toList(),
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> loadRoleStats({String? departmentId}) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final params = <String, String>{};
      if (departmentId != null) params['department_id'] = departmentId;
      
      final response = await _api.get(
        '/v1/compliance/roles',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['data']?['roles'] ?? data['roles'] ?? [];
      roleStats = ObservableList.of(
        (list as List).map((r) => RoleCompliance.fromJson(r)).toList(),
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  Future<void> loadEmployeeGaps({
    String? departmentId,
    String? roleId,
  }) async {
    isLoading = true;
    errorMessage = null;
    
    try {
      final params = <String, String>{};
      if (departmentId != null) params['department_id'] = departmentId;
      if (roleId != null) params['role_id'] = roleId;
      
      final response = await _api.get(
        '/v1/certify/competencies/gaps',
        queryParameters: params,
      );
      final data = response.data as Map<String, dynamic>;
      final list = data['gaps'] ?? [];
      employeeGaps = ObservableList.of(
        (list as List).map((g) => EmployeeGap.fromJson(g)).toList(),
      );
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
    }
  }
  
  @action
  void setDepartmentFilter(String? departmentId) {
    selectedDepartmentId = departmentId;
  }
  
  @action
  void setRoleFilter(String? roleId) {
    selectedRoleId = roleId;
  }
  
  @action
  void clearError() {
    errorMessage = null;
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class ComplianceDashboard {
  final double compliancePercent;
  final int totalEmployees;
  final int compliantEmployees;
  final int overdueCount;
  final int upcomingDue;
  final int certificatesExpiring30d;
  
  ComplianceDashboard({
    required this.compliancePercent,
    required this.totalEmployees,
    required this.compliantEmployees,
    required this.overdueCount,
    required this.upcomingDue,
    required this.certificatesExpiring30d,
  });
  
  factory ComplianceDashboard.fromJson(Map<String, dynamic> json) {
    return ComplianceDashboard(
      compliancePercent: (json['compliance_percent'] as num?)?.toDouble() ?? 0.0,
      totalEmployees: json['total_employees'] ?? 0,
      compliantEmployees: json['compliant'] ?? json['compliant_employees'] ?? 0,
      overdueCount: json['overdue'] ?? json['overdue_count'] ?? 0,
      upcomingDue: json['upcoming_due'] ?? 0,
      certificatesExpiring30d: json['certificates_expiring_30d'] ?? 0,
    );
  }
}

class DepartmentCompliance {
  final String id;
  final String name;
  final double compliancePercent;
  final int totalEmployees;
  final int compliant;
  final int overdue;
  
  DepartmentCompliance({
    required this.id,
    required this.name,
    required this.compliancePercent,
    required this.totalEmployees,
    required this.compliant,
    required this.overdue,
  });
  
  factory DepartmentCompliance.fromJson(Map<String, dynamic> json) {
    return DepartmentCompliance(
      id: json['id'],
      name: json['name'],
      compliancePercent: (json['compliance_percent'] as num?)?.toDouble() ?? 0.0,
      totalEmployees: json['total_employees'] ?? 0,
      compliant: json['compliant'] ?? 0,
      overdue: json['overdue'] ?? 0,
    );
  }
}

class RoleCompliance {
  final String id;
  final String name;
  final double compliancePercent;
  final int totalEmployees;
  final int compliant;
  
  RoleCompliance({
    required this.id,
    required this.name,
    required this.compliancePercent,
    required this.totalEmployees,
    required this.compliant,
  });
  
  factory RoleCompliance.fromJson(Map<String, dynamic> json) {
    return RoleCompliance(
      id: json['id'],
      name: json['name'],
      compliancePercent: (json['compliance_percent'] as num?)?.toDouble() ?? 0.0,
      totalEmployees: json['total_employees'] ?? 0,
      compliant: json['compliant'] ?? 0,
    );
  }
}

class EmployeeGap {
  final String employeeId;
  final String employeeName;
  final String employeeNumber;
  final String? department;
  final String? jobRole;
  final int requiredCompetencies;
  final int certifiedCompetencies;
  final int gapPercent;
  final List<String> missingCompetencies;
  
  EmployeeGap({
    required this.employeeId,
    required this.employeeName,
    required this.employeeNumber,
    this.department,
    this.jobRole,
    required this.requiredCompetencies,
    required this.certifiedCompetencies,
    required this.gapPercent,
    required this.missingCompetencies,
  });
  
  factory EmployeeGap.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] as Map<String, dynamic>? ?? {};
    final missing = json['missing_competencies'] as List? ?? [];
    
    return EmployeeGap(
      employeeId: employee['id'] ?? json['employee_id'],
      employeeName: employee['name'] ?? json['employee_name'] ?? '',
      employeeNumber: employee['employee_number'] ?? json['employee_number'] ?? '',
      department: employee['department'] ?? json['department'],
      jobRole: json['job_role'],
      requiredCompetencies: json['required_competencies'] ?? 0,
      certifiedCompetencies: json['certified_competencies'] ?? 0,
      gapPercent: json['gap_percentage'] ?? 0,
      missingCompetencies: missing.map((m) {
        if (m is Map) return m['name'] as String? ?? '';
        return m.toString();
      }).toList(),
    );
  }
}
