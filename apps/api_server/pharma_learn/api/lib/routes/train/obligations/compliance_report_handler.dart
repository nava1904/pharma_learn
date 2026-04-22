import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/compliance-report
///
/// Returns compliance report for department/plant view.
/// URS Alfa §4.3.3: Compliance dashboard by department
///
/// Query params:
/// - `department_id`: Filter by department UUID
/// - `plant_id`: Filter by plant/location UUID
/// - `status`: Filter by status (compliant, non_compliant, overdue, pending)
/// - `course_id`: Filter by specific course
/// - `as_of_date`: Compliance status as of this date (ISO8601, defaults to now)
/// - `include_details`: Include individual employee records (default false)
/// - `page`: Page number (default 1)
/// - `per_page`: Results per page (default 50, max 200)
Future<Response> complianceReportHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  final departmentId = req.url.queryParameters['department_id'];
  final plantId = req.url.queryParameters['plant_id'];
  final status = req.url.queryParameters['status'];
  final courseId = req.url.queryParameters['course_id'];
  final asOfDate = req.url.queryParameters['as_of_date'] ?? 
      DateTime.now().toUtc().toIso8601String().split('T')[0];
  final includeDetails = req.url.queryParameters['include_details'] == 'true';
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  var perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '50') ?? 50;
  if (perPage > 200) perPage = 200;

  // Build base query for obligations
  var query = supabase
      .from('employee_training_obligations')
      .select('''
        id,
        status,
        due_date,
        completed_at,
        employee_id,
        course_id,
        employees!inner (
          id,
          employee_number,
          first_name,
          last_name,
          department_id,
          plant_id,
          departments ( id, name ),
          plants ( id, name )
        ),
        courses!inner (
          id,
          name,
          course_code,
          course_type
        )
      ''')
      .eq('organization_id', auth.orgId);

  // Apply filters
  if (departmentId != null) {
    query = query.eq('employees.department_id', departmentId);
  }
  if (plantId != null) {
    query = query.eq('employees.plant_id', plantId);
  }
  if (courseId != null) {
    query = query.eq('course_id', courseId);
  }

  final obligations = await query;

  // Calculate compliance status for each obligation as of the given date
  final asOfDateTime = DateTime.parse(asOfDate);
  
  final complianceRecords = <Map<String, dynamic>>[];
  
  for (final ob in obligations) {
    final dueDate = ob['due_date'] != null 
        ? DateTime.parse(ob['due_date'] as String) 
        : null;
    final completedAt = ob['completed_at'] != null 
        ? DateTime.parse(ob['completed_at'] as String) 
        : null;
    final obStatus = ob['status'] as String?;

    // Determine compliance status
    String complianceStatus;
    if (obStatus == 'completed' && completedAt != null) {
      // Completed - check if it was completed on time
      if (dueDate != null && completedAt.isAfter(dueDate)) {
        complianceStatus = 'completed_late';
      } else {
        complianceStatus = 'compliant';
      }
    } else if (dueDate != null && dueDate.isBefore(asOfDateTime)) {
      complianceStatus = 'overdue';
    } else if (obStatus == 'waived') {
      complianceStatus = 'waived';
    } else {
      complianceStatus = 'pending';
    }

    // Apply status filter
    if (status != null) {
      if (status == 'compliant' && complianceStatus != 'compliant') {
        continue;
      }
      if (status == 'non_compliant' && 
          complianceStatus != 'overdue' && 
          complianceStatus != 'completed_late') {
        continue;
      }
      if (status == 'overdue' && complianceStatus != 'overdue') {
        continue;
      }
      if (status == 'pending' && complianceStatus != 'pending') {
        continue;
      }
    }

    complianceRecords.add({
      ...ob,
      'compliance_status': complianceStatus,
    });
  }

  // Aggregate by department
  final departmentStats = <String, Map<String, dynamic>>{};
  
  for (final record in complianceRecords) {
    final employee = record['employees'] as Map<String, dynamic>?;
    if (employee == null) continue;
    
    final dept = employee['departments'] as Map<String, dynamic>?;
    final deptId = dept?['id'] as String? ?? 'unknown';
    final deptName = dept?['name'] as String? ?? 'Unknown';

    departmentStats.putIfAbsent(deptId, () => {
      'department_id': deptId,
      'department_name': deptName,
      'total': 0,
      'compliant': 0,
      'overdue': 0,
      'pending': 0,
      'waived': 0,
      'completed_late': 0,
    });

    final stats = departmentStats[deptId]!;
    stats['total'] = (stats['total'] as int) + 1;
    
    final compStatus = record['compliance_status'] as String;
    stats[compStatus] = (stats[compStatus] as int? ?? 0) + 1;
  }

  // Calculate compliance rate for each department
  for (final stats in departmentStats.values) {
    final total = stats['total'] as int;
    final compliant = stats['compliant'] as int;
    final waived = stats['waived'] as int;
    
    // Compliance rate = (compliant + waived) / total
    if (total > 0) {
      stats['compliance_rate'] = ((compliant + waived) / total * 100).toStringAsFixed(1);
    } else {
      stats['compliance_rate'] = '100.0';
    }
  }

  // Overall summary
  final totalObligations = complianceRecords.length;
  final totalCompliant = complianceRecords
      .where((r) => r['compliance_status'] == 'compliant')
      .length;
  final totalOverdue = complianceRecords
      .where((r) => r['compliance_status'] == 'overdue')
      .length;
  final totalPending = complianceRecords
      .where((r) => r['compliance_status'] == 'pending')
      .length;
  final totalWaived = complianceRecords
      .where((r) => r['compliance_status'] == 'waived')
      .length;

  final overallComplianceRate = totalObligations > 0
      ? ((totalCompliant + totalWaived) / totalObligations * 100).toStringAsFixed(1)
      : '100.0';

  // Prepare response
  final response = <String, dynamic>{
    'as_of_date': asOfDate,
    'summary': {
      'total_obligations': totalObligations,
      'compliant': totalCompliant,
      'overdue': totalOverdue,
      'pending': totalPending,
      'waived': totalWaived,
      'compliance_rate': overallComplianceRate,
    },
    'departments': departmentStats.values.toList()
      ..sort((a, b) => (a['department_name'] as String)
          .compareTo(b['department_name'] as String)),
  };

  // Include details if requested
  if (includeDetails) {
    // Paginate the detailed records
    final offset = (page - 1) * perPage;
    final paginatedRecords = complianceRecords.skip(offset).take(perPage).toList();

    response['details'] = paginatedRecords.map((r) {
      final employee = r['employees'] as Map<String, dynamic>?;
      final course = r['courses'] as Map<String, dynamic>?;
      return {
        'obligation_id': r['id'],
        'employee': {
          'id': employee?['id'],
          'employee_number': employee?['employee_number'],
          'name': '${employee?['first_name']} ${employee?['last_name']}',
        },
        'course': {
          'id': course?['id'],
          'name': course?['name'],
          'code': course?['course_code'],
        },
        'due_date': r['due_date'],
        'completed_at': r['completed_at'],
        'status': r['status'],
        'compliance_status': r['compliance_status'],
      };
    }).toList();

    response['pagination'] = {
      'page': page,
      'per_page': perPage,
      'total': complianceRecords.length,
      'total_pages': (complianceRecords.length / perPage).ceil(),
    };
  }

  return ApiResponse.ok(response).toResponse();
}
