import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/certify/assessments/:id
/// 
/// Gets assessment attempt details with responses.
Future<Response> assessmentGetHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        *,
        question_paper:question_papers(
          id, title, pass_mark, total_marks, time_limit_minutes,
          questions:question_paper_questions(
            sequence_order,
            question:questions(
              id, question_text, question_type, marks,
              options:question_options(id, option_text)
            )
          )
        ),
        responses:assessment_responses(*)
      ''')
      .eq('id', attemptId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  // Permission check - own attempt or admin
  if (attempt['employee_id'] != auth.employeeId) {
    if (!auth.hasPermission('assessments.view_all')) {
      throw PermissionDeniedException('Not your assessment');
    }
  }

  // Calculate time remaining if still in progress
  Map<String, dynamic>? timeInfo;
  if (attempt['status'] == 'in_progress') {
    final startedAt = DateTime.parse(attempt['started_at']);
    final timeLimit = attempt['question_paper']['time_limit_minutes'] as int? ?? 60;
    final deadline = startedAt.add(Duration(minutes: timeLimit));
    final now = DateTime.now().toUtc();
    final remainingSeconds = deadline.difference(now).inSeconds;
    
    timeInfo = {
      'started_at': attempt['started_at'],
      'deadline': deadline.toIso8601String(),
      'remaining_seconds': remainingSeconds > 0 ? remainingSeconds : 0,
      'time_limit_minutes': timeLimit,
    };
  }

  return ApiResponse.ok({
    'attempt': attempt,
    'time_info': timeInfo,
  }).toResponse();
}

/// GET /v1/certify/assessments/history
/// 
/// Gets the current employee's assessment history.
Future<Response> assessmentHistoryHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  
  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;
  final offset = (page - 1) * perPage;
  final status = params['status'];

  var query = supabase
      .from('assessment_attempts')
      .select('''
        id, status, percentage, is_passed, attempt_number, 
        submitted_at, created_at,
        question_paper:question_papers(id, title)
      ''')
      .eq('employee_id', auth.employeeId);

  if (status != null && status.isNotEmpty) {
    query = query.eq('status', status);
  }

  final attempts = await query
      .order('created_at', ascending: false)
      .range(offset, offset + perPage - 1);

  // Get total count
  final countResult = await supabase
      .from('assessment_attempts')
      .select('id')
      .eq('employee_id', auth.employeeId)
      .count();

  final pagination = Pagination.compute(
    page: page,
    perPage: perPage,
    total: countResult.count,
  );

  return ApiResponse.paginated({'history': attempts}, pagination).toResponse();
}

/// GET /v1/certify/assessments/:id/questions/analysis
/// 
/// Admin/trainer only - psychometric analysis of assessment responses.
Future<Response> assessmentQuestionAnalysisHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check
  if (!auth.hasPermission('assessments.analyze')) {
    throw PermissionDeniedException('Analysis permission required');
  }

  // Get attempt with all responses
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, employee_id, percentage, is_passed,
        question_paper:question_papers(id, title),
        responses:assessment_responses(
          id, question_id, is_correct, marks_awarded, time_spent_seconds,
          question:questions(id, question_text, question_type, marks)
        )
      ''')
      .eq('id', attemptId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  final responses = attempt['responses'] as List? ?? [];
  
  // Calculate analysis metrics
  int totalQuestions = responses.length;
  int correctAnswers = 0;
  int incorrectAnswers = 0;
  int unattempted = 0;
  double totalTimeSpent = 0;
  final questionBreakdown = <Map<String, dynamic>>[];

  for (final r in responses) {
    final isCorrect = r['is_correct'] as bool?;
    final timeSpent = (r['time_spent_seconds'] as num?)?.toDouble() ?? 0;
    totalTimeSpent += timeSpent;

    if (isCorrect == true) {
      correctAnswers++;
    } else if (isCorrect == false) {
      incorrectAnswers++;
    } else {
      unattempted++;
    }

    questionBreakdown.add({
      'question_id': r['question_id'],
      'question_text': r['question']?['question_text'],
      'question_type': r['question']?['question_type'],
      'max_marks': r['question']?['marks'],
      'marks_awarded': r['marks_awarded'],
      'is_correct': isCorrect,
      'time_spent_seconds': timeSpent,
    });
  }

  return ApiResponse.ok({
    'attempt_id': attemptId,
    'question_paper': attempt['question_paper'],
    'summary': {
      'total_questions': totalQuestions,
      'correct_answers': correctAnswers,
      'incorrect_answers': incorrectAnswers,
      'unattempted': unattempted,
      'accuracy_percentage': totalQuestions > 0 
          ? (correctAnswers / totalQuestions) * 100 
          : 0,
      'total_time_spent_seconds': totalTimeSpent,
      'average_time_per_question': totalQuestions > 0 
          ? totalTimeSpent / totalQuestions 
          : 0,
    },
    'question_breakdown': questionBreakdown,
  }).toResponse();
}
