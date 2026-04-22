import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../services/assessment_service.dart';
import '../../../utils/param_helpers.dart';

/// GET /v1/certify/assessments/grading-queue
///
/// Lists items in the grading queue for manual grading.
/// Filterable by status and assigned grader.
///
/// Query params:
/// - status: 'pending', 'assigned', 'completed'
/// - assigned_to: UUID of assigned grader (filter)
/// - page: Page number (default 1)
/// - per_page: Items per page (default 50, max 100)
Future<Response> gradingQueueListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAssessments,
    jwtPermissions: auth.permissions,
  );

  final status = req.url.queryParameters['status'];
  final assignedTo = req.url.queryParameters['assigned_to'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  var perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '50') ?? 50;
  if (perPage > 100) perPage = 100;

  final offset = (page - 1) * perPage;

  final assessmentService = AssessmentService(supabase);
  final queue = await assessmentService.getGradingQueue(
    status: status,
    assignedTo: assignedTo,
    limit: perPage,
    offset: offset,
  );

  // Get total count
  var countQuery = supabase.from('grading_queue').select('id');
  if (status != null) {
    countQuery = countQuery.eq('status', status);
  }
  if (assignedTo != null) {
    countQuery = countQuery.eq('assigned_to', assignedTo);
  }
  final countResult = await countQuery.count();

  return ApiResponse.ok({
    'items': queue,
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': countResult.count,
      'total_pages': (countResult.count / perPage).ceil(),
    },
  }).toResponse();
}

/// GET /v1/certify/assessments/grading-queue/:id
///
/// Gets details of a specific grading queue item with all ungraded responses.
Future<Response> gradingQueueGetHandler(Request req) async {
  final queueId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAssessments,
    jwtPermissions: auth.permissions,
  );

  // Get queue item with attempt details
  final queueItem = await supabase
      .from('grading_queue')
      .select('''
        *,
        attempt:assessment_attempts(
          id,
          employee:employees(id, full_name, employee_number),
          assessment:assessments(id, name, course_id),
          responses:assessment_responses(
            id,
            question_id,
            answer_data,
            points_earned,
            is_correct,
            graded_at,
            grader_feedback,
            question:questions(
              id,
              question_text,
              question_type,
              points,
              grading_rubric
            )
          )
        )
      ''')
      .eq('id', queueId)
      .maybeSingle();

  if (queueItem == null) {
    throw NotFoundException('Grading queue item not found');
  }

  // Filter to only show ungraded responses
  final attempt = queueItem['attempt'] as Map<String, dynamic>?;
  if (attempt != null) {
    final responses = attempt['responses'] as List? ?? [];
    final ungraded = responses.where((r) => r['graded_at'] == null).toList();
    attempt['ungraded_responses'] = ungraded;
    attempt['graded_responses'] = responses.where((r) => r['graded_at'] != null).toList();
  }

  return ApiResponse.ok(queueItem).toResponse();
}

/// POST /v1/certify/assessments/grading-queue/:id/assign
///
/// Assigns a grading queue item to a grader.
///
/// Body:
/// ```json
/// {
///   "grader_id": "uuid"
/// }
/// ```
Future<Response> gradingQueueAssignHandler(Request req) async {
  final queueId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAssessments,
    jwtPermissions: auth.permissions,
  );

  final body = await readJson(req);
  final graderIdRaw = body['grader_id'] as String?;

  if (graderIdRaw == null) {
    throw ValidationException({'grader_id': 'Grader ID is required'});
  }

  final graderId = parsePathUuid(graderIdRaw, fieldName: 'grader_id');

  // Verify grader exists and has permission
  final grader = await supabase
      .from('employees')
      .select('id, full_name')
      .eq('id', graderId)
      .eq('status', 'active')
      .maybeSingle();

  if (grader == null) {
    throw NotFoundException('Grader not found or inactive');
  }

  final assessmentService = AssessmentService(supabase);
  final updated = await assessmentService.assignGrader(
    queueId: queueId,
    graderId: graderId,
  );

  return ApiResponse.ok({
    'queue_item': updated,
    'assigned_to': grader,
    'message': 'Grading item assigned successfully',
  }).toResponse();
}

/// POST /v1/certify/assessments/grading-queue/:id/grade
///
/// Submits manual grades for responses in a grading queue item.
///
/// Body:
/// ```json
/// {
///   "grades": [
///     {
///       "response_id": "uuid",
///       "points_earned": 8.5,
///       "feedback": "Good answer but...",
///       "rubric_scores": {"criterion1": 3, "criterion2": 4}
///     }
///   ]
/// }
/// ```
Future<Response> gradingQueueGradeHandler(Request req) async {
  final queueId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAssessments,
    jwtPermissions: auth.permissions,
  );

  // Verify queue item exists and is assigned to this grader (or admin)
  final queueItem = await supabase
      .from('grading_queue')
      .select('id, assigned_to, status, attempt_id')
      .eq('id', queueId)
      .maybeSingle();

  if (queueItem == null) {
    throw NotFoundException('Grading queue item not found');
  }

  if (queueItem['status'] == 'completed') {
    throw ConflictException('This item has already been graded');
  }

  // Check if assigned to this user (if assigned)
  final assignedTo = queueItem['assigned_to'] as String?;

  if (assignedTo != null && assignedTo != auth.employeeId) {
    // Check if user has manage permission to override
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.manageAssessments,
      jwtPermissions: auth.permissions,
    );
  }

  final body = await readJson(req);
  final grades = body['grades'] as List<dynamic>?;

  if (grades == null || grades.isEmpty) {
    throw ValidationException({'grades': 'At least one grade is required'});
  }

  final assessmentService = AssessmentService(supabase);
  final results = <Map<String, dynamic>>[];

  for (final grade in grades) {
    final responseIdRaw = grade['response_id'] as String?;
    if (responseIdRaw == null) {
      throw ValidationException({'grades': 'Each grade must have response_id'});
    }

    final responseId = parsePathUuid(responseIdRaw, fieldName: 'response_id');
    final pointsEarned = (grade['points_earned'] as num?)?.toDouble();
    final feedback = grade['feedback'] as String?;
    final rubricScores = grade['rubric_scores'] as Map<String, dynamic>?;

    if (pointsEarned == null) {
      throw ValidationException({'grades': 'Each grade must have points_earned'});
    }

    final result = await assessmentService.submitManualGrade(
      responseId: responseId,
      graderId: auth.employeeId,
      pointsEarned: pointsEarned,
      feedback: feedback,
      rubricScores: rubricScores,
    );

    results.add(result);
  }

  // Check if queue item is now complete
  final updatedQueue = await supabase
      .from('grading_queue')
      .select('status')
      .eq('id', queueId)
      .single();

  return ApiResponse.ok({
    'graded_count': results.length,
    'results': results,
    'queue_status': updatedQueue['status'],
    'completed': updatedQueue['status'] == 'completed',
  }).toResponse();
}

/// GET /v1/certify/assessments/graders
///
/// Lists available graders for manual assessment grading.
Future<Response> gradersListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAssessments,
    jwtPermissions: auth.permissions,
  );

  // Get employees with grading permission
  // This gets trainers and anyone with manageAssessments permission
  final graders = await supabase
      .from('employees')
      .select('''
        id,
        full_name,
        employee_number,
        email,
        job_role:job_roles(name),
        department:departments(name)
      ''')
      .eq('organization_id', auth.orgId)
      .eq('status', 'active')
      .or('is_trainer.eq.true,job_role_id.in.(SELECT id FROM job_roles WHERE permissions @> \'["manage_assessments"]\')')
      .order('full_name');

  // Get grading stats for each grader
  final graderStats = <String, Map<String, dynamic>>{};
  for (final grader in graders) {
    final graderId = grader['id'] as String;

    // Count pending and completed
    final pending = await supabase
        .from('grading_queue')
        .select('id')
        .eq('assigned_to', graderId)
        .eq('status', 'assigned')
        .count();

    final completed = await supabase
        .from('grading_queue')
        .select('id')
        .eq('assigned_to', graderId)
        .eq('status', 'completed')
        .count();

    graderStats[graderId] = {
      'pending_count': pending.count,
      'completed_count': completed.count,
    };
  }

  // Combine grader info with stats
  final enrichedGraders = graders.map((g) {
    final graderId = g['id'] as String;
    return {
      ...g,
      ...graderStats[graderId] ?? {'pending_count': 0, 'completed_count': 0},
    };
  }).toList();

  return ApiResponse.ok({
    'graders': enrichedGraders,
    'total': enrichedGraders.length,
  }).toResponse();
}
