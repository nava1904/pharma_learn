import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/certify/assessments/start
///
/// Starts a new assessment attempt for an obligation.
/// Returns the question paper with all questions (per design decision Q5).
///
/// Body:
/// ```json
/// {
///   "employee_assignment_id": "uuid"
/// }
/// ```
Future<Response> assessmentStartHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final obligationId = body['employee_assignment_id'] as String?;
  if (obligationId == null || obligationId.isEmpty) {
    throw ValidationException({'employee_assignment_id': 'Required'});
  }

  // Verify the obligation belongs to this employee
  final obligation = await supabase
      .from('employee_assignments')
      .select('''
        id, status,
        training_assignments!inner(
          id,
          courses!inner(
            id, title, assessment_required, passing_percentage, max_attempts,
            time_limit_minutes, question_paper_id
          )
        )
      ''')
      .eq('id', obligationId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (obligation == null) {
    throw NotFoundException('Obligation not found');
  }

  if (obligation['status'] == 'completed') {
    throw ConflictException('This obligation is already completed');
  }

  final course = obligation['training_assignments']['courses'] as Map<String, dynamic>;
  
  if (course['assessment_required'] != true) {
    throw ValidationException({'assessment': 'This course does not require an assessment'});
  }

  final questionPaperId = course['question_paper_id'] as String?;
  if (questionPaperId == null) {
    throw ConflictException('No question paper configured for this course');
  }

  final maxAttempts = course['max_attempts'] as int? ?? 3;
  final timeLimitMinutes = course['time_limit_minutes'] as int? ?? 60;

  // Check previous attempts
  final previousAttempts = await supabase
      .from('assessment_attempts')
      .select('id, attempt_number, passed')
      .eq('employee_assignment_id', obligationId)
      .order('attempt_number', ascending: false);

  final attemptCount = previousAttempts.length;

  // Check if already passed
  if (previousAttempts.any((a) => a['passed'] == true)) {
    throw ConflictException('Assessment already passed');
  }

  // Check max attempts
  if (attemptCount >= maxAttempts) {
    throw ConflictException('Maximum attempts ($maxAttempts) reached');
  }

  // Check for incomplete attempt
  final incompleteAttempt = await supabase
      .from('assessment_attempts')
      .select('id, started_at')
      .eq('employee_assignment_id', obligationId)
      .eq('status', 'in_progress')
      .maybeSingle();

  if (incompleteAttempt != null) {
    // Check if time expired (with 30s grace period per design Q5)
    final startedAt = DateTime.parse(incompleteAttempt['started_at'] as String);
    final deadline = startedAt.add(Duration(minutes: timeLimitMinutes, seconds: 30));
    
    if (DateTime.now().isBefore(deadline)) {
      // Return existing attempt
      return _loadAttemptWithQuestions(supabase, incompleteAttempt['id'] as String);
    } else {
      // Auto-submit expired attempt
      await supabase.from('assessment_attempts').update({
        'status': 'submitted',
        'submitted_at': DateTime.now().toUtc().toIso8601String(),
        'auto_submitted': true,
      }).eq('id', incompleteAttempt['id']);
    }
  }

  // Load question paper with questions
  final questionPaper = await supabase
      .from('question_papers')
      .select('''
        id, title, total_marks, duration_minutes,
        question_paper_questions!inner(
          sequence_order, marks,
          questions!inner(
            id, question_type, question_text, options, 
            correct_answer, explanation, difficulty
          )
        )
      ''')
      .eq('id', questionPaperId)
      .single();

  // Check for questions that require review (open-ended)
  final questions = questionPaper['question_paper_questions'] as List;
  final hasOpenEnded = questions.any((q) {
    final questionType = q['questions']['question_type'] as String?;
    return questionType == 'open_ended' || questionType == 'essay';
  });

  // Create new attempt
  final now = DateTime.now().toUtc();
  final attempt = await supabase.from('assessment_attempts').insert({
    'employee_assignment_id': obligationId,
    'employee_id': auth.employeeId,
    'question_paper_id': questionPaperId,
    'attempt_number': attemptCount + 1,
    'started_at': now.toIso8601String(),
    'deadline_at': now.add(Duration(minutes: timeLimitMinutes)).toIso8601String(),
    'status': 'in_progress',
    'requires_review': hasOpenEnded,
  }).select().single();

  // Prepare response (hide correct answers)
  final sanitizedQuestions = questions.map((q) {
    final question = q['questions'] as Map<String, dynamic>;
    return {
      'id': question['id'],
      'sequence_order': q['sequence_order'],
      'marks': q['marks'],
      'question_type': question['question_type'],
      'question_text': question['question_text'],
      'options': question['options'],
      'difficulty': question['difficulty'],
      // Exclude: correct_answer, explanation
    };
  }).toList();

  return ApiResponse.created({
    'attempt_id': attempt['id'],
    'attempt_number': attempt['attempt_number'],
    'started_at': attempt['started_at'],
    'deadline_at': attempt['deadline_at'],
    'time_limit_minutes': timeLimitMinutes,
    'question_paper': {
      'id': questionPaper['id'],
      'title': questionPaper['title'],
      'total_marks': questionPaper['total_marks'],
    },
    'questions': sanitizedQuestions,
  }).toResponse();
}

/// Helper to load an existing attempt with questions
Future<Response> _loadAttemptWithQuestions(dynamic supabase, String attemptId) async {
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, attempt_number, started_at, deadline_at, status,
        question_papers!inner(
          id, title, total_marks,
          question_paper_questions!inner(
            sequence_order, marks,
            questions!inner(
              id, question_type, question_text, options, difficulty
            )
          )
        )
      ''')
      .eq('id', attemptId)
      .single();

  // Get existing responses
  final responses = await supabase
      .from('assessment_responses')
      .select('question_id, response')
      .eq('attempt_id', attemptId);

  final responseMap = <String, dynamic>{};
  for (final r in responses) {
    responseMap[r['question_id'] as String] = r['response'];
  }

  final questionPaper = attempt['question_papers'] as Map<String, dynamic>;
  final questions = (questionPaper['question_paper_questions'] as List).map((q) {
    final question = q['questions'] as Map<String, dynamic>;
    return {
      'id': question['id'],
      'sequence_order': q['sequence_order'],
      'marks': q['marks'],
      'question_type': question['question_type'],
      'question_text': question['question_text'],
      'options': question['options'],
      'difficulty': question['difficulty'],
      'saved_response': responseMap[question['id']],
    };
  }).toList();

  return ApiResponse.ok({
    'attempt_id': attempt['id'],
    'attempt_number': attempt['attempt_number'],
    'started_at': attempt['started_at'],
    'deadline_at': attempt['deadline_at'],
    'status': 'in_progress',
    'question_paper': {
      'id': questionPaper['id'],
      'title': questionPaper['title'],
      'total_marks': questionPaper['total_marks'],
    },
    'questions': questions,
  }).toResponse();
}

/// POST /v1/certify/assessments/:id/answer
///
/// Saves an answer for a question in the current attempt.
/// Server-side save to handle network interruptions.
///
/// Body:
/// ```json
/// {
///   "question_id": "uuid",
///   "response": "selected_option" | ["option1", "option2"] | "text answer"
/// }
/// ```
Future<Response> assessmentAnswerHandler(Request req) async {
  final attemptId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final questionId = body['question_id'] as String?;
  final response = body['response'];

  if (questionId == null || questionId.isEmpty) {
    throw ValidationException({'question_id': 'Required'});
  }

  // Verify attempt belongs to user and is in progress
  final attempt = await supabase
      .from('assessment_attempts')
      .select('id, status, deadline_at')
      .eq('id', attemptId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  if (attempt['status'] != 'in_progress') {
    throw ConflictException('This attempt has already been submitted');
  }

  // Check deadline (with 30s grace)
  final deadline = DateTime.parse(attempt['deadline_at'] as String)
      .add(const Duration(seconds: 30));
  if (DateTime.now().isAfter(deadline)) {
    throw ConflictException('Time limit exceeded');
  }

  // Upsert response
  await supabase.from('assessment_responses').upsert({
    'attempt_id': attemptId,
    'question_id': questionId,
    'response': response,
    'answered_at': DateTime.now().toUtc().toIso8601String(),
  }, onConflict: 'attempt_id,question_id');

  return ApiResponse.ok({
    'saved': true,
    'question_id': questionId,
  }).toResponse();
}

/// POST /v1/certify/assessments/:id/submit
///
/// Submits the assessment attempt for grading.
/// Auto-grades MCQ/fill-in, marks open-ended for review.
Future<Response> assessmentSubmitHandler(Request req) async {
  final attemptId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Proctoring flags (per design decision Q5)
  final proctoringFlags = body['proctoring'] as Map<String, dynamic>?;

  // Verify attempt belongs to user and is in progress
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, status, deadline_at, employee_assignment_id, requires_review,
        question_papers!inner(
          id, total_marks, passing_percentage,
          question_paper_questions!inner(
            marks,
            questions!inner(id, question_type, correct_answer)
          )
        )
      ''')
      .eq('id', attemptId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  if (attempt['status'] != 'in_progress') {
    throw ConflictException('This attempt has already been submitted');
  }

  // Get all responses
  final responses = await supabase
      .from('assessment_responses')
      .select('question_id, response')
      .eq('attempt_id', attemptId);

  final responseMap = <String, dynamic>{};
  for (final r in responses) {
    responseMap[r['question_id'] as String] = r['response'];
  }

  // Grade auto-gradable questions
  final questionPaper = attempt['question_papers'] as Map<String, dynamic>;
  final questions = questionPaper['question_paper_questions'] as List;
  final passingPercentage = questionPaper['passing_percentage'] as int? ?? 80;

  int totalMarks = 0;
  int earnedMarks = 0;
  int pendingReviewMarks = 0;

  for (final q in questions) {
    final question = q['questions'] as Map<String, dynamic>;
    final questionId = question['id'] as String;
    final questionType = question['question_type'] as String;
    final correctAnswer = question['correct_answer'];
    final marks = q['marks'] as int? ?? 1;
    totalMarks += marks;

    final userResponse = responseMap[questionId];

    if (questionType == 'open_ended' || questionType == 'essay') {
      // Requires manual review
      pendingReviewMarks += marks;
    } else if (userResponse != null) {
      // Auto-grade MCQ, multi-select, fill-in
      bool isCorrect = false;
      
      if (questionType == 'multi_select') {
        // Compare arrays
        final correctSet = Set.from(correctAnswer as List? ?? []);
        final userSet = Set.from(userResponse as List? ?? []);
        isCorrect = correctSet.difference(userSet).isEmpty && 
                    userSet.difference(correctSet).isEmpty;
      } else {
        // Single value comparison
        isCorrect = userResponse.toString().trim().toLowerCase() ==
            correctAnswer.toString().trim().toLowerCase();
      }

      if (isCorrect) {
        earnedMarks += marks;
      }

      // Update response with grading
      await supabase.from('assessment_responses').update({
        'is_correct': isCorrect,
        'marks_earned': isCorrect ? marks : 0,
        'auto_graded': true,
      }).eq('attempt_id', attemptId).eq('question_id', questionId);
    }
  }

  // Calculate score (exclude pending review from denominator for now)
  final gradableMarks = totalMarks - pendingReviewMarks;
  final score = gradableMarks > 0 ? (earnedMarks / gradableMarks * 100).round() : 0;
  final requiresReview = pendingReviewMarks > 0;
  final passed = !requiresReview && score >= passingPercentage;

  // Update attempt
  final now = DateTime.now().toUtc().toIso8601String();
  await supabase.from('assessment_attempts').update({
    'status': requiresReview ? 'pending_review' : 'submitted',
    'submitted_at': now,
    'score': score,
    'total_marks': totalMarks,
    'earned_marks': earnedMarks,
    'passed': passed,
    'proctoring_flags': proctoringFlags,
  }).eq('id', attemptId);

  return ApiResponse.ok({
    'attempt_id': attemptId,
    'status': requiresReview ? 'pending_review' : 'graded',
    'score': score,
    'passed': passed,
    'earned_marks': earnedMarks,
    'total_marks': totalMarks,
    'requires_review': requiresReview,
    'pending_review_marks': pendingReviewMarks,
  }).toResponse();
}

/// GET /v1/certify/assessments/:id
///
/// Returns assessment attempt details and results.
Future<Response> assessmentGetHandler(Request req) async {
  final attemptId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, attempt_number, started_at, submitted_at, deadline_at,
        status, score, passed, total_marks, earned_marks, requires_review,
        employee_assignment_id,
        question_papers!inner(id, title)
      ''')
      .eq('id', attemptId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  // If submitted, include detailed results
  if (attempt['status'] != 'in_progress') {
    final responses = await supabase
        .from('assessment_responses')
        .select('''
          question_id, response, is_correct, marks_earned,
          questions!inner(question_text, question_type, correct_answer, explanation)
        ''')
        .eq('attempt_id', attemptId);

    return ApiResponse.ok({
      ...attempt,
      'responses': responses,
    }).toResponse();
  }

  return ApiResponse.ok(attempt).toResponse();
}

/// GET /v1/certify/assessments/history
///
/// Returns assessment history for the current employee.
Future<Response> assessmentHistoryHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final obligationId = req.url.queryParameters['employee_assignment_id'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;

  var query = supabase
      .from('assessment_attempts')
      .select('''
        id, attempt_number, started_at, submitted_at,
        status, score, passed,
        employee_assignments!inner(
          id,
          training_assignments!inner(
            courses!inner(id, title, course_code)
          )
        )
      ''')
      .eq('employee_id', auth.employeeId);

  if (obligationId != null) {
    query = query.eq('employee_assignment_id', obligationId);
  }

  final response = await query
      .order('started_at', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  return ApiResponse.ok(response).toResponse();
}
