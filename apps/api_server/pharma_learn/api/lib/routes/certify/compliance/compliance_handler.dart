import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/certify/compliance/dashboard
///
/// Returns compliance dashboard metrics for the organization.
/// Uses the SQL functions created in G5 migration.
Future<Response> complianceDashboardHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final departmentId = req.url.queryParameters['department_id'];

  // Verify user has permission to view compliance
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  // Get org-wide or department-specific compliance
  final compliance = await supabase.rpc(
    'calculate_org_compliance',
    params: {
      'p_org_id': auth.orgId,
      if (departmentId != null) 'p_department_id': departmentId,
    },
  ) as List;

  if (compliance.isEmpty) {
    return ApiResponse.ok({
      'total_employees': 0,
      'total_obligations': 0,
      'completed': 0,
      'overdue': 0,
      'pending': 0,
      'waived': 0,
      'compliance_rate': 100.0,
    }).toResponse();
  }

  final stats = compliance.first as Map<String, dynamic>;

  // Get course breakdown
  final courseBreakdown = await supabase.rpc(
    'get_course_compliance_breakdown',
    params: {'p_org_id': auth.orgId},
  ) as List;

  // Get at-risk employees
  final atRiskEmployees = await supabase.rpc(
    'get_at_risk_employees',
    params: {
      'p_org_id': auth.orgId,
      'p_due_within_days': 7,
    },
  ) as List;

  return ApiResponse.ok({
    'summary': stats,
    'course_breakdown': courseBreakdown.take(10).toList(),
    'at_risk_employees': atRiskEmployees.take(20).toList(),
    'generated_at': DateTime.now().toUtc().toIso8601String(),
  }).toResponse();
}

/// GET /v1/certify/compliance/employees/:id
///
/// Returns detailed compliance information for a specific employee.
Future<Response> complianceEmployeeHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify user has permission to view compliance
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  // Verify employee belongs to same org
  final employee = await supabase
      .from('employees')
      .select('id, first_name, last_name, employee_number, department_id')
      .eq('id', employeeId)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  // Get employee compliance rate
  final compliance = await supabase.rpc(
    'calculate_employee_compliance',
    params: {'p_employee_id': employeeId},
  ) as List;

  final stats = compliance.isNotEmpty
      ? compliance.first as Map<String, dynamic>
      : {
          'total_obligations': 0,
          'completed': 0,
          'overdue': 0,
          'pending': 0,
          'waived': 0,
          'compliance_rate': 100.0,
        };

  // Get detailed obligations
  final obligations = await supabase
      .from('employee_assignments')
      .select('''
        id, status, due_date, completed_at,
        training_assignments!inner(
          name,
          courses!inner(id, title, course_code)
        )
      ''')
      .eq('employee_id', employeeId)
      .order('due_date', ascending: true);

  // Categorize obligations
  final now = DateTime.now();
  final overdue = <Map<String, dynamic>>[];
  final dueSoon = <Map<String, dynamic>>[];
  final onTrack = <Map<String, dynamic>>[];
  final completed = <Map<String, dynamic>>[];

  for (final o in obligations) {
    final status = o['status'] as String;
    if (status == 'completed' || status == 'waived') {
      completed.add(o);
      continue;
    }

    final dueDate = DateTime.tryParse(o['due_date'] ?? '');
    if (dueDate == null) {
      onTrack.add(o);
    } else if (dueDate.isBefore(now)) {
      overdue.add(o);
    } else if (dueDate.isBefore(now.add(const Duration(days: 7)))) {
      dueSoon.add(o);
    } else {
      onTrack.add(o);
    }
  }

  return ApiResponse.ok({
    'employee': employee,
    'compliance': stats,
    'obligations': {
      'overdue': overdue,
      'due_soon': dueSoon,
      'on_track': onTrack,
      'completed': completed.take(10).toList(),
    },
  }).toResponse();
}

/// GET /v1/certify/compliance/reports/summary
///
/// Returns a compliance summary report for export.
Future<Response> complianceSummaryReportHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final departmentId = req.url.queryParameters['department_id'];
  // format parameter reserved for future CSV/PDF export support
  // final format = req.url.queryParameters['format'] ?? 'json';

  // Verify user has permission to view compliance
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  // Get all employees with their compliance rates
  final employees = await supabase
      .from('employees')
      .select('id, first_name, last_name, employee_number')
      .eq('org_id', auth.orgId)
      .eq('status', 'active')
      .match(departmentId != null ? {'department_id': departmentId} : {});

  final results = <Map<String, dynamic>>[];
  for (final emp in employees) {
    final compliance = await supabase.rpc(
      'calculate_employee_compliance',
      params: {'p_employee_id': emp['id']},
    ) as List;

    if (compliance.isNotEmpty) {
      results.add({
        'employee_number': emp['employee_number'],
        'name': '${emp['first_name']} ${emp['last_name']}',
        ...compliance.first as Map<String, dynamic>,
      });
    }
  }

  // Sort by compliance rate (worst first)
  results.sort((a, b) => 
      (a['compliance_rate'] as num).compareTo(b['compliance_rate'] as num));

  return ApiResponse.ok({
    'report_type': 'compliance_summary',
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
    'department_id': departmentId,
    'total_employees': results.length,
    'employees': results,
  }).toResponse();
}

/// GET /v1/certify/compliance/my
///
/// Returns the current employee's own compliance status.
Future<Response> complianceMyHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Get employee compliance rate
  final compliance = await supabase.rpc(
    'calculate_employee_compliance',
    params: {'p_employee_id': auth.employeeId},
  ) as List;

  final stats = compliance.isNotEmpty
      ? compliance.first as Map<String, dynamic>
      : {
          'total_obligations': 0,
          'completed': 0,
          'overdue': 0,
          'pending': 0,
          'waived': 0,
          'compliance_rate': 100.0,
        };

  // Get upcoming deadlines
  final upcomingDeadlines = await supabase
      .from('employee_assignments')
      .select('''
        id, due_date, status,
        training_assignments!inner(
          name,
          courses!inner(title, course_code)
        )
      ''')
      .eq('employee_id', auth.employeeId)
      .neq('status', 'completed')
      .neq('status', 'waived')
      .gte('due_date', DateTime.now().toIso8601String())
      .order('due_date', ascending: true)
      .limit(5);

  return ApiResponse.ok({
    'compliance': stats,
    'upcoming_deadlines': upcomingDeadlines,
  }).toResponse();
}
