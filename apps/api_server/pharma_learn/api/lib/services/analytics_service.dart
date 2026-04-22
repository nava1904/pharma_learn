import 'package:supabase/supabase.dart';

/// Service for centralized analytics and metric aggregation.
/// 
/// Provides:
/// - Training completion metrics
/// - Assessment performance analytics
/// - Compliance dashboard data
/// - Trend analysis
class AnalyticsService {
  final SupabaseClient _supabase;

  AnalyticsService(this._supabase);

  // ---------------------------------------------------------------------------
  // Training Analytics
  // ---------------------------------------------------------------------------

  /// Gets training completion metrics for an organization.
  Future<Map<String, dynamic>> getTrainingMetrics({
    required String orgId,
    String? departmentId,
    String? courseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final params = <String, dynamic>{
      'p_org_id': orgId,
      if (departmentId != null) 'p_department_id': departmentId,
      if (courseId != null) 'p_course_id': courseId,
      if (startDate != null) 'p_start_date': startDate.toIso8601String(),
      if (endDate != null) 'p_end_date': endDate.toIso8601String(),
    };

    // Try RPC first, fall back to direct queries
    try {
      final result = await _supabase.rpc('get_training_metrics', params: params);
      if (result is List && result.isNotEmpty) {
        return result[0] as Map<String, dynamic>;
      }
    } catch (_) {
      // Fall back to direct calculation
    }

    return await _calculateTrainingMetrics(
      orgId: orgId,
      departmentId: departmentId,
      courseId: courseId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<Map<String, dynamic>> _calculateTrainingMetrics({
    required String orgId,
    String? departmentId,
    String? courseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Total obligations
    var obligationsQuery = _supabase
        .from('employee_training_obligations')
        .select('id, status, due_date, completed_at')
        .eq('organization_id', orgId);

    if (departmentId != null) {
      obligationsQuery = obligationsQuery.eq('department_id', departmentId);
    }
    if (courseId != null) {
      obligationsQuery = obligationsQuery.eq('course_id', courseId);
    }

    final obligations = await obligationsQuery;

    int total = obligations.length;
    int completed = 0;
    int overdue = 0;
    int inProgress = 0;
    int notStarted = 0;

    final now = DateTime.now();

    for (final o in obligations) {
      final status = o['status'] as String?;
      final dueDate = o['due_date'] != null ? DateTime.parse(o['due_date']) : null;

      if (status == 'completed' || status == 'passed') {
        completed++;
      } else if (dueDate != null && dueDate.isBefore(now)) {
        overdue++;
      } else if (status == 'in_progress') {
        inProgress++;
      } else {
        notStarted++;
      }
    }

    final completionRate = total > 0 ? (completed / total) * 100 : 0;

    return {
      'total_obligations': total,
      'completed': completed,
      'overdue': overdue,
      'in_progress': inProgress,
      'not_started': notStarted,
      'completion_rate': completionRate,
      'compliance_percentage': completionRate,
    };
  }

  /// Gets training trends over time.
  Future<List<Map<String, dynamic>>> getTrainingTrends({
    required String orgId,
    required String period, // 'daily', 'weekly', 'monthly'
    int intervals = 12,
  }) async {
    final now = DateTime.now();
    final trends = <Map<String, dynamic>>[];

    for (int i = intervals - 1; i >= 0; i--) {
      DateTime periodStart;
      DateTime periodEnd;

      switch (period) {
        case 'daily':
          periodStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
          periodEnd = periodStart.add(const Duration(days: 1));
          break;
        case 'weekly':
          periodStart = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - 1 + (i * 7)));
          periodEnd = periodStart.add(const Duration(days: 7));
          break;
        case 'monthly':
        default:
          periodStart = DateTime(now.year, now.month - i, 1);
          periodEnd = DateTime(now.year, now.month - i + 1, 1);
      }

      final completions = await _supabase
          .from('training_records')
          .select('id')
          .eq('organization_id', orgId)
          .gte('completed_at', periodStart.toIso8601String())
          .lt('completed_at', periodEnd.toIso8601String())
          .count();

      trends.add({
        'period': periodStart.toIso8601String().substring(0, 10),
        'completions': completions.count,
      });
    }

    return trends;
  }

  // ---------------------------------------------------------------------------
  // Assessment Analytics
  // ---------------------------------------------------------------------------

  /// Gets assessment performance metrics.
  Future<Map<String, dynamic>> getAssessmentMetrics({
    required String orgId,
    String? assessmentId,
    String? courseId,
  }) async {
    var query = _supabase
        .from('assessment_attempts')
        .select('id, score, percentage, status, passed')
        .eq('organization_id', orgId);

    if (assessmentId != null) {
      query = query.eq('assessment_id', assessmentId);
    }

    final attempts = await query;

    if (attempts.isEmpty) {
      return {
        'total_attempts': 0,
        'pass_rate': 0,
        'average_score': 0,
        'highest_score': 0,
        'lowest_score': 0,
      };
    }

    int totalAttempts = attempts.length;
    int passed = 0;
    double totalScore = 0;
    double highest = 0;
    double lowest = 100;

    for (final a in attempts) {
      final score = (a['percentage'] as num?)?.toDouble() ?? 0;
      if (a['passed'] == true) passed++;
      totalScore += score;
      if (score > highest) highest = score;
      if (score < lowest) lowest = score;
    }

    return {
      'total_attempts': totalAttempts,
      'pass_rate': (passed / totalAttempts) * 100,
      'average_score': totalScore / totalAttempts,
      'highest_score': highest,
      'lowest_score': lowest,
      'passed_count': passed,
      'failed_count': totalAttempts - passed,
    };
  }

  /// Gets question-level analytics for an assessment.
  Future<List<Map<String, dynamic>>> getQuestionAnalytics({
    required String assessmentId,
  }) async {
    final responses = await _supabase
        .from('assessment_responses')
        .select('''
          question_id,
          is_correct,
          points_earned,
          question:questions(
            id,
            question_text,
            difficulty_level,
            points
          )
        ''')
        .eq('assessment_id', assessmentId);

    // Group by question
    final byQuestion = <String, List<Map<String, dynamic>>>{};
    for (final r in responses) {
      final questionId = r['question_id'] as String;
      byQuestion.putIfAbsent(questionId, () => []).add(r);
    }

    final analytics = <Map<String, dynamic>>[];

    for (final entry in byQuestion.entries) {
      final questionResponses = entry.value;
      final question = questionResponses.first['question'] as Map<String, dynamic>?;

      int correct = 0;
      double totalPoints = 0;
      final maxPoints = (question?['points'] as num?)?.toDouble() ?? 1;

      for (final r in questionResponses) {
        if (r['is_correct'] == true) correct++;
        totalPoints += (r['points_earned'] as num?)?.toDouble() ?? 0;
      }

      final attemptCount = questionResponses.length;
      final correctRate = attemptCount > 0 ? (correct / attemptCount) * 100 : 0;
      final avgPoints = attemptCount > 0 ? totalPoints / attemptCount : 0;
      final discriminationIndex = _calculateDiscrimination(questionResponses);

      analytics.add({
        'question_id': entry.key,
        'question_text': question?['question_text'],
        'difficulty_level': question?['difficulty_level'],
        'attempt_count': attemptCount,
        'correct_count': correct,
        'correct_rate': correctRate,
        'average_points': avgPoints,
        'max_points': maxPoints,
        'discrimination_index': discriminationIndex,
        'needs_review': correctRate < 30 || correctRate > 95,
      });
    }

    // Sort by correct rate (lowest first - problematic questions)
    analytics.sort((a, b) => 
        (a['correct_rate'] as double).compareTo(b['correct_rate'] as double));

    return analytics;
  }

  /// Calculates discrimination index for a question.
  /// Measures how well the question differentiates between high and low performers.
  double _calculateDiscrimination(List<Map<String, dynamic>> responses) {
    if (responses.length < 10) return 0; // Not enough data

    // Sort by total score (would need attempt data for this)
    // Simplified version: just use the correct rate difference
    final correctCount = responses.where((r) => r['is_correct'] == true).length;
    final incorrectCount = responses.length - correctCount;

    if (incorrectCount == 0) return 1.0;
    if (correctCount == 0) return -1.0;

    return (correctCount - incorrectCount) / responses.length;
  }

  // ---------------------------------------------------------------------------
  // Compliance Analytics
  // ---------------------------------------------------------------------------

  /// Gets compliance metrics by department.
  Future<List<Map<String, dynamic>>> getComplianceByDepartment({
    required String orgId,
  }) async {
    final departments = await _supabase
        .from('departments')
        .select('id, name')
        .eq('organization_id', orgId);

    final results = <Map<String, dynamic>>[];

    for (final dept in departments) {
      final deptId = dept['id'] as String;

      final metrics = await _calculateTrainingMetrics(
        orgId: orgId,
        departmentId: deptId,
      );

      results.add({
        'department_id': deptId,
        'department_name': dept['name'],
        'total_employees': await _getDepartmentEmployeeCount(deptId),
        'compliance_percentage': metrics['compliance_percentage'],
        'overdue_count': metrics['overdue'],
        'completed_count': metrics['completed'],
      });
    }

    // Sort by compliance (lowest first)
    results.sort((a, b) => 
        (a['compliance_percentage'] as num).compareTo(b['compliance_percentage'] as num));

    return results;
  }

  Future<int> _getDepartmentEmployeeCount(String departmentId) async {
    final result = await _supabase
        .from('employees')
        .select('id')
        .eq('department_id', departmentId)
        .eq('status', 'active')
        .count();

    return result.count;
  }

  /// Gets compliance metrics by role.
  Future<List<Map<String, dynamic>>> getComplianceByRole({
    required String orgId,
    String? departmentId,
  }) async {
    var rolesQuery = _supabase
        .from('job_roles')
        .select('id, name')
        .eq('organization_id', orgId);

    final roles = await rolesQuery;
    final results = <Map<String, dynamic>>[];

    for (final role in roles) {
      final roleId = role['id'] as String;

      // Get employees with this role
      var empQuery = _supabase
          .from('employees')
          .select('id')
          .eq('job_role_id', roleId)
          .eq('status', 'active');

      if (departmentId != null) {
        empQuery = empQuery.eq('department_id', departmentId);
      }

      final employees = await empQuery;
      final employeeIds = employees.map((e) => e['id'] as String).toList();

      if (employeeIds.isEmpty) continue;

      // Get obligations for these employees
      final obligations = await _supabase
          .from('employee_training_obligations')
          .select('id, status, due_date')
          .inFilter('employee_id', employeeIds);

      int total = obligations.length;
      int completed = 0;
      int overdue = 0;
      final now = DateTime.now();

      for (final o in obligations) {
        final status = o['status'] as String?;
        final dueDate = o['due_date'] != null ? DateTime.parse(o['due_date']) : null;

        if (status == 'completed' || status == 'passed') {
          completed++;
        } else if (dueDate != null && dueDate.isBefore(now)) {
          overdue++;
        }
      }

      final compliance = total > 0 ? (completed / total) * 100 : 100;

      results.add({
        'role_id': roleId,
        'role_name': role['name'],
        'employee_count': employeeIds.length,
        'compliance_percentage': compliance,
        'overdue_count': overdue,
        'total_obligations': total,
      });
    }

    results.sort((a, b) => 
        (a['compliance_percentage'] as num).compareTo(b['compliance_percentage'] as num));

    return results;
  }

  // ---------------------------------------------------------------------------
  // Certificate Analytics
  // ---------------------------------------------------------------------------

  /// Gets certificate expiry analytics.
  Future<Map<String, dynamic>> getCertificateExpiryMetrics({
    required String orgId,
    int days = 30,
  }) async {
    final now = DateTime.now();
    final threshold = now.add(Duration(days: days));

    final certificates = await _supabase
        .from('certificates')
        .select('id, valid_until, status')
        .eq('organization_id', orgId)
        .eq('status', 'active');

    int active = 0;
    int expiringWithin = 0;
    int expired = 0;

    for (final cert in certificates) {
      final validUntil = cert['valid_until'] != null
          ? DateTime.parse(cert['valid_until'])
          : null;

      if (validUntil == null) {
        active++; // No expiry
      } else if (validUntil.isBefore(now)) {
        expired++;
      } else if (validUntil.isBefore(threshold)) {
        expiringWithin++;
      } else {
        active++;
      }
    }

    return {
      'total_certificates': certificates.length,
      'active': active,
      'expiring_within_${days}_days': expiringWithin,
      'expired': expired,
    };
  }
}
