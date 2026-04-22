import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/certify/assessments/:id/results
///
/// Returns results for a completed assessment attempt.
/// Shows score, pass/fail, and optionally detailed feedback.
Future<Response> assessmentResultsHandler(Request req) async {
  final attemptId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  
  final includeDetails = req.url.queryParameters['include_details'] == 'true';

  // Get the assessment attempt with results
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, status, started_at, submitted_at, time_limit_minutes,
        employee_id, training_record_id,
        employees!employee_id(id, first_name, last_name, employee_number),
        question_paper_id,
        question_papers!inner(
          id, name, total_marks, passing_percentage, passing_marks,
          courses!inner(id, title, course_code)
        ),
        assessment_results!inner(
          id, total_score, percentage, passed, graded_at,
          graded_by,
          employees!graded_by(id, first_name, last_name)
        )
      ''')
      .eq('id', attemptId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  // Check access - employee can see their own, managers/trainers can see others
  final isOwnAttempt = attempt['employee_id'] == auth.employeeId;
  
  if (!isOwnAttempt) {
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.viewAssessmentResults,
      jwtPermissions: auth.permissions,
    );
  }

  // Build response
  final questionPaper = attempt['question_papers'] as Map<String, dynamic>;
  final result = attempt['assessment_results'] as Map<String, dynamic>?;
  
  if (result == null) {
    throw NotFoundException('Assessment has not been graded yet');
  }

  final response = <String, dynamic>{
    'attempt_id': attemptId,
    'status': attempt['status'],
    'started_at': attempt['started_at'],
    'submitted_at': attempt['submitted_at'],
    'employee': attempt['employees'],
    'question_paper': {
      'id': questionPaper['id'],
      'name': questionPaper['name'],
      'total_marks': questionPaper['total_marks'],
      'passing_percentage': questionPaper['passing_percentage'],
      'passing_marks': questionPaper['passing_marks'],
      'course': questionPaper['courses'],
    },
    'result': {
      'total_score': result['total_score'],
      'percentage': result['percentage'],
      'passed': result['passed'],
      'graded_at': result['graded_at'],
      'graded_by': result['employees'],
    },
  };

  // Optionally include detailed breakdown per question
  if (includeDetails) {
    final answers = await supabase
        .from('assessment_answers')
        .select('''
          id, question_id, selected_options, text_answer, marks_awarded, feedback,
          questions!inner(
            id, question_text, question_type, marks, correct_options,
            options, explanation
          )
        ''')
        .eq('attempt_id', attemptId)
        .order('created_at', ascending: true);

    final questionDetails = <Map<String, dynamic>>[];
    for (final answer in answers) {
      final question = answer['questions'] as Map<String, dynamic>;
      final isCorrect = answer['marks_awarded'] == question['marks'];
      
      questionDetails.add({
        'question_id': answer['question_id'],
        'question_text': question['question_text'],
        'question_type': question['question_type'],
        'max_marks': question['marks'],
        'marks_awarded': answer['marks_awarded'],
        'is_correct': isCorrect,
        'selected_answer': answer['selected_options'] ?? answer['text_answer'],
        'correct_answer': question['correct_options'],
        'explanation': question['explanation'],
        'feedback': answer['feedback'],
      });
    }
    
    response['question_details'] = questionDetails;
  }

  return ApiResponse.ok(response).toResponse();
}
