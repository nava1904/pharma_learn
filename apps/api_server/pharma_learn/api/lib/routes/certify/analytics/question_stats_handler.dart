import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/certify/analytics/questions/:id
///
/// Question-level statistics: discrimination index, difficulty index.
/// Analyzes question performance across all assessments.
Future<Response> questionStatsHandler(Request req) async {
  final questionId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  // Get question details
  final question = await supabase
      .from('questions')
      .select('''
        id, question_text, question_type, difficulty_level, points,
        topics ( id, name ),
        courses ( id, name, course_code )
      ''')
      .eq('id', questionId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (question == null) throw NotFoundException('Question not found');

  // Get all answers for this question
  final answers = await supabase
      .from('assessment_answers')
      .select('''
        id, is_correct, score, max_score, time_spent_seconds,
        assessments!inner ( id, percentage, status )
      ''')
      .eq('question_id', questionId);

  if (answers.isEmpty) {
    return ApiResponse.ok({
      'question': {
        'id': question['id'],
        'text': question['question_text'],
        'type': question['question_type'],
        'stated_difficulty': question['difficulty_level'],
        'points': question['points'],
        'topic': question['topics'],
        'course': question['courses'],
      },
      'statistics': {
        'total_attempts': 0,
        'message': 'No attempts recorded for this question',
      },
    }).toResponse();
  }

  // Calculate basic stats
  final totalAttempts = answers.length;
  final correctCount = answers.where((a) => a['is_correct'] == true).length;
  
  // Difficulty Index (P): proportion of correct answers
  // P = correct / total (0 to 1, higher = easier)
  final difficultyIndex = correctCount / totalAttempts;

  // For discrimination index, we need to compare high performers vs low performers
  // Group by assessment performance
  final highPerformers = <Map<String, dynamic>>[]; // Top 27%
  final lowPerformers = <Map<String, dynamic>>[];  // Bottom 27%

  // Sort answers by assessment percentage
  final sortedAnswers = List<Map<String, dynamic>>.from(answers);
  sortedAnswers.sort((a, b) {
    final aPercent = (a['assessments'] as Map?)?['percentage'] as num? ?? 0;
    final bPercent = (b['assessments'] as Map?)?['percentage'] as num? ?? 0;
    return bPercent.compareTo(aPercent);
  });

  final cutoff = (totalAttempts * 0.27).ceil();
  if (cutoff > 0) {
    highPerformers.addAll(sortedAnswers.take(cutoff));
    lowPerformers.addAll(sortedAnswers.reversed.take(cutoff));
  }

  // Discrimination Index (D): difference between high and low performer success rates
  // D = (high correct / high total) - (low correct / low total)
  // Range: -1 to +1, higher = better discrimination
  double discriminationIndex = 0.0;
  if (highPerformers.isNotEmpty && lowPerformers.isNotEmpty) {
    final highCorrect = highPerformers.where((a) => a['is_correct'] == true).length;
    final lowCorrect = lowPerformers.where((a) => a['is_correct'] == true).length;
    discriminationIndex = (highCorrect / highPerformers.length) - 
                          (lowCorrect / lowPerformers.length);
  }

  // Average time spent
  var totalTimeSeconds = 0;
  var timeCount = 0;
  for (final answer in answers) {
    final time = answer['time_spent_seconds'] as int?;
    if (time != null && time > 0) {
      totalTimeSeconds += time;
      timeCount++;
    }
  }
  final avgTimeSeconds = timeCount > 0 ? (totalTimeSeconds / timeCount).round() : 0;

  // Score analysis (for partial credit questions)
  var totalScore = 0.0;
  var totalMaxScore = 0.0;
  for (final answer in answers) {
    totalScore += (answer['score'] as num?)?.toDouble() ?? 0;
    totalMaxScore += (answer['max_score'] as num?)?.toDouble() ?? 0;
  }
  final avgScorePercent = totalMaxScore > 0 
      ? (totalScore / totalMaxScore * 100).toStringAsFixed(1) 
      : '0.0';

  // Interpret metrics
  final difficultyInterpretation = _interpretDifficulty(difficultyIndex);
  final discriminationInterpretation = _interpretDiscrimination(discriminationIndex);
  final qualityAssessment = _assessQuestionQuality(
    difficultyIndex, 
    discriminationIndex,
  );

  return ApiResponse.ok({
    'question': {
      'id': question['id'],
      'text': question['question_text'],
      'type': question['question_type'],
      'stated_difficulty': question['difficulty_level'],
      'points': question['points'],
      'topic': question['topics'],
      'course': question['courses'],
    },
    'statistics': {
      'total_attempts': totalAttempts,
      'correct_count': correctCount,
      'incorrect_count': totalAttempts - correctCount,
      'correct_rate_percent': (difficultyIndex * 100).toStringAsFixed(1),
      'avg_time_seconds': avgTimeSeconds,
      'avg_score_percent': avgScorePercent,
    },
    'psychometrics': {
      'difficulty_index': difficultyIndex.toStringAsFixed(3),
      'difficulty_interpretation': difficultyInterpretation,
      'discrimination_index': discriminationIndex.toStringAsFixed(3),
      'discrimination_interpretation': discriminationInterpretation,
      'quality_assessment': qualityAssessment,
    },
    'recommendations': _generateRecommendations(
      difficultyIndex, 
      discriminationIndex,
    ),
  }).toResponse();
}

/// GET /v1/certify/analytics/questions
///
/// List questions with psychometric stats for a course or question bank.
Future<Response> questionsStatsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  final courseId = req.url.queryParameters['course_id'];
  final questionBankId = req.url.queryParameters['question_bank_id'];
  final minAttempts = int.tryParse(
    req.url.queryParameters['min_attempts'] ?? '10',
  ) ?? 10;

  if (courseId == null && questionBankId == null) {
    throw ValidationException({
      'filter': 'Either course_id or question_bank_id is required',
    });
  }

  // Get questions
  var questionsQuery = supabase
      .from('questions')
      .select('id, question_text, question_type, difficulty_level, points')
      .eq('organization_id', auth.orgId);

  if (courseId != null) {
    questionsQuery = questionsQuery.eq('course_id', courseId);
  }
  if (questionBankId != null) {
    questionsQuery = questionsQuery.eq('question_bank_id', questionBankId);
  }

  final questions = await questionsQuery;

  // Calculate stats for each question
  final questionStats = <Map<String, dynamic>>[];

  for (final question in questions) {
    final questionId = question['id'] as String;

    // Get answer stats
    final answers = await supabase
        .from('assessment_answers')
        .select('is_correct')
        .eq('question_id', questionId);

    final totalAttempts = answers.length;
    if (totalAttempts < minAttempts) continue; // Skip questions with few attempts

    final correctCount = answers.where((a) => a['is_correct'] == true).length;
    final difficultyIndex = correctCount / totalAttempts;

    questionStats.add({
      'id': question['id'],
      'question_text': (question['question_text'] as String?)?.substring(
        0, 
        (question['question_text'] as String?)?.length.clamp(0, 100) ?? 0,
      ),
      'type': question['question_type'],
      'stated_difficulty': question['difficulty_level'],
      'points': question['points'],
      'total_attempts': totalAttempts,
      'correct_count': correctCount,
      'difficulty_index': difficultyIndex.toStringAsFixed(3),
      'difficulty_interpretation': _interpretDifficulty(difficultyIndex),
    });
  }

  // Sort by difficulty (hardest first)
  questionStats.sort((a, b) {
    final aIndex = double.tryParse(a['difficulty_index'] as String) ?? 0;
    final bIndex = double.tryParse(b['difficulty_index'] as String) ?? 0;
    return aIndex.compareTo(bIndex);
  });

  return ApiResponse.ok({
    'questions': questionStats,
    'filter': {
      'course_id': courseId,
      'question_bank_id': questionBankId,
      'min_attempts': minAttempts,
    },
    'total': questionStats.length,
  }).toResponse();
}

String _interpretDifficulty(double index) {
  if (index < 0.3) return 'very_hard';
  if (index < 0.5) return 'hard';
  if (index < 0.7) return 'moderate';
  if (index < 0.9) return 'easy';
  return 'very_easy';
}

String _interpretDiscrimination(double index) {
  if (index >= 0.4) return 'excellent';
  if (index >= 0.3) return 'good';
  if (index >= 0.2) return 'acceptable';
  if (index >= 0.1) return 'poor';
  return 'needs_review';
}

String _assessQuestionQuality(double difficulty, double discrimination) {
  // Ideal: moderate difficulty (0.3-0.7) + good discrimination (>0.3)
  if (difficulty >= 0.3 && difficulty <= 0.7 && discrimination >= 0.3) {
    return 'excellent';
  }
  if (difficulty >= 0.2 && difficulty <= 0.8 && discrimination >= 0.2) {
    return 'good';
  }
  if (discrimination < 0.1) {
    return 'poor_discrimination';
  }
  if (difficulty < 0.2) {
    return 'too_hard';
  }
  if (difficulty > 0.9) {
    return 'too_easy';
  }
  return 'acceptable';
}

List<String> _generateRecommendations(double difficulty, double discrimination) {
  final recommendations = <String>[];

  if (difficulty < 0.2) {
    recommendations.add('Question is very difficult. Consider simplifying or providing additional context.');
  }
  if (difficulty > 0.9) {
    recommendations.add('Question is too easy. Consider increasing complexity or removing as it doesn\'t differentiate learners.');
  }
  if (discrimination < 0.1) {
    recommendations.add('Poor discrimination. Review question clarity, distractors, and answer key accuracy.');
  }
  if (discrimination < 0) {
    recommendations.add('CRITICAL: Negative discrimination suggests the question may have an incorrect answer key or is misleading high performers.');
  }
  if (recommendations.isEmpty) {
    recommendations.add('Question performs well psychometrically. No changes recommended.');
  }

  return recommendations;
}
