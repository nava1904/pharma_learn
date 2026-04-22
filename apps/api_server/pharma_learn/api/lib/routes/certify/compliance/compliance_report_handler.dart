import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/certify/compliance/reports/run
///
/// Runs a compliance report and stores it for later download.
/// Body: {
///   report_type: 'summary' | 'detailed' | 'overdue' | 'trend',
///   filters: {
///     department_ids?: string[],
///     course_ids?: string[],
///     from_date?: date,
///     to_date?: date,
///     status?: string[]
///   },
///   format: 'json' | 'csv' | 'pdf'
/// }
Future<Response> complianceReportRunHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.exportReports)) {
    throw PermissionDeniedException('You do not have permission to run compliance reports');
  }

  final reportType = requireString(body, 'report_type');
  final format = body['format'] as String? ?? 'json';
  final filters = body['filters'] as Map<String, dynamic>? ?? {};

  // Validate report type
  final validTypes = ['summary', 'detailed', 'overdue', 'trend'];
  if (!validTypes.contains(reportType)) {
    throw ValidationException({
      'report_type': 'Invalid report type. Must be one of: ${validTypes.join(', ')}'
    });
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Create report record
  final report = await supabase
      .from('compliance_reports')
      .insert({
        'org_id': auth.orgId,
        'report_type': reportType,
        'format': format,
        'filters': filters,
        'status': 'pending',
        'requested_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  // For simple reports, generate immediately
  if (reportType == 'summary' || reportType == 'overdue') {
    try {
      final data = await _generateReport(supabase, auth.orgId, reportType, filters);
      
      await supabase
          .from('compliance_reports')
          .update({
            'status': 'completed',
            'data': data,
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', report['id']);

      return ApiResponse.ok({
        'report_id': report['id'],
        'status': 'completed',
        'message': 'Report generated successfully',
      }).toResponse();
    } catch (e) {
      await supabase
          .from('compliance_reports')
          .update({
            'status': 'failed',
            'error_message': e.toString(),
          })
          .eq('id', report['id']);

      return ApiResponse.ok({
        'report_id': report['id'],
        'status': 'failed',
        'error': e.toString(),
      }).toResponse();
    }
  }

  // For complex reports, queue for background processing
  await supabase.from('report_jobs').insert({
    'report_id': report['id'],
    'status': 'queued',
    'created_at': now,
  });

  return ApiResponse.ok({
    'report_id': report['id'],
    'status': 'pending',
    'message': 'Report queued for processing',
  }).toResponse();
}

/// GET /v1/certify/compliance/reports/:id
///
/// Gets report status or data.
Future<Response> complianceReportGetHandler(Request req) async {
  final reportId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (reportId == null || reportId.isEmpty) {
    throw ValidationException({'id': 'Report ID is required'});
  }

  if (!auth.hasPermission(Permissions.viewReports)) {
    throw PermissionDeniedException('You do not have permission to view reports');
  }

  final report = await supabase
      .from('compliance_reports')
      .select('*')
      .eq('id', reportId)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (report == null) {
    throw NotFoundException('Report not found');
  }

  return ApiResponse.ok(report).toResponse();
}

/// GET /v1/certify/compliance/reports/:id/download
///
/// Downloads report in requested format.
Future<Response> complianceReportDownloadHandler(Request req) async {
  final reportId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (reportId == null || reportId.isEmpty) {
    throw ValidationException({'id': 'Report ID is required'});
  }

  if (!auth.hasPermission(Permissions.exportReports)) {
    throw PermissionDeniedException('You do not have permission to download reports');
  }

  final report = await supabase
      .from('compliance_reports')
      .select('id, report_type, format, data, status')
      .eq('id', reportId)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (report == null) {
    throw NotFoundException('Report not found');
  }

  if (report['status'] != 'completed') {
    throw ConflictException('Report is not ready for download (status: ${report['status']})');
  }

  final data = report['data'];
  final format = report['format'] as String;

  // Log the download
  await supabase.from('audit_trails').insert({
    'entity_type': 'compliance_report',
    'entity_id': reportId,
    'action': 'download',
    'employee_id': auth.employeeId,
    'new_values': {'format': format},
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  switch (format) {
    case 'csv':
      return _formatAsCsv(data, report['report_type'] as String);
    case 'pdf':
      // PDF generation would require additional library
      // For now, return JSON
      return ApiResponse.ok(data).toResponse();
    default:
      return ApiResponse.ok(data).toResponse();
  }
}

/// GET /v1/certify/compliance/reports
///
/// Lists previous compliance reports.
Future<Response> complianceReportsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.viewReports)) {
    throw PermissionDeniedException('You do not have permission to view reports');
  }

  final params = req.url.queryParameters;
  final reportType = params['report_type'];
  final status = params['status'];

  var query = supabase
      .from('compliance_reports')
      .select('''
        id, report_type, format, filters, status, 
        created_at, completed_at, error_message,
        requested_by:employees!requested_by(id, first_name, last_name)
      ''')
      .eq('org_id', auth.orgId);

  if (reportType != null) query = query.eq('report_type', reportType);
  if (status != null) query = query.eq('status', status);

  final reports = await query.order('created_at', ascending: false).limit(50);

  return ApiResponse.ok(reports).toResponse();
}

/// Generates report data based on type and filters.
Future<Map<String, dynamic>> _generateReport(
  dynamic supabase,
  String orgId,
  String reportType,
  Map<String, dynamic> filters,
) async {
  switch (reportType) {
    case 'summary':
      return _generateSummaryReport(supabase, orgId, filters);
    case 'overdue':
      return _generateOverdueReport(supabase, orgId, filters);
    default:
      throw ValidationException({'report_type': 'Unsupported report type: $reportType'});
  }
}

Future<Map<String, dynamic>> _generateSummaryReport(
  dynamic supabase,
  String orgId,
  Map<String, dynamic> filters,
) async {
  final departmentIds = filters['department_ids'] as List<dynamic>?;

  // Get overall stats
  final stats = await supabase.rpc('calculate_org_compliance', params: {
    'p_org_id': orgId,
  }) as List;

  // Get department breakdown
  var deptQuery = supabase
      .from('departments')
      .select('id, name')
      .eq('org_id', orgId);

  if (departmentIds != null && departmentIds.isNotEmpty) {
    deptQuery = deptQuery.inFilter('id', departmentIds.cast<String>());
  }

  final departments = await deptQuery;
  final deptStats = <Map<String, dynamic>>[];

  for (final dept in departments) {
    final deptCompliance = await supabase.rpc('calculate_org_compliance', params: {
      'p_org_id': orgId,
      'p_department_id': dept['id'],
    }) as List;

    if (deptCompliance.isNotEmpty) {
      deptStats.add({
        'department_id': dept['id'],
        'department_name': dept['name'],
        ...deptCompliance.first as Map<String, dynamic>,
      });
    }
  }

  return {
    'report_type': 'summary',
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'overall': stats.isNotEmpty ? stats.first : {},
    'by_department': deptStats,
  };
}

Future<Map<String, dynamic>> _generateOverdueReport(
  dynamic supabase,
  String orgId,
  Map<String, dynamic> filters,
) async {
  final now = DateTime.now().toUtc().toIso8601String();

  var query = supabase
      .from('employee_assignments')
      .select('''
        id, due_date, status,
        employees(id, employee_number, first_name, last_name, email,
          departments(id, name)),
        training_assignments(name,
          courses(id, title, course_code))
      ''')
      .lt('due_date', now)
      .inFilter('status', ['pending', 'in_progress']);

  final overdueAssignments = await query.order('due_date', ascending: true);

  // Group by employee
  final byEmployee = <String, List<Map<String, dynamic>>>{};
  for (final assignment in overdueAssignments) {
    final emp = assignment['employees'] as Map<String, dynamic>?;
    if (emp == null) continue;

    final empId = emp['id'] as String;
    byEmployee[empId] ??= [];
    byEmployee[empId]!.add(assignment);
  }

  final employees = byEmployee.entries.map((e) {
    final first = e.value.first;
    final emp = first['employees'] as Map<String, dynamic>;
    return {
      'employee_id': e.key,
      'employee_number': emp['employee_number'],
      'name': '${emp['first_name']} ${emp['last_name']}',
      'email': emp['email'],
      'department': emp['departments']?['name'],
      'overdue_count': e.value.length,
      'assignments': e.value.map((a) => {
        'id': a['id'],
        'due_date': a['due_date'],
        'course': a['training_assignments']?['courses']?['title'],
      }).toList(),
    };
  }).toList();

  return {
    'report_type': 'overdue',
    'generated_at': DateTime.now().toUtc().toIso8601String(),
    'total_overdue': overdueAssignments.length,
    'employees_affected': employees.length,
    'employees': employees,
  };
}

Response _formatAsCsv(dynamic data, String reportType) {
  final StringBuffer csv = StringBuffer();

  if (reportType == 'overdue' && data is Map<String, dynamic>) {
    // Header
    csv.writeln('Employee Number,Name,Email,Department,Overdue Count,Course,Due Date');
    
    final employees = data['employees'] as List? ?? [];
    for (final emp in employees) {
      final assignments = emp['assignments'] as List? ?? [];
      for (final assignment in assignments) {
        csv.writeln(
          '${emp['employee_number']},${emp['name']},${emp['email']},'
          '${emp['department']},${emp['overdue_count']},'
          '${assignment['course']},${assignment['due_date']}'
        );
      }
    }
  } else if (reportType == 'summary' && data is Map<String, dynamic>) {
    csv.writeln('Department,Total,Completed,Overdue,Pending,Compliance Rate');
    
    final depts = data['by_department'] as List? ?? [];
    for (final dept in depts) {
      csv.writeln(
        '${dept['department_name']},${dept['total_obligations']},'
        '${dept['completed']},${dept['overdue']},${dept['pending']},'
        '${dept['compliance_rate']}'
      );
    }
  }

  // Return CSV response
  return ApiResponse.ok({
    'content': csv.toString(),
    'content_type': 'text/csv',
    'filename': 'compliance_report.csv',
  }).toResponse();
}
