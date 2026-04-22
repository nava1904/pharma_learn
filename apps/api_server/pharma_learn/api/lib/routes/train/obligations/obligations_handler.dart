import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/train/obligations
///
/// Returns the current employee's training obligations (employee_assignments).
/// Includes filtering by status, course, due date range.
///
/// Query params:
/// - status: assigned|in_progress|completed|overdue|waived (optional)
/// - due_before: ISO date (optional)
/// - due_after: ISO date (optional)
/// - page, per_page: pagination
Future<Response> obligationsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final status = req.url.queryParameters['status'];
  final dueBefore = req.url.queryParameters['due_before'];
  final dueAfter = req.url.queryParameters['due_after'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;

  // Build count query
  var countQuery = supabase
      .from('employee_assignments')
      .select('id')
      .eq('employee_id', auth.employeeId);
  if (status != null) countQuery = countQuery.eq('status', status);
  if (dueBefore != null) countQuery = countQuery.lte('due_date', dueBefore);
  if (dueAfter != null) countQuery = countQuery.gte('due_date', dueAfter);
  final countResult = await countQuery;
  final total = countResult.length;

  // Build data query with relations
  var query = supabase
      .from('employee_assignments')
      .select('''
        id, status, assigned_at, due_date, completed_at, waived_at, waiver_reason,
        training_assignments!inner(
          id, name, assignment_type, priority,
          courses!inner(id, title, course_code, duration_minutes, assessment_required)
        ),
        learning_progress(id, progress_percentage, started_at, last_activity_at)
      ''')
      .eq('employee_id', auth.employeeId);

  if (status != null) query = query.eq('status', status);
  if (dueBefore != null) query = query.lte('due_date', dueBefore);
  if (dueAfter != null) query = query.gte('due_date', dueAfter);

  final response = await query
      .order('due_date', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  // Compute overdue flag for each obligation
  final now = DateTime.now();
  final enriched = response.map((row) {
    final dueDate = DateTime.tryParse(row['due_date'] ?? '');
    final isOverdue = dueDate != null &&
        dueDate.isBefore(now) &&
        row['status'] != 'completed' &&
        row['status'] != 'waived';
    return {
      ...row,
      'is_overdue': isOverdue,
    };
  }).toList();

  return ApiResponse.paginated(
    enriched,
    Pagination.compute(page: page, perPage: perPage, total: total),
  ).toResponse();
}

/// GET /v1/train/obligations/:id
///
/// Returns details of a specific obligation.
Future<Response> obligationGetHandler(Request req) async {
  final obligationId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final obligation = await supabase
      .from('employee_assignments')
      .select('''
        id, status, assigned_at, due_date, completed_at, waived_at, waiver_reason,
        training_assignments!inner(
          id, name, assignment_type, priority, description,
          courses!inner(
            id, title, course_code, description, duration_minutes, 
            assessment_required, passing_percentage, max_attempts
          )
        ),
        learning_progress(
          id, progress_percentage, started_at, last_activity_at, 
          completion_method, scorm_session_time
        ),
        waivers(id, status, reason, requested_at, approved_at)
      ''')
      .eq('id', obligationId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (obligation == null) {
    throw NotFoundException('Obligation not found');
  }

  return ApiResponse.ok(obligation).toResponse();
}

/// POST /v1/train/obligations/:id/waive
///
/// Requests a waiver for an obligation. Requires reason and creates
/// a pending waiver request.
///
/// Body: `{"reason": "string"}`
Future<Response> obligationWaiveHandler(Request req) async {
  final obligationId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final reason = body['reason'] as String?;
  if (reason == null || reason.trim().isEmpty) {
    throw ValidationException({'reason': 'Waiver reason is required'});
  }

  // Verify the obligation belongs to this employee and is waivable
  final obligation = await supabase
      .from('employee_assignments')
      .select('id, status')
      .eq('id', obligationId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (obligation == null) {
    throw NotFoundException('Obligation not found');
  }

  if (obligation['status'] == 'completed') {
    throw ConflictException('Cannot waive a completed obligation');
  }

  if (obligation['status'] == 'waived') {
    throw ConflictException('Obligation is already waived');
  }

  // Check for existing pending waiver
  final existingWaiver = await supabase
      .from('training_waivers')
      .select('id')
      .eq('assignment_id', obligationId)
      .eq('status', 'pending_approval')
      .maybeSingle();

  if (existingWaiver != null) {
    throw ConflictException('A waiver request is already pending for this obligation');
  }

  // Create waiver request
  final waiver = await supabase.from('training_waivers').insert({
    'assignment_id': obligationId,
    'employee_id': auth.employeeId,
    'reason': reason.trim(),
    'status': 'pending_approval',
    'requested_at': DateTime.now().toUtc().toIso8601String(),
  }).select().single();

  return ApiResponse.created(waiver).toResponse();
}
