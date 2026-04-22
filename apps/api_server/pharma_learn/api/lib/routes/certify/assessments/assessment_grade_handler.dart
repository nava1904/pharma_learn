import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/certify/assessments/:id/grade
///
/// Manual grading for open-ended questions.
/// Used by trainers to score essay/descriptive answers.
/// URS §4.2.1.19: Manual grading workflow
///
/// Body:
/// ```json
/// {
///   "gradings": [
///     {
///       "answer_id": "uuid",
///       "score": 8,
///       "max_score": 10,
///       "feedback": "Good explanation but missing key point about..."
///     }
///   ]
/// }
/// ```
Future<Response> assessmentGradeHandler(Request req) async {
  final assessmentId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAssessments,
    jwtPermissions: auth.permissions,
  );

  // Get assessment and verify it's in 'pending_review' status
  final assessment = await supabase
      .from('assessments')
      .select('''
        id, status, course_id, employee_id,
        courses!inner ( trainer_id )
      ''')
      .eq('id', assessmentId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (assessment == null) throw NotFoundException('Assessment not found');

  final status = assessment['status'] as String?;
  if (status != 'pending_review') {
    throw ConflictException(
      'Assessment cannot be graded in status "$status". '
      'Only assessments with status "pending_review" can be graded.',
    );
  }

  // Verify the grader has permission (trainer or authorized reviewer)
  // Permission already checked above via PermissionChecker

  final body = await readJson(req);
  final gradings = body['gradings'] as List<dynamic>?;

  if (gradings == null || gradings.isEmpty) {
    throw ValidationException({'gradings': 'At least one grading is required'});
  }

  final now = DateTime.now().toUtc().toIso8601String();
  final gradedAnswers = <Map<String, dynamic>>[];

  // Process each grading
  for (final grading in gradings) {
    final answerIdRaw = grading['answer_id'] as String?;
    if (answerIdRaw == null) {
      throw ValidationException({'gradings': 'Each grading must have answer_id'});
    }
    final answerId = parsePathUuid(answerIdRaw, fieldName: 'answer_id');

    final score = (grading['score'] as num?)?.toDouble();
    final maxScore = (grading['max_score'] as num?)?.toDouble();
    final feedback = grading['feedback'] as String?;

    if (score == null || maxScore == null) {
      throw ValidationException({
        'gradings': 'Each grading must have score and max_score',
      });
    }

    if (score < 0 || score > maxScore) {
      throw ValidationException({
        'gradings': 'Score must be between 0 and max_score',
      });
    }

    // Update the answer with grading
    final updated = await supabase
        .from('assessment_answers')
        .update({
          'score': score,
          'max_score': maxScore,
          'graded_by': auth.employeeId,
          'graded_at': now,
          'grader_feedback': feedback,
          'is_graded': true,
        })
        .eq('id', answerId)
        .eq('assessment_id', assessmentId)
        .select()
        .maybeSingle();

    if (updated == null) {
      throw NotFoundException('Answer $answerId not found in this assessment');
    }

    gradedAnswers.add(updated);
  }

  // Check if all answers are now graded
  final ungradedCount = await supabase
      .from('assessment_answers')
      .select('id')
      .eq('assessment_id', assessmentId)
      .eq('is_graded', false);

  final allGraded = ungradedCount.isEmpty;

  // If all graded, calculate final score and update assessment
  if (allGraded) {
    // Get all answers to calculate total score
    final allAnswers = await supabase
        .from('assessment_answers')
        .select('score, max_score')
        .eq('assessment_id', assessmentId);

    var finalScore = 0.0;
    var finalMaxScore = 0.0;

    for (final answer in allAnswers) {
      finalScore += (answer['score'] as num?)?.toDouble() ?? 0;
      finalMaxScore += (answer['max_score'] as num?)?.toDouble() ?? 0;
    }

    final percentage = finalMaxScore > 0 
        ? (finalScore / finalMaxScore * 100).roundToDouble() 
        : 0.0;

    // Get passing threshold from course
    final courseDetails = await supabase
        .from('courses')
        .select('passing_score')
        .eq('id', assessment['course_id'])
        .single();

    final passingScore = (courseDetails['passing_score'] as num?)?.toDouble() ?? 70.0;
    final passed = percentage >= passingScore;

    // Update assessment with final results
    await supabase
        .from('assessments')
        .update({
          'status': passed ? 'passed' : 'failed',
          'score': finalScore,
          'max_score': finalMaxScore,
          'percentage': percentage,
          'completed_at': now,
          'graded_at': now,
          'graded_by': auth.employeeId,
        })
        .eq('id', assessmentId);

    return ApiResponse.ok({
      'assessment_id': assessmentId,
      'graded_answers': gradedAnswers,
      'all_graded': true,
      'result': {
        'score': finalScore,
        'max_score': finalMaxScore,
        'percentage': percentage,
        'passed': passed,
        'passing_threshold': passingScore,
      },
    }).toResponse();
  }

  // Still has ungraded answers
  return ApiResponse.ok({
    'assessment_id': assessmentId,
    'graded_answers': gradedAnswers,
    'all_graded': false,
    'remaining_ungraded': ungradedCount.length,
  }).toResponse();
}

/// GET /v1/certify/assessments/:id/questions/analysis
///
/// Question-level analysis for an assessment.
/// URS §4.2.1.19: Question discrimination/difficulty metrics
Future<Response> assessmentQuestionAnalysisHandler(Request req) async {
  final assessmentId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewAssessments,
    jwtPermissions: auth.permissions,
  );

  // Get the assessment with course info
  final assessment = await supabase
      .from('assessments')
      .select('id, course_id, status')
      .eq('id', assessmentId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (assessment == null) throw NotFoundException('Assessment not found');

  // Get all answers for this assessment
  final answers = await supabase
      .from('assessment_answers')
      .select('''
        id,
        question_id,
        is_correct,
        score,
        max_score,
        time_spent_seconds,
        questions!inner (
          id,
          question_text,
          question_type,
          difficulty_level,
          topic_id,
          topics ( name )
        )
      ''')
      .eq('assessment_id', assessmentId);

  // Group answers by question for analysis
  final questionStats = <String, Map<String, dynamic>>{};

  for (final answer in answers) {
    final question = answer['questions'] as Map<String, dynamic>?;
    if (question == null) continue;

    final questionId = question['id'] as String;
    final isCorrect = answer['is_correct'] as bool? ?? false;
    final timeSpent = answer['time_spent_seconds'] as int? ?? 0;
    final score = (answer['score'] as num?)?.toDouble() ?? 0;
    final maxScore = (answer['max_score'] as num?)?.toDouble() ?? 0;

    questionStats.putIfAbsent(questionId, () => {
      'question_id': questionId,
      'question_text': question['question_text'],
      'question_type': question['question_type'],
      'difficulty_level': question['difficulty_level'],
      'topic': (question['topics'] as Map<String, dynamic>?)?['name'],
      'attempts': 0,
      'correct_count': 0,
      'total_time_seconds': 0,
      'total_score': 0.0,
      'total_max_score': 0.0,
    });

    final stats = questionStats[questionId]!;
    stats['attempts'] = (stats['attempts'] as int) + 1;
    if (isCorrect) {
      stats['correct_count'] = (stats['correct_count'] as int) + 1;
    }
    stats['total_time_seconds'] = (stats['total_time_seconds'] as int) + timeSpent;
    stats['total_score'] = (stats['total_score'] as double) + score;
    stats['total_max_score'] = (stats['total_max_score'] as double) + maxScore;
  }

  // Calculate derived metrics
  final analysisResults = questionStats.values.map((stats) {
    final attempts = stats['attempts'] as int;
    final correctCount = stats['correct_count'] as int;
    final totalTime = stats['total_time_seconds'] as int;
    final totalScore = stats['total_score'] as double;
    final totalMaxScore = stats['total_max_score'] as double;

    // Difficulty index: proportion of correct answers (0-1)
    // Lower = harder, Higher = easier
    final difficultyIndex = attempts > 0 ? correctCount / attempts : 0.0;

    // Average time per attempt
    final avgTimeSeconds = attempts > 0 ? totalTime / attempts : 0.0;

    // Score rate
    final scoreRate = totalMaxScore > 0 ? totalScore / totalMaxScore : 0.0;

    return {
      ...stats,
      'difficulty_index': difficultyIndex.toStringAsFixed(3),
      'correct_rate': (difficultyIndex * 100).toStringAsFixed(1),
      'avg_time_seconds': avgTimeSeconds.round(),
      'score_rate': (scoreRate * 100).toStringAsFixed(1),
      // Difficulty interpretation
      'difficulty_interpretation': _interpretDifficulty(difficultyIndex),
    };
  }).toList();

  // Sort by difficulty (hardest first)
  analysisResults.sort((a, b) {
    final aIndex = double.tryParse(a['difficulty_index'] as String) ?? 0;
    final bIndex = double.tryParse(b['difficulty_index'] as String) ?? 0;
    return aIndex.compareTo(bIndex);
  });

  return ApiResponse.ok({
    'assessment_id': assessmentId,
    'total_questions': analysisResults.length,
    'questions': analysisResults,
  }).toResponse();
}

String _interpretDifficulty(double index) {
  if (index < 0.3) return 'very_hard';
  if (index < 0.5) return 'hard';
  if (index < 0.7) return 'moderate';
  if (index < 0.9) return 'easy';
  return 'very_easy';
}
