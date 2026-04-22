/// Permission string constants used across the platform.
abstract final class Permissions {
  // Documents
  static const String approveDocuments = 'documents.approve';
  static const String createDocuments = 'documents.create';
  static const String editDocuments = 'documents.edit';
  static const String viewDocuments = 'documents.view';
  static const String deleteDocuments = 'documents.delete';

  // Courses
  static const String approveCourses = 'courses.approve';
  static const String createCourses = 'courses.create';
  static const String editCourses = 'courses.edit';
  static const String viewCourses = 'courses.view';

  // GTPs (Good Training Practices)
  static const String approveGtps = 'gtps.approve';
  static const String createGtps = 'gtps.create';
  static const String editGtps = 'gtps.edit';

  // Compliance
  static const String viewCompliance = 'compliance.view';
  static const String manageCompliance = 'compliance.manage';

  // Certificates
  static const String manageCertificates = 'certificates.manage';
  static const String revokeCertificates = 'certificates.revoke';
  static const String viewCertificates = 'certificates.view';

  // Employees
  static const String manageEmployees = 'employees.manage';
  static const String viewEmployees = 'employees.view';

  // Roles & Permissions
  static const String manageRoles = 'roles.manage';
  static const String viewRoles = 'roles.view';

  // Audit
  static const String viewAudit = 'audit.view';

  // Approvals
  static const String manageApprovals = 'approvals.manage';
  static const String viewApprovals = 'approvals.view';

  // Assessments
  static const String manageAssessments = 'assessments.manage';
  static const String viewAssessments = 'assessments.view';
  static const String viewAssessmentResults = 'assessments.results.view';
  static const String gradeAssessments = 'assessments.grade';

  // Competencies
  static const String manageCompetencies = 'competencies.manage';
  static const String viewCompetencies = 'competencies.view';

  // Training
  static const String manageTraining = 'training.manage';
  static const String viewTraining = 'training.view';
  static const String manageAttendance = 'training.attendance.manage';
  static const String manageSessions = 'training.sessions.manage';
  static const String manageSchedules = 'training.schedules.manage';

  // Reports
  static const String viewReports = 'reports.view';
  static const String exportReports = 'reports.export';
  static const String manageReports = 'reports.manage';
}

/// Domain event type constants for the outbox/event-sourcing pattern.
abstract final class EventTypes {
  // Auth
  static const String authLogin = 'auth.login';
  static const String authLogout = 'auth.logout';
  static const String authTokenRefreshed = 'auth.token_refreshed';
  static const String authSessionRevoked = 'auth.session_revoked';

  // Documents
  static const String documentCreated = 'document.created';
  static const String documentSubmitted = 'document.submitted';
  static const String documentApproved = 'document.approved';
  static const String documentRejected = 'document.rejected';
  static const String documentRevoked = 'document.revoked';

  // Courses
  static const String courseCreated = 'course.created';
  static const String courseApproved = 'course.approved';
  static const String courseRejected = 'course.rejected';
  static const String coursePublished = 'course.published';

  // Assessments
  static const String assessmentCreated = 'assessment.created';
  static const String assessmentSubmitted = 'assessment.submitted';
  static const String assessmentGraded = 'assessment.graded';

  // Certificates
  static const String certificateIssued = 'certificate.issued';
  static const String certificateRevoked = 'certificate.revoked';
  static const String certificateExpired = 'certificate.expired';

  // Training
  static const String trainingAssigned = 'training.assigned';
  static const String trainingStarted = 'training.started';
  static const String trainingCompleted = 'training.completed';
  static const String trainingFailed = 'training.failed';

  // Sessions & Attendance
  static const String sessionStarted = 'session.started';
  static const String sessionEnded = 'session.ended';
  static const String attendanceCheckedIn = 'attendance.checked_in';
  static const String attendanceCheckedOut = 'attendance.checked_out';

  // Employees
  static const String employeeCreated = 'employee.created';
  static const String employeeUpdated = 'employee.updated';
  static const String employeeDeactivated = 'employee.deactivated';
}

/// Paths that the auth middleware skips JWT verification for.
abstract final class PublicPaths {
  /// Exact paths that require no JWT at all.
  static const List<String> skipAuth = [
    '/health',
    '/health/detailed',
    '/v1/auth/login',
    '/v1/auth/refresh',
    '/v1/auth/sso/login',
    '/v1/auth/biometric/login',
  ];

  /// Path PREFIXES that a non-inducted employee can still access.
  /// (Checked by _isInductionAllowed in auth_middleware.dart.)
  static const List<String> inductionAllowedPrefixes = [
    '/health',
    '/v1/auth',      // login, logout, profile, password, mfa, sessions
    '/v1/induction', // the induction flow itself
    '/v1/reauth',    // reauth session needed for induction e-sig
  ];
}
