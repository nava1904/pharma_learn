import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/access/employees/:id/pending-tasks
///
/// Lists all pending/open tasks for an employee.
Future<Response> employeePendingTasksListHandler(Request req) async {
  final employeeId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to view employee tasks');
  }

  if (employeeId == null || employeeId.isEmpty) {
    throw ValidationException({'id': 'Employee ID is required'});
  }

  // Verify employee exists
  final employee = await supabase
      .from('employees')
      .select('id, first_name, last_name, organization_id')
      .eq('id', employeeId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  // Collect all pending tasks
  final tasks = <Map<String, dynamic>>[];

  // 1. Pending assessments
  final assessments = await supabase
      .from('assessment_attempts')
      .select('''
        id, status, started_at, time_limit_minutes,
        question_paper:question_papers(id, title)
      ''')
      .eq('employee_id', employeeId)
      .eq('status', 'in_progress');

  for (final a in assessments as List) {
    tasks.add({
      'type': 'assessment',
      'id': a['id'],
      'title': a['question_paper']?['title'] ?? 'Assessment',
      'status': a['status'],
      'started_at': a['started_at'],
    });
  }

  // 2. Pending training enrollments
  final enrollments = await supabase
      .from('schedule_enrollments')
      .select('''
        id, status, enrolled_at,
        schedule:training_schedules(id, title, start_date)
      ''')
      .eq('employee_id', employeeId)
      .inFilter('status', ['enrolled', 'in_progress']);

  for (final e in enrollments as List) {
    tasks.add({
      'type': 'training',
      'id': e['id'],
      'title': e['schedule']?['title'] ?? 'Training',
      'status': e['status'],
      'started_at': e['enrolled_at'],
    });
  }

  // 3. Pending curriculums
  final curricula = await supabase
      .from('employee_curricula')
      .select('''
        id, status, assigned_at,
        curriculum:curricula(id, title)
      ''')
      .eq('employee_id', employeeId)
      .inFilter('status', ['assigned', 'in_progress']);

  for (final c in curricula as List) {
    tasks.add({
      'type': 'curriculum',
      'id': c['id'],
      'title': c['curriculum']?['title'] ?? 'Curriculum',
      'status': c['status'],
      'started_at': c['assigned_at'],
    });
  }

  // 4. Active inductions
  final inductions = await supabase
      .from('employee_induction')
      .select('id, status, created_at')
      .eq('employee_id', employeeId)
      .inFilter('status', ['pending', 'in_progress']);

  for (final i in inductions as List) {
    tasks.add({
      'type': 'induction',
      'id': i['id'],
      'title': 'Induction Program',
      'status': i['status'],
      'started_at': i['created_at'],
    });
  }

  // 5. Pending OJT assignments
  final ojt = await supabase
      .from('ojt_assignments')
      .select('''
        id, status, assigned_at,
        ojt:ojt_templates(id, title)
      ''')
      .eq('employee_id', employeeId)
      .inFilter('status', ['assigned', 'in_progress']);

  for (final o in ojt as List) {
    tasks.add({
      'type': 'ojt',
      'id': o['id'],
      'title': o['ojt']?['title'] ?? 'OJT Assignment',
      'status': o['status'],
      'started_at': o['assigned_at'],
    });
  }

  // 6. Learning progress
  final learning = await supabase
      .from('learning_progress')
      .select('''
        id, status, started_at,
        course:courses(id, title)
      ''')
      .eq('employee_id', employeeId)
      .eq('status', 'in_progress');

  for (final l in learning as List) {
    tasks.add({
      'type': 'learning',
      'id': l['id'],
      'title': l['course']?['title'] ?? 'Learning Course',
      'status': l['status'],
      'started_at': l['started_at'],
    });
  }

  return ApiResponse.ok({
    'employee': {
      'id': employee['id'],
      'name': '${employee['first_name']} ${employee['last_name']}',
    },
    'total_pending_tasks': tasks.length,
    'tasks': tasks,
  }).toResponse();
}

/// POST /v1/access/employees/:id/pending-tasks/terminate
///
/// Admin terminates all open obligations for an employee (deactivation/transfer).
/// Body: { reason, esig: { reauth_session_id, meaning } }
Future<Response> employeeTaskTerminateHandler(Request req) async {
  final employeeId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Verify admin permission
  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to terminate employee tasks');
  }

  if (employeeId == null || employeeId.isEmpty) {
    throw ValidationException({'id': 'Employee ID is required'});
  }

  final reason = requireString(body, 'reason');

  // Validate e-signature
  final esig = body['esig'] as Map<String, dynamic>?;
  if (esig == null) {
    throw ValidationException({'esig': 'E-signature is required for task termination'});
  }

  // Verify employee exists
  final employee = await supabase
      .from('employees')
      .select('id, first_name, last_name, organization_id')
      .eq('id', employeeId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  if (employee['organization_id'] != auth.orgId) {
    throw PermissionDeniedException('Employee not in your organization');
  }

  // Create e-signature
  final esigService = EsigService(supabase);
  final esigId = await esigService.createEsignature(
    employeeId: auth.employeeId,
    meaning: esig['meaning'] as String? ?? 'TERMINATE_EMPLOYEE_TASKS',
    entityType: 'employee_task_termination',
    entityId: employeeId,
    reauthSessionId: esig['reauth_session_id'] as String,
  );

  final terminationTime = DateTime.now().toUtc();
  final results = <String, int>{};

  // 1. Terminate open training obligations
  final obligationsResult = await supabase
      .from('employee_training_obligations')
      .update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_by': auth.employeeId,
        'cancelled_at': terminationTime.toIso8601String(),
      })
      .eq('employee_id', employeeId)
      .inFilter('status', ['assigned', 'pending', 'in_progress', 'overdue'])
      .select();
  results['training_obligations'] = (obligationsResult as List).length;

  // 2. Terminate open assessment attempts
  final assessmentsResult = await supabase
      .from('assessment_attempts')
      .update({
        'status': 'terminated',
        'termination_reason': reason,
        'terminated_by': auth.employeeId,
        'terminated_at': terminationTime.toIso8601String(),
      })
      .eq('employee_id', employeeId)
      .inFilter('status', ['started', 'in_progress'])
      .select();
  results['assessment_attempts'] = (assessmentsResult as List).length;

  // 3. Withdraw pending approval requests
  final approvalsResult = await supabase
      .from('approval_steps')
      .update({
        'status': 'withdrawn',
        'withdrawal_reason': reason,
        'withdrawn_by': auth.employeeId,
        'withdrawn_at': terminationTime.toIso8601String(),
      })
      .eq('requested_by', employeeId)
      .eq('status', 'pending')
      .select();
  results['pending_approvals'] = (approvalsResult as List).length;

  // 4. Cancel active inductions
  final inductionsResult = await supabase
      .from('employee_induction')
      .update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_by': auth.employeeId,
        'cancelled_at': terminationTime.toIso8601String(),
      })
      .eq('employee_id', employeeId)
      .inFilter('status', ['pending', 'in_progress'])
      .select();
  results['inductions'] = (inductionsResult as List).length;

  // 5. Cancel pending OJT assignments
  final ojtResult = await supabase
      .from('ojt_assignments')
      .update({
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_by': auth.employeeId,
        'cancelled_at': terminationTime.toIso8601String(),
      })
      .eq('employee_id', employeeId)
      .inFilter('status', ['assigned', 'in_progress'])
      .select();
  results['ojt_assignments'] = (ojtResult as List).length;

  // 6. Cancel learning progress
  final learningResult = await supabase
      .from('learning_progress')
      .update({
        'status': 'terminated',
        'termination_reason': reason,
        'terminated_at': terminationTime.toIso8601String(),
      })
      .eq('employee_id', employeeId)
      .eq('status', 'in_progress')
      .select();
  results['learning_progress'] = (learningResult as List).length;

  // Log comprehensive audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee_task_termination',
    'entity_id': employeeId,
    'action': 'bulk_terminate',
    'actor_id': auth.employeeId,
    'organization_id': auth.orgId,
    'changes': {
      'reason': reason,
      'results': results,
      'esignature_id': esigId,
    },
    'created_at': terminationTime.toIso8601String(),
  });

  await OutboxService(supabase).publish(
    aggregateType: 'employee',
    aggregateId: employeeId,
    eventType: 'employee.tasks_terminated',
    payload: {
      'terminated_by': auth.employeeId,
      'reason': reason,
      'results': results,
    },
  );

  final totalTerminated = results.values.reduce((a, b) => a + b);

  return ApiResponse.ok({
    'message': 'Employee tasks terminated successfully',
    'employee_id': employeeId,
    'total_terminated': totalTerminated,
    'details': results,
    'esignature_id': esigId,
  }).toResponse();
}
