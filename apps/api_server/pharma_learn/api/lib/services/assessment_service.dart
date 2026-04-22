import 'dart:math';

import 'package:supabase/supabase.dart';

/// Service for assessment grading and adaptive question selection.
/// 
/// Provides:
/// - Auto-grading for MCQ, True/False, and fill-in-blank questions
/// - Manual grading queue management
/// - Adaptive question selection based on difficulty and performance
/// - Score calculation with weighting
class AssessmentService {
  final SupabaseClient _supabase;
  final Random _random = Random();

  AssessmentService(this._supabase);

  // ---------------------------------------------------------------------------
  // Auto-Grading
  // ---------------------------------------------------------------------------

  /// Auto-grades an assessment attempt for questions that can be auto-graded.
  /// 
  /// Returns:
  /// - totalScore: Sum of points earned
  /// - totalPossible: Sum of possible points for auto-gradable questions
  /// - pendingManualGrading: Number of questions requiring manual grading
  /// - questionResults: Per-question results
  Future<Map<String, dynamic>> autoGradeAttempt(String attemptId) async {
    // 1. Get attempt with responses
    final attempt = await _supabase
        .from('assessment_attempts')
        .select('''
          id,
          assessment_id,
          employee_id,
          assessment:assessments(question_paper_id),
          responses:assessment_responses(
            id,
            question_id,
            answer_data,
            question:questions(
              id,
              question_type,
              correct_answer,
              options,
              points,
              grading_rubric
            )
          )
        ''')
        .eq('id', attemptId)
        .single();

    final responses = attempt['responses'] as List;
    double totalScore = 0;
    double totalPossible = 0;
    int pendingManualGrading = 0;
    final questionResults = <Map<String, dynamic>>[];

    for (final response in responses) {
      final question = response['question'] as Map<String, dynamic>;
      final questionType = question['question_type'] as String;
      final points = (question['points'] as num?)?.toDouble() ?? 1.0;
      final answerData = response['answer_data'] as Map<String, dynamic>?;

      Map<String, dynamic> result;

      switch (questionType) {
        case 'mcq':
        case 'mcq_single':
          result = _gradeMcqSingle(question, answerData, points);
          break;
        case 'mcq_multiple':
          result = _gradeMcqMultiple(question, answerData, points);
          break;
        case 'true_false':
          result = _gradeTrueFalse(question, answerData, points);
          break;
        case 'fill_blank':
        case 'fill_in_blank':
          result = _gradeFillBlank(question, answerData, points);
          break;
        case 'short_answer':
        case 'essay':
        case 'descriptive':
          // Requires manual grading
          result = {
            'autoGraded': false,
            'requiresManualGrading': true,
            'pointsEarned': 0,
            'pointsPossible': points,
          };
          pendingManualGrading++;
          break;
        default:
          result = {
            'autoGraded': false,
            'error': 'Unknown question type: $questionType',
            'pointsEarned': 0,
            'pointsPossible': points,
          };
      }

      // Update response with grading result
      await _supabase
          .from('assessment_responses')
          .update({
            'is_correct': result['isCorrect'],
            'points_earned': result['pointsEarned'],
            'auto_graded': result['autoGraded'] ?? true,
            'graded_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', response['id']);

      if (result['autoGraded'] == true) {
        totalScore += (result['pointsEarned'] as num?)?.toDouble() ?? 0;
        totalPossible += points;
      }

      questionResults.add({
        'question_id': question['id'],
        'response_id': response['id'],
        ...result,
      });
    }

    // 2. Calculate percentage
    final percentage = totalPossible > 0 ? (totalScore / totalPossible) * 100 : 0;

    // 3. Update attempt with preliminary score
    await _supabase
        .from('assessment_attempts')
        .update({
          'score': totalScore,
          'percentage': percentage,
          'auto_graded_at': DateTime.now().toUtc().toIso8601String(),
          'pending_manual_grading': pendingManualGrading > 0,
        })
        .eq('id', attemptId);

    // 4. If manual grading needed, add to grading queue
    if (pendingManualGrading > 0) {
      await _supabase.from('grading_queue').upsert({
        'attempt_id': attemptId,
        'status': 'pending',
        'questions_pending': pendingManualGrading,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'attempt_id');
    }

    return {
      'attemptId': attemptId,
      'totalScore': totalScore,
      'totalPossible': totalPossible,
      'percentage': percentage,
      'pendingManualGrading': pendingManualGrading,
      'questionResults': questionResults,
    };
  }

  /// Grade single-choice MCQ
  Map<String, dynamic> _gradeMcqSingle(
    Map<String, dynamic> question,
    Map<String, dynamic>? answerData,
    double points,
  ) {
    final correctAnswer = question['correct_answer'];
    final selectedAnswer = answerData?['selected'] ?? answerData?['answer'];

    final isCorrect = correctAnswer != null && 
                      selectedAnswer != null && 
                      correctAnswer.toString() == selectedAnswer.toString();

    return {
      'autoGraded': true,
      'isCorrect': isCorrect,
      'pointsEarned': isCorrect ? points : 0,
      'pointsPossible': points,
      'correctAnswer': correctAnswer,
      'selectedAnswer': selectedAnswer,
    };
  }

  /// Grade multiple-choice MCQ (partial credit)
  Map<String, dynamic> _gradeMcqMultiple(
    Map<String, dynamic> question,
    Map<String, dynamic>? answerData,
    double points,
  ) {
    final correctAnswers = _toStringSet(question['correct_answer']);
    final selectedAnswers = _toStringSet(answerData?['selected'] ?? answerData?['answers']);

    if (correctAnswers.isEmpty) {
      return {
        'autoGraded': true,
        'isCorrect': false,
        'pointsEarned': 0,
        'pointsPossible': points,
        'error': 'No correct answer defined',
      };
    }

    // Calculate partial credit
    final correctSelected = selectedAnswers.intersection(correctAnswers).length;
    final incorrectSelected = selectedAnswers.difference(correctAnswers).length;
    final totalCorrect = correctAnswers.length;

    // Formula: (correct - incorrect) / total, minimum 0
    final score = max(0, correctSelected - incorrectSelected) / totalCorrect;
    final pointsEarned = score * points;
    final isCorrect = selectedAnswers.length == correctAnswers.length &&
                      selectedAnswers.containsAll(correctAnswers);

    return {
      'autoGraded': true,
      'isCorrect': isCorrect,
      'pointsEarned': pointsEarned,
      'pointsPossible': points,
      'correctAnswers': correctAnswers.toList(),
      'selectedAnswers': selectedAnswers.toList(),
      'partialCredit': score,
    };
  }

  /// Grade True/False question
  Map<String, dynamic> _gradeTrueFalse(
    Map<String, dynamic> question,
    Map<String, dynamic>? answerData,
    double points,
  ) {
    final correctAnswer = question['correct_answer']?.toString().toLowerCase();
    final selectedAnswer = (answerData?['selected'] ?? answerData?['answer'])?.toString().toLowerCase();

    final normalizedCorrect = _normalizeTrueFalse(correctAnswer);
    final normalizedSelected = _normalizeTrueFalse(selectedAnswer);

    final isCorrect = normalizedCorrect != null && 
                      normalizedSelected != null &&
                      normalizedCorrect == normalizedSelected;

    return {
      'autoGraded': true,
      'isCorrect': isCorrect,
      'pointsEarned': isCorrect ? points : 0,
      'pointsPossible': points,
    };
  }

  /// Grade fill-in-the-blank question
  Map<String, dynamic> _gradeFillBlank(
    Map<String, dynamic> question,
    Map<String, dynamic>? answerData,
    double points,
  ) {
    final correctAnswer = question['correct_answer'];
    final userAnswer = answerData?['answer']?.toString().trim().toLowerCase();

    if (correctAnswer == null || userAnswer == null) {
      return {
        'autoGraded': true,
        'isCorrect': false,
        'pointsEarned': 0,
        'pointsPossible': points,
      };
    }

    // Support multiple acceptable answers
    final acceptableAnswers = <String>[];
    if (correctAnswer is List) {
      acceptableAnswers.addAll(correctAnswer.map((a) => a.toString().trim().toLowerCase()));
    } else {
      acceptableAnswers.add(correctAnswer.toString().trim().toLowerCase());
    }

    final isCorrect = acceptableAnswers.contains(userAnswer);

    return {
      'autoGraded': true,
      'isCorrect': isCorrect,
      'pointsEarned': isCorrect ? points : 0,
      'pointsPossible': points,
    };
  }

  Set<String> _toStringSet(dynamic value) {
    if (value == null) return {};
    if (value is List) return value.map((e) => e.toString()).toSet();
    if (value is Set) return value.map((e) => e.toString()).toSet();
    return {value.toString()};
  }

  bool? _normalizeTrueFalse(String? value) {
    if (value == null) return null;
    if (['true', 't', 'yes', 'y', '1'].contains(value)) return true;
    if (['false', 'f', 'no', 'n', '0'].contains(value)) return false;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Manual Grading Queue
  // ---------------------------------------------------------------------------

  /// Gets the grading queue with filters.
  Future<List<Map<String, dynamic>>> getGradingQueue({
    String? status,
    String? assignedTo,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _supabase.from('grading_queue').select('''
          *,
          attempt:assessment_attempts(
            id,
            employee:employees(id, full_name, employee_number),
            assessment:assessments(id, name)
          )
        ''');

    if (status != null) {
      query = query.eq('status', status);
    }
    if (assignedTo != null) {
      query = query.eq('assigned_to', assignedTo);
    }

    return await query
        .order('created_at', ascending: true)
        .range(offset, offset + limit - 1);
  }

  /// Assigns a grading queue item to a grader.
  Future<Map<String, dynamic>> assignGrader({
    required String queueId,
    required String graderId,
  }) async {
    final updated = await _supabase
        .from('grading_queue')
        .update({
          'assigned_to': graderId,
          'assigned_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'assigned',
        })
        .eq('id', queueId)
        .select()
        .single();

    return updated;
  }

  /// Submits a manual grade for a response.
  Future<Map<String, dynamic>> submitManualGrade({
    required String responseId,
    required String graderId,
    required double pointsEarned,
    String? feedback,
    Map<String, dynamic>? rubricScores,
  }) async {
    // 1. Update response
    final response = await _supabase
        .from('assessment_responses')
        .update({
          'points_earned': pointsEarned,
          'grader_id': graderId,
          'grader_feedback': feedback,
          'rubric_scores': rubricScores,
          'auto_graded': false,
          'graded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', responseId)
        .select('attempt_id')
        .single();

    final attemptId = response['attempt_id'];

    // 2. Check if all responses are graded
    final pendingCount = await _supabase
        .from('assessment_responses')
        .select('id')
        .eq('attempt_id', attemptId)
        .isFilter('graded_at', null)
        .count();

    // 3. If all graded, update attempt and queue
    if (pendingCount.count == 0) {
      await _recalculateAttemptScore(attemptId);
      
      await _supabase
          .from('grading_queue')
          .update({
            'status': 'completed',
            'completed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('attempt_id', attemptId);
    }

    return {'responseId': responseId, 'pointsEarned': pointsEarned};
  }

  /// Recalculates the total score for an attempt after manual grading.
  Future<void> _recalculateAttemptScore(String attemptId) async {
    final responses = await _supabase
        .from('assessment_responses')
        .select('points_earned, question:questions(points)')
        .eq('attempt_id', attemptId);

    double totalScore = 0;
    double totalPossible = 0;

    for (final r in responses) {
      totalScore += (r['points_earned'] as num?)?.toDouble() ?? 0;
      final question = r['question'] as Map<String, dynamic>?;
      totalPossible += (question?['points'] as num?)?.toDouble() ?? 1;
    }

    final percentage = totalPossible > 0 ? (totalScore / totalPossible) * 100 : 0;

    await _supabase
        .from('assessment_attempts')
        .update({
          'score': totalScore,
          'percentage': percentage,
          'pending_manual_grading': false,
          'graded_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', attemptId);
  }

  // ---------------------------------------------------------------------------
  // Adaptive Question Selection
  // ---------------------------------------------------------------------------

  /// Selects questions adaptively based on:
  /// - Target difficulty distribution
  /// - Candidate's previous performance
  /// - Question bank coverage
  Future<List<Map<String, dynamic>>> selectQuestionsAdaptively({
    required String questionBankId,
    required int count,
    String? employeeId,
    Map<String, double>? difficultyDistribution,
  }) async {
    // Default distribution if not specified
    final distribution = difficultyDistribution ?? {
      'easy': 0.3,
      'medium': 0.5,
      'hard': 0.2,
    };

    // 1. Get all questions from the bank
    final allQuestions = await _supabase
        .from('questions')
        .select('id, difficulty_level, topic, question_type, times_used, avg_score')
        .eq('question_bank_id', questionBankId)
        .eq('status', 'active');

    if (allQuestions.isEmpty) {
      return [];
    }

    // 2. Calculate target counts per difficulty
    final targetCounts = <String, int>{};
    for (final entry in distribution.entries) {
      targetCounts[entry.key] = (count * entry.value).round();
    }

    // 3. Adjust for performance if employee provided
    if (employeeId != null) {
      final performance = await _getEmployeePerformance(employeeId, questionBankId);
      if (performance['avgScore'] != null && performance['avgScore'] < 50) {
        // Struggling: more easy questions
        targetCounts['easy'] = (count * 0.4).round();
        targetCounts['medium'] = (count * 0.4).round();
        targetCounts['hard'] = (count * 0.2).round();
      } else if (performance['avgScore'] != null && performance['avgScore'] > 80) {
        // Excelling: more hard questions
        targetCounts['easy'] = (count * 0.2).round();
        targetCounts['medium'] = (count * 0.4).round();
        targetCounts['hard'] = (count * 0.4).round();
      }
    }

    // 4. Select questions by difficulty
    final selected = <Map<String, dynamic>>[];
    final groupedByDifficulty = <String, List<Map<String, dynamic>>>{};

    for (final q in allQuestions) {
      final difficulty = (q['difficulty_level'] as String?) ?? 'medium';
      groupedByDifficulty.putIfAbsent(difficulty, () => []).add(q);
    }

    for (final entry in targetCounts.entries) {
      final difficulty = entry.key;
      final targetCount = entry.value;
      final available = groupedByDifficulty[difficulty] ?? [];

      // Sort by least used first (for coverage)
      available.sort((a, b) => 
        ((a['times_used'] as int?) ?? 0).compareTo((b['times_used'] as int?) ?? 0));

      final toSelect = min(targetCount, available.length);
      selected.addAll(available.take(toSelect));
    }

    // 5. Fill remaining slots if needed
    final remaining = count - selected.length;
    if (remaining > 0) {
      final usedIds = selected.map((q) => q['id']).toSet();
      final unused = allQuestions.where((q) => !usedIds.contains(q['id'])).toList();
      unused.shuffle(_random);
      selected.addAll(unused.take(remaining));
    }

    // 6. Shuffle final selection
    selected.shuffle(_random);

    return selected.take(count).toList();
  }

  Future<Map<String, dynamic>> _getEmployeePerformance(
    String employeeId,
    String questionBankId,
  ) async {
    final result = await _supabase.rpc('get_employee_bank_performance', params: {
      'p_employee_id': employeeId,
      'p_question_bank_id': questionBankId,
    });

    if (result is List && result.isNotEmpty) {
      return result[0] as Map<String, dynamic>;
    }

    return {};
  }
}
