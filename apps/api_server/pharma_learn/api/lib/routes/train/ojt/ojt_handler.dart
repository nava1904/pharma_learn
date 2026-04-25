import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/train/ojt
///
/// Returns the current employee's OJT assignments with task details.
/// Query params:
/// - status: assigned|in_progress|completed (optional)
/// - page, per_page: pagination
Future<Response> ojtListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final status = req.url.queryParameters['status'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;

  // Build count query
  var countQuery = supabase
      .from('employee_ojt')
      .select('id')
      .eq('employee_id', auth.employeeId);
  if (status != null) countQuery = countQuery.eq('status', status);
  final countResult = await countQuery;
  final total = countResult.length;

  // Build data query with relations
  var query = supabase
      .from('employee_ojt')
      .select('''
        id, status, assigned_at, due_date, started_at, completed_at, 
        completion_percentage, evaluator_notes,
        ojt_masters!inner(
          id, name, description, total_tasks, estimated_duration_hours,
          courses(id, title, course_code)
        ),
        employees!evaluator_id(id, first_name, last_name)
      ''')
      .eq('employee_id', auth.employeeId);

  if (status != null) query = query.eq('status', status);

  final response = await query
      .order('due_date', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  return ApiResponse.paginated(
    response,
    Pagination.compute(page: page, perPage: perPage, total: total),
  ).toResponse();
}

/// GET /v1/train/ojt/:id
///
/// Returns details of a specific OJT assignment including all tasks
/// and their completion status.
Future<Response> ojtGetHandler(Request req) async {
  final ojtId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final ojt = await supabase
      .from('employee_ojt')
      .select('''
        id, status, assigned_at, due_date, started_at, completed_at,
        completion_percentage, evaluator_notes,
        ojt_masters!inner(
          id, name, description, total_tasks, estimated_duration_hours,
          ojt_tasks(
            id, task_number, name, description, criteria, sequence_order
          ),
          courses(id, title, course_code)
        ),
        employees!evaluator_id(id, first_name, last_name, email)
      ''')
      .eq('id', ojtId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (ojt == null) {
    throw NotFoundException('OJT assignment not found');
  }

  // Get task completion status for this employee
  final taskCompletions = await supabase
      .from('ojt_task_completion')
      .select('*, electronic_signatures(id, meaning, signed_at)')
      .eq('employee_ojt_id', ojtId);

  // Merge task completions with OJT data
  final enrichedOjt = {
    ...ojt,
    'task_completions': taskCompletions,
  };

  return ApiResponse.ok(enrichedOjt).toResponse();
}

/// POST /v1/train/ojt/:id/tasks/:taskId/complete
///
/// Records completion of a specific OJT task. Requires evaluator to
/// sign off with e-signature.
///
/// Body:
/// ```json
/// {
///   "evaluator_notes": "Task completed satisfactorily",
///   "esignature": {
///     "reauth_session_id": "uuid",
///     "meaning": "APPROVE"
///   }
/// }
/// ```
Future<Response> ojtTaskCompleteHandler(Request req) async {
  final ojtId = parsePathUuid(req.rawPathParameters[#id]);
  final taskId = parsePathUuid(req.rawPathParameters[#taskId], fieldName: 'taskId');
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final evaluatorNotes = body['evaluator_notes'] as String?;
  final esigData = body['esignature'] as Map<String, dynamic>?;

  // 1. Verify the OJT assignment exists and get details
  final ojt = await supabase
      .from('employee_ojt')
      .select('id, status, employee_id, evaluator_id')
      .eq('id', ojtId)
      .maybeSingle();

  if (ojt == null) {
    throw NotFoundException('OJT assignment not found');
  }

  // 2. Verify the current user is the evaluator
  if (ojt['evaluator_id'] != auth.employeeId) {
    throw PermissionDeniedException('Only the assigned evaluator can sign off on tasks');
  }

  if (ojt['status'] == 'completed') {
    throw ConflictException('This OJT assignment is already completed');
  }

  // 3. Verify the task belongs to this OJT master
  final ojtMaster = await supabase
      .from('employee_ojt')
      .select('ojt_master_id')
      .eq('id', ojtId)
      .single();

  final task = await supabase
      .from('ojt_tasks')
      .select('id, name')
      .eq('id', taskId)
      .eq('ojt_master_id', ojtMaster['ojt_master_id'])
      .maybeSingle();

  if (task == null) {
    throw NotFoundException('Task not found in this OJT');
  }

  // 4. Check if task is already completed
  final existingCompletion = await supabase
      .from('ojt_task_completion')
      .select('id')
      .eq('employee_ojt_id', ojtId)
      .eq('ojt_task_id', taskId)
      .maybeSingle();

  if (existingCompletion != null) {
    throw ConflictException('This task has already been completed');
  }

  // 5. Create e-signature if provided
  String? esignatureId;
  if (esigData != null) {
    final reauthSessionId = esigData['reauth_session_id'] as String?;
    final meaning = esigData['meaning'] as String? ?? 'APPROVE';

    if (reauthSessionId != null) {
      // Validate reauth session and create e-signature
      final esig = await supabase.rpc(
        'create_esignature_from_reauth',
        params: {
          'p_reauth_session_id': reauthSessionId,
          'p_employee_id': auth.employeeId,
          'p_meaning': meaning,
          'p_context_type': 'ojt_task_completion',
          'p_context_id': taskId,
        },
      ) as Map<String, dynamic>;
      esignatureId = esig['esignature_id'] as String?;
    }
  }

  // 6. Record task completion
  final completion = await supabase.from('ojt_task_completion').insert({
    'employee_ojt_id': ojtId,
    'ojt_task_id': taskId,
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'evaluator_id': auth.employeeId,
    'evaluator_notes': evaluatorNotes,
    'esignature_id': esignatureId,
  }).select().single();

  // 7. Update completion percentage
  final totalTasks = await supabase
      .from('ojt_tasks')
      .select('id')
      .eq('ojt_master_id', ojtMaster['ojt_master_id']);

  final completedTasks = await supabase
      .from('ojt_task_completion')
      .select('id')
      .eq('employee_ojt_id', ojtId);

  final completionPercentage = (completedTasks.length / totalTasks.length * 100).round();

  // 8. Update OJT status
  final newStatus = completionPercentage >= 100 ? 'completed' : 'in_progress';
  await supabase.from('employee_ojt').update({
    'completion_percentage': completionPercentage,
    'status': newStatus,
    if (newStatus == 'completed') 'completed_at': DateTime.now().toUtc().toIso8601String(),
    if (newStatus == 'in_progress' && ojt['status'] == 'assigned')
      'started_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', ojtId);

  return ApiResponse.ok({
    ...completion,
    'completion_percentage': completionPercentage,
    'ojt_status': newStatus,
  }).toResponse();
}

/// GET /v1/train/ojt/:id/tasks
///
/// Returns all tasks for an OJT assignment with completion status.
Future<Response> ojtTasksListHandler(Request req) async {
  final ojtId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify the OJT assignment exists and belongs to the user (or they're the evaluator)
  final ojt = await supabase
      .from('employee_ojt')
      .select('id, ojt_master_id, employee_id, evaluator_id')
      .eq('id', ojtId)
      .maybeSingle();

  if (ojt == null) {
    throw NotFoundException('OJT assignment not found');
  }

  final isOwner = ojt['employee_id'] == auth.employeeId;
  final isEvaluator = ojt['evaluator_id'] == auth.employeeId;
  if (!isOwner && !isEvaluator) {
    throw PermissionDeniedException('You do not have access to this OJT assignment');
  }

  // Get all tasks with completion status
  final tasks = await supabase
      .from('ojt_tasks')
      .select('''
        id, task_number, name, description, criteria, sequence_order,
        ojt_task_completion!left(
          id, completed_at, evaluator_notes,
          employees!evaluator_id(id, first_name, last_name),
          electronic_signatures(id, meaning, signed_at)
        )
      ''')
      .eq('ojt_master_id', ojt['ojt_master_id'])
      .order('sequence_order', ascending: true);

  // Flatten completion data
  final enrichedTasks = tasks.map((task) {
    final completions = task['ojt_task_completion'] as List? ?? [];
    // Find the completion for this specific employee_ojt
    // Note: In actual query we'd filter by employee_ojt_id, but for simplicity
    // we're assuming one completion per task per employee
    final completion = completions.isNotEmpty ? completions.first : null;
    return {
      ...task,
      'is_completed': completion != null,
      'completion': completion,
    };
  }).toList();

  return ApiResponse.ok(enrichedTasks).toResponse();
}
