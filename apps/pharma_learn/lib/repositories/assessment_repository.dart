import 'package:injectable/injectable.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';

/// Repository for assessment-related API operations.
@singleton
class AssessmentRepository {
  final ApiClient _api;
  
  AssessmentRepository(this._api);
  
  // ---------------------------------------------------------------------------
  // Available Assessments
  // ---------------------------------------------------------------------------
  
  Future<List<Assessment>> getAvailableAssessments() async {
    try {
      final response = await _api.get('/v1/certify/assessments/available');
      final data = response.data as Map<String, dynamic>;
      final assessments = data['data']?['assessments'] ?? data['assessments'] ?? [];
      return (assessments as List)
          .map((a) => Assessment.fromJson(a))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Start Attempt
  // ---------------------------------------------------------------------------
  
  Future<AssessmentAttempt> startAttempt(String assessmentId) async {
    try {
      final response = await _api.post(
        '/v1/certify/assessments/$assessmentId/start',
      );
      final data = response.data as Map<String, dynamic>;
      return AssessmentAttempt.fromJson(data['data'] ?? data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Get Questions
  // ---------------------------------------------------------------------------
  
  Future<List<Question>> getQuestions(String attemptId) async {
    try {
      final response = await _api.get(
        '/v1/certify/assessments/attempts/$attemptId/questions',
      );
      final data = response.data as Map<String, dynamic>;
      final questions = data['data']?['questions'] ?? data['questions'] ?? [];
      return (questions as List)
          .map((q) => Question.fromJson(q))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Submit Answer
  // ---------------------------------------------------------------------------
  
  Future<void> submitAnswer(
    String attemptId,
    String questionId,
    dynamic answer,
  ) async {
    try {
      await _api.post(
        '/v1/certify/assessments/attempts/$attemptId/answer',
        data: {
          'question_id': questionId,
          'answer': answer,
        },
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Submit Assessment
  // ---------------------------------------------------------------------------
  
  Future<AssessmentResult> submitAssessment(
    String attemptId, {
    required String esigPassword,
    required String meaning,
  }) async {
    try {
      final response = await _api.post(
        '/v1/certify/assessments/attempts/$attemptId/submit',
        data: {
          'esig_password': esigPassword,
          'meaning': meaning,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return AssessmentResult.fromJson(data['data'] ?? data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Get Results
  // ---------------------------------------------------------------------------
  
  Future<AssessmentResult> getResult(String attemptId) async {
    try {
      final response = await _api.get(
        '/v1/certify/assessments/attempts/$attemptId/result',
      );
      final data = response.data as Map<String, dynamic>;
      return AssessmentResult.fromJson(data['data'] ?? data);
    } catch (e) {
      throw _handleError(e);
    }
  }
  
  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------
  
  Exception _handleError(dynamic e) {
    if (e is ApiException) return e;
    return ApiException(message: e.toString());
  }
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class Assessment {
  final String id;
  final String courseId;
  final String courseTitle;
  final String title;
  final int questionCount;
  final int timeLimit; // minutes
  final double passingScore;
  final int maxAttempts;
  final int attemptsTaken;
  final bool canAttempt;
  
  Assessment({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.title,
    required this.questionCount,
    required this.timeLimit,
    required this.passingScore,
    required this.maxAttempts,
    required this.attemptsTaken,
    required this.canAttempt,
  });
  
  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: json['id'],
      courseId: json['course_id'],
      courseTitle: json['course_title'] ?? json['courses']?['title'] ?? '',
      title: json['title'] ?? 'Assessment',
      questionCount: json['question_count'] ?? 0,
      timeLimit: json['time_limit'] ?? 60,
      passingScore: (json['passing_score'] as num?)?.toDouble() ?? 70.0,
      maxAttempts: json['max_attempts'] ?? 3,
      attemptsTaken: json['attempts_taken'] ?? 0,
      canAttempt: json['can_attempt'] ?? true,
    );
  }
}

class AssessmentAttempt {
  final String id;
  final String assessmentId;
  final int attemptNumber;
  final DateTime startedAt;
  final DateTime? endsAt;
  final String status;
  
  AssessmentAttempt({
    required this.id,
    required this.assessmentId,
    required this.attemptNumber,
    required this.startedAt,
    this.endsAt,
    required this.status,
  });
  
  factory AssessmentAttempt.fromJson(Map<String, dynamic> json) {
    return AssessmentAttempt(
      id: json['id'],
      assessmentId: json['assessment_id'],
      attemptNumber: json['attempt_number'] ?? 1,
      startedAt: DateTime.parse(json['started_at']),
      endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at']) : null,
      status: json['status'] ?? 'in_progress',
    );
  }
  
  Duration? get remainingTime {
    if (endsAt == null) return null;
    final remaining = endsAt!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class Question {
  final String id;
  final int order;
  final String type;
  final String text;
  final List<QuestionOption>? options;
  final dynamic currentAnswer;
  final bool isAnswered;
  
  Question({
    required this.id,
    required this.order,
    required this.type,
    required this.text,
    this.options,
    this.currentAnswer,
    required this.isAnswered,
  });
  
  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      order: json['order'] ?? 0,
      type: json['type'] ?? 'single_choice',
      text: json['text'] ?? json['question_text'] ?? '',
      options: (json['options'] as List?)
          ?.map((o) => QuestionOption.fromJson(o))
          .toList(),
      currentAnswer: json['current_answer'],
      isAnswered: json['is_answered'] ?? false,
    );
  }
}

class QuestionOption {
  final String id;
  final String text;
  final int order;
  
  QuestionOption({
    required this.id,
    required this.text,
    required this.order,
  });
  
  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    return QuestionOption(
      id: json['id'],
      text: json['text'] ?? json['option_text'] ?? '',
      order: json['order'] ?? 0,
    );
  }
}

class AssessmentResult {
  final String attemptId;
  final double score;
  final double passingScore;
  final bool passed;
  final int correctCount;
  final int totalCount;
  final DateTime completedAt;
  final String? certificateId;
  
  AssessmentResult({
    required this.attemptId,
    required this.score,
    required this.passingScore,
    required this.passed,
    required this.correctCount,
    required this.totalCount,
    required this.completedAt,
    this.certificateId,
  });
  
  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    return AssessmentResult(
      attemptId: json['attempt_id'] ?? json['id'],
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      passingScore: (json['passing_score'] as num?)?.toDouble() ?? 70.0,
      passed: json['passed'] ?? false,
      correctCount: json['correct_count'] ?? 0,
      totalCount: json['total_count'] ?? 0,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at']) 
          : DateTime.now(),
      certificateId: json['certificate_id'],
    );
  }
}
