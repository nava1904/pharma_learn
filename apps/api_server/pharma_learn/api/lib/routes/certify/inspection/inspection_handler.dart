import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/certify/inspection/dashboard
///
/// Returns comprehensive inspection-readiness dashboard.
/// Consolidates all compliance data needed for regulatory inspections.
/// URS Alfa §5.6.1 - Inspection support features
Future<Response> inspectionDashboardHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  final departmentId = req.url.queryParameters['department_id'];
  final now = DateTime.now().toUtc();

  // 1. Overall compliance rate
  final complianceStats = await supabase.rpc(
    'calculate_org_compliance',
    params: {
      'p_org_id': auth.orgId,
      if (departmentId != null) 'p_department_id': departmentId,
    },
  ) as List;

  // 2. Training matrix compliance
  final matrixCompliance = await supabase.rpc(
    'get_org_matrix_compliance',
    params: {'p_org_id': auth.orgId},
  ) as List;

  // 3. Overdue training count
  final overdueQuery = await supabase
      .from('employee_training_obligations')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('status', 'overdue');
  final overdueCount = (overdueQuery as List).length;

  // 4. Expiring certificates (next 30 days)
  final expiringCerts = await supabase
      .from('certificates')
      .select('id, employee_id, course_id, expiry_date')
      .eq('organization_id', auth.orgId)
      .eq('status', 'active')
      .gte('expiry_date', now.toIso8601String())
      .lte('expiry_date', now.add(const Duration(days: 30)).toIso8601String())
      .order('expiry_date');

  // 5. Pending competency assessments
  final pendingCompetencies = await supabase
      .from('employee_competencies')
      .select('id')
      .eq('organization_id', auth.orgId)
      .eq('status', 'pending_assessment');
  final pendingCompCount = (pendingCompetencies as List).length;

  // 6. Active waivers
  final activeWaivers = await supabase
      .from('training_waivers')
      .select('id, employee_id, waiver_type, expiry_date')
      .eq('organization_id', auth.orgId)
      .eq('status', 'approved')
      .gte('expiry_date', now.toIso8601String())
      .order('expiry_date');

  // 7. Document readings pending
  final pendingReadings = await supabase
      .from('document_readings')
      .select('id')
      .eq('organization_id', auth.orgId)
      .inFilter('status', ['ASSIGNED', 'IN_PROGRESS']);
  final pendingReadCount = (pendingReadings as List).length;

  // 8. Induction completeness
  final inductionStats = await supabase.rpc(
    'get_induction_completion_stats',
    params: {'p_org_id': auth.orgId},
  ) as Map<String, dynamic>?;

  // 9. Recent deviations affecting training
  final recentDeviations = await supabase
      .from('deviations')
      .select('id, deviation_number, title, status, created_at')
      .eq('organization_id', auth.orgId)
      .eq('deviation_type', 'training_deviation')
      .order('created_at', ascending: false)
      .limit(10);

  // 10. Audit trail integrity (recent)
  final auditIntegrity = await supabase.rpc(
    'check_audit_trail_integrity',
    params: {
      'p_org_id': auth.orgId,
      'p_days_back': 30,
    },
  ) as Map<String, dynamic>?;

  return ApiResponse.ok({
    'generated_at': now.toIso8601String(),
    'organization_id': auth.orgId,
    'summary': {
      'compliance_rate': complianceStats.isNotEmpty
          ? complianceStats.first['compliance_rate']
          : 100.0,
      'overdue_count': overdueCount,
      'expiring_certificates_30_days': (expiringCerts as List).length,
      'pending_competency_assessments': pendingCompCount,
      'active_waivers': (activeWaivers as List).length,
      'pending_document_readings': pendingReadCount,
    },
    'training_matrix_compliance': matrixCompliance,
    'expiring_certificates': expiringCerts,
    'active_waivers': activeWaivers,
    'induction_stats': inductionStats,
    'recent_training_deviations': recentDeviations,
    'audit_integrity': auditIntegrity,
  }).toResponse();
}

/// GET /v1/certify/inspection/employee-dossier/:id
///
/// Returns complete training dossier for an employee.
/// Everything an inspector needs to verify employee qualification.
Future<Response> inspectionEmployeeDossierHandler(Request req) async {
  final employeeId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (employeeId == null || employeeId.isEmpty) {
    throw ValidationException({'id': 'Employee ID is required'});
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  // Employee details
  final employee = await supabase
      .from('employees')
      .select('''
        id, employee_id, first_name, last_name, email, 
        department_id, role_id, job_title, hire_date, status,
        departments(id, name, code),
        roles(id, name, role_code)
      ''')
      .eq('id', employeeId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  // Training records
  final trainingRecords = await supabase
      .from('training_records')
      .select('''
        id, training_type, training_source, training_date, completion_date,
        duration_hours, assessment_score, assessment_passed, overall_status,
        courses(id, name, course_code),
        gtp_masters(id, name, gtp_code)
      ''')
      .eq('employee_id', employeeId)
      .order('training_date', ascending: false);

  // Certificates
  final certificates = await supabase
      .from('certificates')
      .select('''
        id, certificate_number, issue_date, expiry_date, status,
        courses(id, name, course_code)
      ''')
      .eq('employee_id', employeeId)
      .order('issue_date', ascending: false);

  // Active obligations
  final obligations = await supabase
      .from('employee_training_obligations')
      .select('''
        id, obligation_type, status, due_date, completed_at,
        courses(id, name, course_code)
      ''')
      .eq('employee_id', employeeId)
      .order('due_date', ascending: false);

  // Competencies
  final competencies = await supabase
      .from('employee_competencies')
      .select('''
        id, competency_level, status, assessed_at,
        competency_definitions(id, name, code)
      ''')
      .eq('employee_id', employeeId);

  // Document readings
  final documentReadings = await supabase
      .from('document_readings')
      .select('''
        id, status, completed_at,
        documents(id, title, doc_number)
      ''')
      .eq('employee_id', employeeId)
      .order('completed_at', ascending: false);

  // Induction status
  final induction = await supabase
      .from('employee_inductions')
      .select('''
        id, status, started_at, completed_at,
        induction_programs(id, name)
      ''')
      .eq('employee_id', employeeId)
      .order('started_at', ascending: false)
      .limit(1)
      .maybeSingle();

  // Waivers
  final waivers = await supabase
      .from('training_waivers')
      .select('''
        id, waiver_type, reason, status, approved_at, expiry_date
      ''')
      .eq('employee_id', employeeId)
      .order('approved_at', ascending: false);

  // Calculate summary stats
  final completedTrainings = (trainingRecords as List)
      .where((r) => r['overall_status'] == 'completed')
      .length;
  final activeCerts = (certificates as List)
      .where((c) => c['status'] == 'active')
      .length;
  final overdueObligations = (obligations as List)
      .where((o) => o['status'] == 'overdue')
      .length;

  return ApiResponse.ok({
    'employee': employee,
    'summary': {
      'total_trainings': (trainingRecords as List).length,
      'completed_trainings': completedTrainings,
      'active_certificates': activeCerts,
      'active_obligations': (obligations as List).length,
      'overdue_obligations': overdueObligations,
      'competencies_assessed': (competencies as List).length,
    },
    'training_records': trainingRecords,
    'certificates': certificates,
    'obligations': obligations,
    'competencies': competencies,
    'document_readings': documentReadings,
    'induction': induction,
    'waivers': waivers,
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  }).toResponse();
}

/// GET /v1/certify/inspection/audit-export
///
/// Exports audit trail for inspection purposes.
/// Supports filtering and date ranges.
Future<Response> inspectionAuditExportHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final params = req.url.queryParameters;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewAudit,
    jwtPermissions: auth.permissions,
  );

  final fromDate = params['from_date'];
  final toDate = params['to_date'];
  final entityType = params['entity_type'];
  final employeeId = params['employee_id'];
  final limit = int.tryParse(params['limit'] ?? '1000') ?? 1000;

  var query = supabase
      .from('audit_trails')
      .select('''
        id, entity_type, entity_id, action, old_values, new_values,
        performed_at, ip_address, user_agent, session_id,
        performer:employees!performed_by(id, first_name, last_name, employee_id)
      ''')
      .eq('organization_id', auth.orgId);

  if (fromDate != null) {
    query = query.gte('performed_at', fromDate);
  }
  if (toDate != null) {
    query = query.lte('performed_at', toDate);
  }
  if (entityType != null) {
    query = query.eq('entity_type', entityType);
  }
  if (employeeId != null) {
    query = query.eq('performed_by', employeeId);
  }

  final trails = await query
      .order('performed_at', ascending: false)
      .limit(limit);

  // Log this export for compliance
  await supabase.from('audit_trails').insert({
    'organization_id': auth.orgId,
    'entity_type': 'audit_export',
    'entity_id': auth.orgId,
    'action': 'export',
    'performed_by': auth.employeeId,
    'performed_at': DateTime.now().toUtc().toIso8601String(),
    'new_values': {
      'from_date': fromDate,
      'to_date': toDate,
      'entity_type': entityType,
      'record_count': (trails as List).length,
    },
  });

  return ApiResponse.ok({
    'audit_trails': trails,
    'filters': {
      'from_date': fromDate,
      'to_date': toDate,
      'entity_type': entityType,
      'employee_id': employeeId,
    },
    'record_count': (trails as List).length,
    'exported_at': DateTime.now().toUtc().toIso8601String(),
    'exported_by': auth.employeeId,
  }).toResponse();
}

/// GET /v1/certify/inspection/gaps
///
/// Returns all training gaps across the organization.
/// Critical for inspection preparation.
Future<Response> inspectionGapsHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final params = req.url.queryParameters;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  final departmentId = params['department_id'];
  final roleId = params['role_id'];
  final includeWaived = params['include_waived'] == 'true';

  // Get all gaps using RPC
  final gaps = await supabase.rpc(
    'get_organization_training_gaps',
    params: {
      'p_org_id': auth.orgId,
      if (departmentId != null) 'p_department_id': departmentId,
      if (roleId != null) 'p_role_id': roleId,
      'p_include_waived': includeWaived,
    },
  ) as List;

  // Group by department
  final byDepartment = <String, List<dynamic>>{};
  for (final gap in gaps) {
    final deptName = gap['department_name'] as String? ?? 'Unassigned';
    byDepartment.putIfAbsent(deptName, () => []);
    byDepartment[deptName]!.add(gap);
  }

  // Group by course
  final byCourse = <String, List<dynamic>>{};
  for (final gap in gaps) {
    final courseName = gap['course_name'] as String? ?? 'Unknown';
    byCourse.putIfAbsent(courseName, () => []);
    byCourse[courseName]!.add(gap);
  }

  return ApiResponse.ok({
    'total_gaps': gaps.length,
    'gaps': gaps,
    'by_department': byDepartment.map((k, v) => MapEntry(k, {
      'count': v.length,
      'gaps': v,
    })),
    'by_course': byCourse.map((k, v) => MapEntry(k, {
      'count': v.length,
      'employees': v.map((g) => g['employee_name']).toList(),
    })),
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  }).toResponse();
}
