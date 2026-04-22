import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/me/dashboard
///
/// Returns the current employee's training dashboard with:
/// - Employee info
/// - Training obligations (assigned courses + status)
/// - Upcoming sessions
/// - Recent certificates
/// - Compliance percentage
/// - Pending approvals count
///
/// Response:
/// ```json
/// {
///   "data": {
///     "employee": {...},
///     "my_obligations": [...],
///     "upcoming_sessions": [...],
///     "certificates": [...],
///     "compliance_percent": 85.5,
///     "pending_approvals": 3
///   }
/// }
/// ```
Future<Response> meDashboardHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final employeeId = auth.employeeId;

  // 1. Load employee basic info
  final employee = await supabase
      .from('employees')
      .select('''
        id, employee_id, first_name, last_name, email, designation,
        induction_completed, compliance_percent,
        departments(name),
        plants(name, code)
      ''')
      .eq('id', employeeId)
      .single();

  // 2. Load training obligations (courses assigned to this employee)
  final obligations = await supabase
      .from('employee_training_obligations')
      .select('''
        id, status, due_date, assigned_at, completed_at,
        courses!inner(id, name, course_code, duration_hours),
        training_records(id, status, completion_date)
      ''')
      .eq('employee_id', employeeId)
      .order('due_date', ascending: true)
      .limit(20);

  // 3. Load upcoming sessions (next 7 days)
  final now = DateTime.now().toUtc();
  final weekFromNow = now.add(const Duration(days: 7));

  final upcomingSessions = await supabase
      .from('training_sessions')
      .select('''
        id, session_code, session_date, start_time, end_time, status,
        training_schedules!inner(
          name,
          schedule_employees!inner(employee_id)
        ),
        courses!inner(name, course_code),
        training_venues(name)
      ''')
      .gte('session_date', now.toIso8601String().substring(0, 10))
      .lte('session_date', weekFromNow.toIso8601String().substring(0, 10))
      .eq('training_schedules.schedule_employees.employee_id', employeeId)
      .order('session_date', ascending: true)
      .order('start_time', ascending: true)
      .limit(10);

  // 4. Load recent certificates (last 5)
  final certificates = await supabase
      .from('certificates')
      .select('''
        id, certificate_number, issued_at, valid_until, status,
        courses!inner(name, course_code)
      ''')
      .eq('employee_id', employeeId)
      .eq('status', 'active')
      .order('issued_at', ascending: false)
      .limit(5);

  // 5. Count pending approvals (if user has approval permission)
  int pendingApprovalsCount = 0;
  if (auth.permissions.any((p) =>
      p == Permissions.manageApprovals || p == Permissions.viewApprovals)) {
    try {
      final pendingApprovals = await supabase.rpc(
        'get_pending_approvals_for_user',
        params: {'p_user_id': employeeId},
      );
      pendingApprovalsCount = (pendingApprovals as List?)?.length ?? 0;
    } catch (_) {
      // RPC may not exist or user may not have access
    }
  }

  // 6. Calculate compliance stats
  final compliancePercent =
      (employee['compliance_percent'] as num?)?.toDouble() ?? 0.0;

  final obligationsWithStatus = obligations.map((o) {
    final status = o['status'] as String?;
    return {
      'id': o['id'],
      'course': o['courses'],
      'status': status,
      'due_date': o['due_date'],
      'is_overdue':
          status != 'completed' && _isOverdue(o['due_date'] as String?),
    };
  }).toList();

  return ApiResponse.ok({
    'employee': {
      'id': employee['id'],
      'employee_id': employee['employee_id'],
      'full_name':
          '${employee['first_name']} ${employee['last_name']}',
      'email': employee['email'],
      'designation': employee['designation'],
      'department': employee['departments']?['name'],
      'plant': employee['plants']?['name'],
      'induction_completed': employee['induction_completed'] ?? false,
    },
    'my_obligations': obligationsWithStatus,
    'upcoming_sessions': upcomingSessions,
    'certificates': certificates,
    'compliance_percent': compliancePercent,
    'pending_approvals': pendingApprovalsCount,
    'summary': {
      'total_obligations': obligations.length,
      'completed':
          obligations.where((o) => o['status'] == 'completed').length,
      'overdue': obligationsWithStatus.where((o) => o['is_overdue'] == true).length,
      'upcoming_sessions_count': upcomingSessions.length,
      'active_certificates': certificates.length,
    },
  }).toResponse();
}

bool _isOverdue(String? dueDateStr) {
  if (dueDateStr == null) return false;
  try {
    final dueDate = DateTime.parse(dueDateStr);
    return DateTime.now().toUtc().isAfter(dueDate);
  } catch (_) {
    return false;
  }
}
