/// Report template definitions for the S6 reporting system.
///
/// Each template defines:
/// - Unique ID (used in API and database)
/// - Human-readable name and description
/// - Required and optional parameters with their types
/// - Whether PDF and/or CSV exports are supported
/// - Default priority in the job queue
library;

/// Supported parameter types for report filters.
enum ReportParamType {
  uuid,
  date,
  dateTime,
  integer,
  string,
  boolean,
}

/// Definition of a report parameter.
class ReportParam {
  final String name;
  final String label;
  final ReportParamType type;
  final bool required;
  final dynamic defaultValue;
  final String? description;

  const ReportParam({
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'label': label,
        'type': type.name,
        'required': required,
        if (defaultValue != null) 'default': defaultValue,
        if (description != null) 'description': description,
      };
}

/// Report template metadata.
class ReportTemplate {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<ReportParam> parameters;
  final bool supportsPdf;
  final bool supportsCsv;
  final int defaultPriority;

  const ReportTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.parameters,
    this.supportsPdf = true,
    this.supportsCsv = true,
    this.defaultPriority = 5,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'parameters': parameters.map((p) => p.toJson()).toList(),
        'supports_pdf': supportsPdf,
        'supports_csv': supportsCsv,
        'default_priority': defaultPriority,
      };

  /// Registry of all available report templates.
  static const List<ReportTemplate> all = [
    employeeTrainingDossier,
    departmentComplianceSummary,
    overdueTrainingReport,
    certificateExpiryReport,
    sopAcknowledgmentReport,
    assessmentPerformanceReport,
    esignatureAuditReport,
    systemAccessLogReport,
    integrityVerificationReport,
    auditReadinessReport,
    // New templates added for Phase 6
    qualifiedTrainerReport,
    courseListReport,
    sessionBatchReport,
    inductionStatusReport,
    ojtCompletionReport,
    pendingTrainingReport,
    attendanceReport,
    trainingMatrixCoverageReport,
  ];

  /// Lookup template by ID.
  static ReportTemplate? byId(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Template Definitions
  // ---------------------------------------------------------------------------

  /// Employee Training Dossier
  /// Single-employee complete training history for inspector walkthroughs.
  /// Priority 1 (highest) for urgent inspector requests.
  static const employeeTrainingDossier = ReportTemplate(
    id: 'employee_training_dossier',
    name: 'Employee Training Dossier',
    description:
        'Complete training history for a single employee including all training records, '
        'certificates, waivers, competency attestations, and OJT completions. '
        'Primary deliverable for regulatory inspections.',
    category: 'compliance',
    defaultPriority: 1,
    supportsCsv: false, // Formatted document, not tabular
    parameters: [
      ReportParam(
        name: 'employee_id',
        label: 'Employee',
        type: ReportParamType.uuid,
        required: true,
        description: 'The employee whose dossier to generate',
      ),
      ReportParam(
        name: 'as_of',
        label: 'As Of Date',
        type: ReportParamType.date,
        required: false,
        description:
            'Generate dossier as of this date (for historical compliance verification)',
      ),
    ],
  );

  /// Department Compliance Summary
  /// Compliance status rollup by department with overdue counts.
  static const departmentComplianceSummary = ReportTemplate(
    id: 'department_compliance_summary',
    name: 'Department Compliance Summary',
    description:
        'Compliance status summary for a department including compliant/non-compliant '
        'employee counts, overdue training details, and trend data.',
    category: 'compliance',
    parameters: [
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department (omit for all departments)',
      ),
      ReportParam(
        name: 'plant_id',
        label: 'Plant',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific plant',
      ),
      ReportParam(
        name: 'date_from',
        label: 'From Date',
        type: ReportParamType.date,
        required: false,
        description: 'Start of reporting period',
      ),
      ReportParam(
        name: 'date_to',
        label: 'To Date',
        type: ReportParamType.date,
        required: false,
        description: 'End of reporting period',
      ),
      ReportParam(
        name: 'as_of',
        label: 'As Of Date',
        type: ReportParamType.date,
        required: false,
        description: 'Compliance status as of this date',
      ),
    ],
  );

  /// Overdue Training Report
  /// List of all overdue training obligations with employee details.
  static const overdueTrainingReport = ReportTemplate(
    id: 'overdue_training_report',
    name: 'Overdue Training Report',
    description:
        'List of all training obligations that are past their due date, '
        'grouped by department with employee details and days overdue.',
    category: 'compliance',
    parameters: [
      ReportParam(
        name: 'plant_id',
        label: 'Plant',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific plant',
      ),
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
      ReportParam(
        name: 'threshold_days',
        label: 'Minimum Days Overdue',
        type: ReportParamType.integer,
        required: false,
        defaultValue: 0,
        description: 'Only include items overdue by at least this many days',
      ),
      ReportParam(
        name: 'course_id',
        label: 'Course',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific course',
      ),
    ],
  );

  /// Certificate Expiry Report
  /// Certificates expiring within a specified window.
  static const certificateExpiryReport = ReportTemplate(
    id: 'certificate_expiry_report',
    name: 'Certificate Expiry Report',
    description:
        'List of certificates expiring within the specified number of days, '
        'with employee details and renewal status.',
    category: 'certificates',
    parameters: [
      ReportParam(
        name: 'expiry_within_days',
        label: 'Expiring Within (Days)',
        type: ReportParamType.integer,
        required: false,
        defaultValue: 90,
        description: 'Show certificates expiring within this many days',
      ),
      ReportParam(
        name: 'plant_id',
        label: 'Plant',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific plant',
      ),
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
      ReportParam(
        name: 'include_expired',
        label: 'Include Already Expired',
        type: ReportParamType.boolean,
        required: false,
        defaultValue: false,
        description: 'Include certificates that have already expired',
      ),
    ],
  );

  /// SOP Acknowledgment Report
  /// Document read acknowledgment coverage for SOPs.
  static const sopAcknowledgmentReport = ReportTemplate(
    id: 'sop_acknowledgment_report',
    name: 'SOP Acknowledgment Coverage',
    description:
        'Document read acknowledgment status showing which employees have '
        'acknowledged reading a specific document or set of documents.',
    category: 'documents',
    parameters: [
      ReportParam(
        name: 'document_id',
        label: 'Document',
        type: ReportParamType.uuid,
        required: false,
        description: 'Specific document to check (omit for all)',
      ),
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
      ReportParam(
        name: 'as_of',
        label: 'As Of Date',
        type: ReportParamType.date,
        required: false,
        description: 'Acknowledgment status as of this date',
      ),
      ReportParam(
        name: 'document_type',
        label: 'Document Type',
        type: ReportParamType.string,
        required: false,
        description: 'Filter by document type (SOP, WI, Policy, etc.)',
      ),
    ],
  );

  /// Assessment Performance Report
  /// Pass/fail rates and score distributions for assessments.
  static const assessmentPerformanceReport = ReportTemplate(
    id: 'assessment_performance_report',
    name: 'Assessment Performance Report',
    description:
        'Assessment pass/fail rates, score distributions, and trend analysis '
        'for a specific course or across all courses.',
    category: 'assessments',
    parameters: [
      ReportParam(
        name: 'course_id',
        label: 'Course',
        type: ReportParamType.uuid,
        required: false,
        description: 'Specific course to analyze (omit for all courses)',
      ),
      ReportParam(
        name: 'date_from',
        label: 'From Date',
        type: ReportParamType.date,
        required: false,
        description: 'Start of analysis period',
      ),
      ReportParam(
        name: 'date_to',
        label: 'To Date',
        type: ReportParamType.date,
        required: false,
        description: 'End of analysis period',
      ),
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
    ],
  );

  /// E-Signature Audit Report
  /// Complete audit trail of all electronic signatures.
  /// Required for 21 CFR Part 11 §11.50 compliance verification.
  static const esignatureAuditReport = ReportTemplate(
    id: 'esignature_audit_report',
    name: 'E-Signature Audit Trail',
    description:
        'Complete audit trail of all electronic signatures including signer identity, '
        'timestamp, meaning, and the entity signed. Required for 21 CFR Part 11 compliance.',
    category: 'audit',
    parameters: [
      ReportParam(
        name: 'date_from',
        label: 'From Date',
        type: ReportParamType.date,
        required: true,
        description: 'Start of audit period',
      ),
      ReportParam(
        name: 'date_to',
        label: 'To Date',
        type: ReportParamType.date,
        required: true,
        description: 'End of audit period',
      ),
      ReportParam(
        name: 'entity_type',
        label: 'Entity Type',
        type: ReportParamType.string,
        required: false,
        description:
            'Filter by entity type (document, course, certificate, etc.)',
      ),
      ReportParam(
        name: 'employee_id',
        label: 'Signer',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to signatures by specific employee',
      ),
    ],
  );

  /// System Access Log Report
  /// Login/logout history for regulatory compliance.
  /// Required by EU Annexure 11 §9.
  static const systemAccessLogReport = ReportTemplate(
    id: 'system_access_log_report',
    name: 'System Access Log',
    description:
        'Login and logout history including IP addresses, user agents, and session durations. '
        'Required for EU Annexure 11 compliance.',
    category: 'audit',
    parameters: [
      ReportParam(
        name: 'date_from',
        label: 'From Date',
        type: ReportParamType.date,
        required: true,
        description: 'Start of log period',
      ),
      ReportParam(
        name: 'date_to',
        label: 'To Date',
        type: ReportParamType.date,
        required: true,
        description: 'End of log period',
      ),
      ReportParam(
        name: 'employee_id',
        label: 'Employee',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific employee',
      ),
      ReportParam(
        name: 'event_type',
        label: 'Event Type',
        type: ReportParamType.string,
        required: false,
        description: 'Filter by event type (LOGIN, LOGOUT, SESSION_TIMEOUT)',
      ),
    ],
  );

  /// Integrity Verification Report
  /// Audit trail hash chain verification attestation.
  static const integrityVerificationReport = ReportTemplate(
    id: 'integrity_verification_report',
    name: 'Audit Trail Integrity Report',
    description:
        'Verification report confirming the integrity of the audit trail hash chain. '
        'This attestation document records the verification result and is signed by QA.',
    category: 'audit',
    defaultPriority: 3,
    supportsCsv: false, // Attestation document, not tabular
    parameters: [
      ReportParam(
        name: 'as_of',
        label: 'Verify Up To Date',
        type: ReportParamType.date,
        required: false,
        description: 'Verify all audit records up to this date',
      ),
    ],
  );

  /// Audit Readiness Report
  /// Comprehensive umbrella report for regulatory inspection preparation.
  /// Aggregates key metrics from multiple sub-reports.
  static const auditReadinessReport = ReportTemplate(
    id: 'audit_readiness_report',
    name: 'Full Audit Readiness Report',
    description:
        'Comprehensive compliance report for regulatory inspection preparation. '
        'Includes compliance summary, overdue training, certificate status, '
        'and key metrics. Each section can be exported separately for detail.',
    category: 'compliance',
    defaultPriority: 8, // Lower priority, large report
    supportsCsv: false, // Composite document
    parameters: [
      ReportParam(
        name: 'plant_id',
        label: 'Plant',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific plant',
      ),
      ReportParam(
        name: 'as_of',
        label: 'As Of Date',
        type: ReportParamType.date,
        required: false,
        description: 'Compliance status as of this date',
      ),
      ReportParam(
        name: 'include_details',
        label: 'Include Detailed Lists',
        type: ReportParamType.boolean,
        required: false,
        defaultValue: true,
        description: 'Include detailed employee-level data (increases report size)',
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // Phase 6: Additional Standard Report Templates
  // ---------------------------------------------------------------------------

  /// Qualified Trainer Report
  /// List of all qualified trainers with their certifications and competencies.
  static const qualifiedTrainerReport = ReportTemplate(
    id: 'qualified_trainer_report',
    name: 'Qualified Trainer Report',
    description:
        'List of all qualified trainers with their certification status, '
        'competencies, training areas, and expiry dates.',
    category: 'trainers',
    parameters: [
      ReportParam(
        name: 'plant_id',
        label: 'Plant',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific plant',
      ),
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
      ReportParam(
        name: 'topic_id',
        label: 'Training Topic',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to trainers qualified for specific topic',
      ),
      ReportParam(
        name: 'include_external',
        label: 'Include External Trainers',
        type: ReportParamType.boolean,
        required: false,
        defaultValue: true,
        description: 'Include external/contract trainers',
      ),
      ReportParam(
        name: 'active_only',
        label: 'Active Trainers Only',
        type: ReportParamType.boolean,
        required: false,
        defaultValue: true,
        description: 'Only show active trainers with valid certifications',
      ),
    ],
  );

  /// Course List Report
  /// Master list of all courses with their status and metadata.
  static const courseListReport = ReportTemplate(
    id: 'course_list_report',
    name: 'Course Master List',
    description:
        'Complete list of all courses with revision numbers, status, '
        'linked documents, topics, and effective dates.',
    category: 'training',
    parameters: [
      ReportParam(
        name: 'status',
        label: 'Course Status',
        type: ReportParamType.string,
        required: false,
        description: 'Filter by status (draft, approved, effective, obsolete)',
      ),
      ReportParam(
        name: 'topic_id',
        label: 'Topic',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to courses under specific topic',
      ),
      ReportParam(
        name: 'subject_id',
        label: 'Subject',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to courses under specific subject',
      ),
      ReportParam(
        name: 'delivery_method',
        label: 'Delivery Method',
        type: ReportParamType.string,
        required: false,
        description: 'Filter by delivery method (ilt, self_study, ojt, document)',
      ),
      ReportParam(
        name: 'effective_date_from',
        label: 'Effective From',
        type: ReportParamType.date,
        required: false,
        description: 'Only courses effective on or after this date',
      ),
    ],
  );

  /// Session/Batch Report
  /// Training sessions and batches with attendance summary.
  static const sessionBatchReport = ReportTemplate(
    id: 'session_batch_report',
    name: 'Training Session & Batch Report',
    description:
        'List of all training sessions and batches with trainer details, '
        'attendance summary, pass rates, and completion status.',
    category: 'training',
    parameters: [
      ReportParam(
        name: 'date_from',
        label: 'From Date',
        type: ReportParamType.date,
        required: false,
        description: 'Start of reporting period',
      ),
      ReportParam(
        name: 'date_to',
        label: 'To Date',
        type: ReportParamType.date,
        required: false,
        description: 'End of reporting period',
      ),
      ReportParam(
        name: 'course_id',
        label: 'Course',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific course',
      ),
      ReportParam(
        name: 'trainer_id',
        label: 'Trainer',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific trainer',
      ),
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to sessions for specific department',
      ),
      ReportParam(
        name: 'status',
        label: 'Session Status',
        type: ReportParamType.string,
        required: false,
        description: 'Filter by status (scheduled, in_progress, completed, cancelled)',
      ),
    ],
  );

  /// Induction Status Report
  /// Induction completion status for employees.
  static const inductionStatusReport = ReportTemplate(
    id: 'induction_status_report',
    name: 'Induction Status Report',
    description:
        'Induction completion status for all employees showing module progress, '
        'completion dates, and pending modules.',
    category: 'compliance',
    parameters: [
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
      ReportParam(
        name: 'plant_id',
        label: 'Plant',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific plant',
      ),
      ReportParam(
        name: 'status',
        label: 'Completion Status',
        type: ReportParamType.string,
        required: false,
        description: 'Filter by status (completed, in_progress, not_started)',
      ),
      ReportParam(
        name: 'hire_date_from',
        label: 'Hire Date From',
        type: ReportParamType.date,
        required: false,
        description: 'Filter to employees hired on or after this date',
      ),
      ReportParam(
        name: 'hire_date_to',
        label: 'Hire Date To',
        type: ReportParamType.date,
        required: false,
        description: 'Filter to employees hired on or before this date',
      ),
    ],
  );

  /// OJT Completion Report
  /// On-the-Job Training assignment and completion status.
  static const ojtCompletionReport = ReportTemplate(
    id: 'ojt_completion_report',
    name: 'OJT Completion Report',
    description:
        'On-the-Job Training assignments with task completion status, '
        'sign-off details, and competency assessment results.',
    category: 'training',
    parameters: [
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
      ReportParam(
        name: 'course_id',
        label: 'Course/OJT Module',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific OJT course or module',
      ),
      ReportParam(
        name: 'trainer_id',
        label: 'OJT Trainer',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter by OJT trainer/assessor',
      ),
      ReportParam(
        name: 'date_from',
        label: 'From Date',
        type: ReportParamType.date,
        required: false,
        description: 'Assignment date from',
      ),
      ReportParam(
        name: 'date_to',
        label: 'To Date',
        type: ReportParamType.date,
        required: false,
        description: 'Assignment date to',
      ),
      ReportParam(
        name: 'status',
        label: 'Status',
        type: ReportParamType.string,
        required: false,
        description: 'Filter by status (pending, in_progress, completed, failed)',
      ),
    ],
  );

  /// Pending Training Report
  /// All employees with pending training obligations.
  static const pendingTrainingReport = ReportTemplate(
    id: 'pending_training_report',
    name: 'Pending Training Report',
    description:
        'List of all pending training obligations showing employees who need '
        'to complete training with due dates and assignment sources.',
    category: 'compliance',
    parameters: [
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
      ReportParam(
        name: 'plant_id',
        label: 'Plant',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific plant',
      ),
      ReportParam(
        name: 'course_id',
        label: 'Course',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific course',
      ),
      ReportParam(
        name: 'due_within_days',
        label: 'Due Within (Days)',
        type: ReportParamType.integer,
        required: false,
        description: 'Show obligations due within this many days',
      ),
      ReportParam(
        name: 'include_overdue',
        label: 'Include Overdue',
        type: ReportParamType.boolean,
        required: false,
        defaultValue: true,
        description: 'Include items that are already overdue',
      ),
    ],
  );

  /// Attendance Report
  /// Session attendance records with time tracking.
  static const attendanceReport = ReportTemplate(
    id: 'attendance_report',
    name: 'Attendance Report',
    description:
        'Session attendance records showing check-in/check-out times, '
        'attendance percentage, and any corrections made.',
    category: 'training',
    parameters: [
      ReportParam(
        name: 'date_from',
        label: 'From Date',
        type: ReportParamType.date,
        required: true,
        description: 'Start of reporting period',
      ),
      ReportParam(
        name: 'date_to',
        label: 'To Date',
        type: ReportParamType.date,
        required: true,
        description: 'End of reporting period',
      ),
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
      ReportParam(
        name: 'batch_id',
        label: 'Training Batch',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific training batch',
      ),
      ReportParam(
        name: 'session_id',
        label: 'Session',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific session',
      ),
      ReportParam(
        name: 'include_corrections',
        label: 'Show Corrections',
        type: ReportParamType.boolean,
        required: false,
        defaultValue: false,
        description: 'Include attendance correction history',
      ),
    ],
  );

  /// Training Matrix Coverage Report
  /// Coverage analysis for training matrices.
  static const trainingMatrixCoverageReport = ReportTemplate(
    id: 'training_matrix_coverage_report',
    name: 'Training Matrix Coverage Report',
    description:
        'Compliance coverage analysis for training matrices showing '
        'percentage completion by role, department, and individual items.',
    category: 'compliance',
    parameters: [
      ReportParam(
        name: 'matrix_id',
        label: 'Training Matrix',
        type: ReportParamType.uuid,
        required: false,
        description: 'Specific matrix to analyze (omit for all)',
      ),
      ReportParam(
        name: 'department_id',
        label: 'Department',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific department',
      ),
      ReportParam(
        name: 'role_id',
        label: 'Role',
        type: ReportParamType.uuid,
        required: false,
        description: 'Filter to specific role',
      ),
      ReportParam(
        name: 'as_of',
        label: 'As Of Date',
        type: ReportParamType.date,
        required: false,
        description: 'Coverage status as of this date',
      ),
      ReportParam(
        name: 'show_gaps_only',
        label: 'Show Gaps Only',
        type: ReportParamType.boolean,
        required: false,
        defaultValue: false,
        description: 'Only show employees with compliance gaps',
      ),
    ],
  );
}
