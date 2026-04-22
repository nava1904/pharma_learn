/// Compliance report models for generating compliance reports.
/// 
/// Used by: GET /v1/reports/compliance
/// Reference: URS-REP-03 - Department Compliance Report
/// Reference: EE §6.2 - compliance dashboard

/// Request parameters for compliance report.
class ComplianceReportRequest {
  /// Filter by department IDs (null = all departments user can access)
  final List<String>? departmentIds;

  /// Filter by role IDs
  final List<String>? roleIds;

  /// Filter by specific employees
  final List<String>? employeeIds;

  /// Filter by course IDs
  final List<String>? courseIds;

  /// Filter by training category IDs
  final List<String>? categoryIds;

  /// Report start date (for time-based filtering)
  final DateTime? fromDate;

  /// Report end date
  final DateTime? toDate;

  /// Include only overdue training
  final bool overdueOnly;

  /// Include inactive employees
  final bool includeInactive;

  /// Group results by ('department', 'role', 'employee', 'course', 'category')
  final String groupBy;

  /// Report format ('summary', 'detailed', 'matrix')
  final String format;

  const ComplianceReportRequest({
    this.departmentIds,
    this.roleIds,
    this.employeeIds,
    this.courseIds,
    this.categoryIds,
    this.fromDate,
    this.toDate,
    this.overdueOnly = false,
    this.includeInactive = false,
    this.groupBy = 'department',
    this.format = 'summary',
  });

  factory ComplianceReportRequest.fromJson(Map<String, dynamic> json) {
    return ComplianceReportRequest(
      departmentIds: (json['department_ids'] as List?)?.cast<String>(),
      roleIds: (json['role_ids'] as List?)?.cast<String>(),
      employeeIds: (json['employee_ids'] as List?)?.cast<String>(),
      courseIds: (json['course_ids'] as List?)?.cast<String>(),
      categoryIds: (json['category_ids'] as List?)?.cast<String>(),
      fromDate: json['from_date'] != null ? DateTime.parse(json['from_date']) : null,
      toDate: json['to_date'] != null ? DateTime.parse(json['to_date']) : null,
      overdueOnly: json['overdue_only'] as bool? ?? false,
      includeInactive: json['include_inactive'] as bool? ?? false,
      groupBy: json['group_by'] as String? ?? 'department',
      format: json['format'] as String? ?? 'summary',
    );
  }

  Map<String, dynamic> toJson() => {
    'department_ids': departmentIds,
    'role_ids': roleIds,
    'employee_ids': employeeIds,
    'course_ids': courseIds,
    'category_ids': categoryIds,
    'from_date': fromDate?.toIso8601String(),
    'to_date': toDate?.toIso8601String(),
    'overdue_only': overdueOnly,
    'include_inactive': includeInactive,
    'group_by': groupBy,
    'format': format,
  };
}

/// Compliance report response.
class ComplianceReportResponse {
  /// Report metadata
  final ReportMetadata metadata;

  /// Summary statistics
  final ComplianceSummary summary;

  /// Grouped data based on groupBy parameter
  final List<ComplianceGroup> groups;

  /// Individual records (for detailed format)
  final List<ComplianceRecord>? records;

  /// Matrix data (for matrix format)
  final ComplianceMatrix? matrix;

  const ComplianceReportResponse({
    required this.metadata,
    required this.summary,
    required this.groups,
    this.records,
    this.matrix,
  });

  Map<String, dynamic> toJson() => {
    'metadata': metadata.toJson(),
    'summary': summary.toJson(),
    'groups': groups.map((g) => g.toJson()).toList(),
    'records': records?.map((r) => r.toJson()).toList(),
    'matrix': matrix?.toJson(),
  };

  factory ComplianceReportResponse.fromJson(Map<String, dynamic> json) {
    return ComplianceReportResponse(
      metadata: ReportMetadata.fromJson(json['metadata']),
      summary: ComplianceSummary.fromJson(json['summary']),
      groups: (json['groups'] as List)
          .map((g) => ComplianceGroup.fromJson(g))
          .toList(),
      records: (json['records'] as List?)
          ?.map((r) => ComplianceRecord.fromJson(r))
          .toList(),
      matrix: json['matrix'] != null
          ? ComplianceMatrix.fromJson(json['matrix'])
          : null,
    );
  }
}

/// Report metadata.
class ReportMetadata {
  final String reportId;
  final String reportType;
  final DateTime generatedAt;
  final String generatedBy;
  final String generatedByName;
  final ComplianceReportRequest parameters;
  final String orgId;

  const ReportMetadata({
    required this.reportId,
    required this.reportType,
    required this.generatedAt,
    required this.generatedBy,
    required this.generatedByName,
    required this.parameters,
    required this.orgId,
  });

  Map<String, dynamic> toJson() => {
    'report_id': reportId,
    'report_type': reportType,
    'generated_at': generatedAt.toIso8601String(),
    'generated_by': generatedBy,
    'generated_by_name': generatedByName,
    'parameters': parameters.toJson(),
    'org_id': orgId,
  };

  factory ReportMetadata.fromJson(Map<String, dynamic> json) {
    return ReportMetadata(
      reportId: json['report_id'] as String,
      reportType: json['report_type'] as String,
      generatedAt: DateTime.parse(json['generated_at']),
      generatedBy: json['generated_by'] as String,
      generatedByName: json['generated_by_name'] as String,
      parameters: ComplianceReportRequest.fromJson(json['parameters']),
      orgId: json['org_id'] as String,
    );
  }
}

/// Overall compliance summary.
class ComplianceSummary {
  /// Total number of employees in scope
  final int totalEmployees;

  /// Total training assignments
  final int totalAssignments;

  /// Completed assignments
  final int completedAssignments;

  /// Overdue assignments
  final int overdueAssignments;

  /// Pending (not yet due) assignments
  final int pendingAssignments;

  /// In progress assignments
  final int inProgressAssignments;

  /// Overall compliance percentage
  final double compliancePercent;

  /// Average completion time in days
  final double? avgCompletionDays;

  const ComplianceSummary({
    required this.totalEmployees,
    required this.totalAssignments,
    required this.completedAssignments,
    required this.overdueAssignments,
    required this.pendingAssignments,
    required this.inProgressAssignments,
    required this.compliancePercent,
    this.avgCompletionDays,
  });

  Map<String, dynamic> toJson() => {
    'total_employees': totalEmployees,
    'total_assignments': totalAssignments,
    'completed_assignments': completedAssignments,
    'overdue_assignments': overdueAssignments,
    'pending_assignments': pendingAssignments,
    'in_progress_assignments': inProgressAssignments,
    'compliance_percent': compliancePercent,
    'avg_completion_days': avgCompletionDays,
  };

  factory ComplianceSummary.fromJson(Map<String, dynamic> json) {
    return ComplianceSummary(
      totalEmployees: json['total_employees'] as int,
      totalAssignments: json['total_assignments'] as int,
      completedAssignments: json['completed_assignments'] as int,
      overdueAssignments: json['overdue_assignments'] as int,
      pendingAssignments: json['pending_assignments'] as int,
      inProgressAssignments: json['in_progress_assignments'] as int,
      compliancePercent: (json['compliance_percent'] as num).toDouble(),
      avgCompletionDays: (json['avg_completion_days'] as num?)?.toDouble(),
    );
  }
}

/// Compliance data grouped by a dimension.
class ComplianceGroup {
  /// Group identifier (department_id, role_id, employee_id, course_id)
  final String groupId;

  /// Group name for display
  final String groupName;

  /// Group type ('department', 'role', 'employee', 'course', 'category')
  final String groupType;

  /// Number of employees in this group
  final int employeeCount;

  /// Total assignments in this group
  final int totalAssignments;

  /// Completed assignments
  final int completedAssignments;

  /// Overdue assignments
  final int overdueAssignments;

  /// Compliance percentage for this group
  final double compliancePercent;

  /// Trend direction ('up', 'down', 'stable') compared to previous period
  final String? trend;

  /// Trend change percentage
  final double? trendChange;

  const ComplianceGroup({
    required this.groupId,
    required this.groupName,
    required this.groupType,
    required this.employeeCount,
    required this.totalAssignments,
    required this.completedAssignments,
    required this.overdueAssignments,
    required this.compliancePercent,
    this.trend,
    this.trendChange,
  });

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'group_name': groupName,
    'group_type': groupType,
    'employee_count': employeeCount,
    'total_assignments': totalAssignments,
    'completed_assignments': completedAssignments,
    'overdue_assignments': overdueAssignments,
    'compliance_percent': compliancePercent,
    'trend': trend,
    'trend_change': trendChange,
  };

  factory ComplianceGroup.fromJson(Map<String, dynamic> json) {
    return ComplianceGroup(
      groupId: json['group_id'] as String,
      groupName: json['group_name'] as String,
      groupType: json['group_type'] as String,
      employeeCount: json['employee_count'] as int,
      totalAssignments: json['total_assignments'] as int,
      completedAssignments: json['completed_assignments'] as int,
      overdueAssignments: json['overdue_assignments'] as int,
      compliancePercent: (json['compliance_percent'] as num).toDouble(),
      trend: json['trend'] as String?,
      trendChange: (json['trend_change'] as num?)?.toDouble(),
    );
  }
}

/// Individual compliance record for detailed reports.
class ComplianceRecord {
  final String employeeId;
  final String employeeNumber;
  final String employeeName;
  final String departmentName;
  final String roleName;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String status; // 'completed', 'overdue', 'pending', 'in_progress'
  final DateTime? assignedDate;
  final DateTime? dueDate;
  final DateTime? completedDate;
  final int? score;
  final int daysOverdue;
  final String? certificateId;

  const ComplianceRecord({
    required this.employeeId,
    required this.employeeNumber,
    required this.employeeName,
    required this.departmentName,
    required this.roleName,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.status,
    this.assignedDate,
    this.dueDate,
    this.completedDate,
    this.score,
    this.daysOverdue = 0,
    this.certificateId,
  });

  Map<String, dynamic> toJson() => {
    'employee_id': employeeId,
    'employee_number': employeeNumber,
    'employee_name': employeeName,
    'department_name': departmentName,
    'role_name': roleName,
    'course_id': courseId,
    'course_code': courseCode,
    'course_name': courseName,
    'status': status,
    'assigned_date': assignedDate?.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
    'completed_date': completedDate?.toIso8601String(),
    'score': score,
    'days_overdue': daysOverdue,
    'certificate_id': certificateId,
  };

  factory ComplianceRecord.fromJson(Map<String, dynamic> json) {
    return ComplianceRecord(
      employeeId: json['employee_id'] as String,
      employeeNumber: json['employee_number'] as String,
      employeeName: json['employee_name'] as String,
      departmentName: json['department_name'] as String,
      roleName: json['role_name'] as String,
      courseId: json['course_id'] as String,
      courseCode: json['course_code'] as String,
      courseName: json['course_name'] as String,
      status: json['status'] as String,
      assignedDate: json['assigned_date'] != null 
          ? DateTime.parse(json['assigned_date']) 
          : null,
      dueDate: json['due_date'] != null 
          ? DateTime.parse(json['due_date']) 
          : null,
      completedDate: json['completed_date'] != null 
          ? DateTime.parse(json['completed_date']) 
          : null,
      score: json['score'] as int?,
      daysOverdue: json['days_overdue'] as int? ?? 0,
      certificateId: json['certificate_id'] as String?,
    );
  }
}

/// Compliance matrix for cross-tabulated data.
class ComplianceMatrix {
  /// Row headers (e.g., employee names)
  final List<MatrixHeader> rowHeaders;

  /// Column headers (e.g., course names)
  final List<MatrixHeader> columnHeaders;

  /// Matrix cells indexed by [row][column]
  final List<List<MatrixCell>> cells;

  const ComplianceMatrix({
    required this.rowHeaders,
    required this.columnHeaders,
    required this.cells,
  });

  Map<String, dynamic> toJson() => {
    'row_headers': rowHeaders.map((h) => h.toJson()).toList(),
    'column_headers': columnHeaders.map((h) => h.toJson()).toList(),
    'cells': cells.map((row) => row.map((c) => c.toJson()).toList()).toList(),
  };

  factory ComplianceMatrix.fromJson(Map<String, dynamic> json) {
    return ComplianceMatrix(
      rowHeaders: (json['row_headers'] as List)
          .map((h) => MatrixHeader.fromJson(h))
          .toList(),
      columnHeaders: (json['column_headers'] as List)
          .map((h) => MatrixHeader.fromJson(h))
          .toList(),
      cells: (json['cells'] as List)
          .map((row) => (row as List)
              .map((c) => MatrixCell.fromJson(c))
              .toList())
          .toList(),
    );
  }
}

/// Matrix header.
class MatrixHeader {
  final String id;
  final String label;
  final String? parentId;

  const MatrixHeader({
    required this.id,
    required this.label,
    this.parentId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'parent_id': parentId,
  };

  factory MatrixHeader.fromJson(Map<String, dynamic> json) {
    return MatrixHeader(
      id: json['id'] as String,
      label: json['label'] as String,
      parentId: json['parent_id'] as String?,
    );
  }
}

/// Matrix cell.
class MatrixCell {
  /// Cell status ('completed', 'overdue', 'pending', 'in_progress', 'not_required', 'na')
  final String status;

  /// Status icon/color code
  final String statusCode;

  /// Completion date if completed
  final DateTime? completedDate;

  /// Days overdue if overdue
  final int? daysOverdue;

  /// Score if applicable
  final int? score;

  const MatrixCell({
    required this.status,
    required this.statusCode,
    this.completedDate,
    this.daysOverdue,
    this.score,
  });

  Map<String, dynamic> toJson() => {
    'status': status,
    'status_code': statusCode,
    'completed_date': completedDate?.toIso8601String(),
    'days_overdue': daysOverdue,
    'score': score,
  };

  factory MatrixCell.fromJson(Map<String, dynamic> json) {
    return MatrixCell(
      status: json['status'] as String,
      statusCode: json['status_code'] as String,
      completedDate: json['completed_date'] != null 
          ? DateTime.parse(json['completed_date']) 
          : null,
      daysOverdue: json['days_overdue'] as int?,
      score: json['score'] as int?,
    );
  }
}
