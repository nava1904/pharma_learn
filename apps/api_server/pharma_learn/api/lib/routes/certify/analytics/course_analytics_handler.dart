import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/certify/analytics/courses/:id
///
/// Course-level analytics: pass rate trends, completion rates, avg scores.
/// Returns aggregate metrics for a specific course.
Future<Response> courseAnalyticsHandler(Request req) async {
  final courseId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  // Query parameters for time range
  final fromDate = req.url.queryParameters['from_date'];
  final toDate = req.url.queryParameters['to_date'];

  // Verify course exists
  final course = await supabase
      .from('courses')
      .select('id, name, course_code, passing_score')
      .eq('id', courseId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (course == null) throw NotFoundException('Course not found');

  // Get all assessments for this course
  var assessmentsQuery = supabase
      .from('assessments')
      .select('id, status, score, max_score, percentage, completed_at, started_at')
      .eq('course_id', courseId)
      .eq('organization_id', auth.orgId)
      .inFilter('status', ['passed', 'failed', 'completed']);

  if (fromDate != null) {
    assessmentsQuery = assessmentsQuery.gte('completed_at', fromDate);
  }
  if (toDate != null) {
    assessmentsQuery = assessmentsQuery.lte('completed_at', toDate);
  }

  final assessments = await assessmentsQuery;

  // Calculate metrics
  final totalAttempts = assessments.length;
  final passedCount = assessments.where((a) => a['status'] == 'passed').length;
  final failedCount = assessments.where((a) => a['status'] == 'failed').length;

  // Pass rate
  final passRate = totalAttempts > 0 
      ? (passedCount / totalAttempts * 100).toStringAsFixed(1) 
      : '0.0';

  // Average score
  var totalScore = 0.0;
  var totalMaxScore = 0.0;
  var totalTimeMinutes = 0.0;
  var timeCount = 0;

  for (final assessment in assessments) {
    final score = (assessment['score'] as num?)?.toDouble() ?? 0;
    final maxScore = (assessment['max_score'] as num?)?.toDouble() ?? 0;
    totalScore += score;
    totalMaxScore += maxScore;

    // Calculate time spent
    final startedAt = assessment['started_at'] as String?;
    final completedAt = assessment['completed_at'] as String?;
    if (startedAt != null && completedAt != null) {
      final start = DateTime.parse(startedAt);
      final end = DateTime.parse(completedAt);
      final minutes = end.difference(start).inMinutes;
      if (minutes > 0 && minutes < 480) { // Ignore outliers > 8 hours
        totalTimeMinutes += minutes;
        timeCount++;
      }
    }
  }

  final avgScorePercent = totalMaxScore > 0 
      ? (totalScore / totalMaxScore * 100).toStringAsFixed(1) 
      : '0.0';
  
  final avgTimeMinutes = timeCount > 0 
      ? (totalTimeMinutes / timeCount).round() 
      : 0;

  // Score distribution buckets
  final scoreDistribution = {
    '0-50': 0,
    '51-60': 0,
    '61-70': 0,
    '71-80': 0,
    '81-90': 0,
    '91-100': 0,
  };

  for (final assessment in assessments) {
    final percentage = (assessment['percentage'] as num?)?.toDouble() ?? 0;
    if (percentage <= 50) {
      scoreDistribution['0-50'] = (scoreDistribution['0-50'] ?? 0) + 1;
    } else if (percentage <= 60) {
      scoreDistribution['51-60'] = (scoreDistribution['51-60'] ?? 0) + 1;
    } else if (percentage <= 70) {
      scoreDistribution['61-70'] = (scoreDistribution['61-70'] ?? 0) + 1;
    } else if (percentage <= 80) {
      scoreDistribution['71-80'] = (scoreDistribution['71-80'] ?? 0) + 1;
    } else if (percentage <= 90) {
      scoreDistribution['81-90'] = (scoreDistribution['81-90'] ?? 0) + 1;
    } else {
      scoreDistribution['91-100'] = (scoreDistribution['91-100'] ?? 0) + 1;
    }
  }

  // Monthly trend (last 6 months)
  final monthlyTrend = <Map<String, dynamic>>[];
  final now = DateTime.now();
  
  for (var i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final monthEnd = DateTime(now.year, now.month - i + 1, 0);
    
    final monthAssessments = assessments.where((a) {
      final completedAt = a['completed_at'] as String?;
      if (completedAt == null) return false;
      final date = DateTime.parse(completedAt);
      return date.isAfter(month.subtract(const Duration(days: 1))) && 
             date.isBefore(monthEnd.add(const Duration(days: 1)));
    }).toList();

    final monthTotal = monthAssessments.length;
    final monthPassed = monthAssessments.where((a) => a['status'] == 'passed').length;
    
    monthlyTrend.add({
      'month': '${month.year}-${month.month.toString().padLeft(2, '0')}',
      'total_attempts': monthTotal,
      'passed': monthPassed,
      'failed': monthTotal - monthPassed,
      'pass_rate': monthTotal > 0 
          ? (monthPassed / monthTotal * 100).toStringAsFixed(1) 
          : '0.0',
    });
  }

  return ApiResponse.ok({
    'course': {
      'id': course['id'],
      'name': course['name'],
      'code': course['course_code'],
      'passing_score': course['passing_score'],
    },
    'summary': {
      'total_attempts': totalAttempts,
      'passed': passedCount,
      'failed': failedCount,
      'pass_rate_percent': passRate,
      'avg_score_percent': avgScorePercent,
      'avg_time_minutes': avgTimeMinutes,
    },
    'score_distribution': scoreDistribution,
    'monthly_trend': monthlyTrend,
  }).toResponse();
}

/// GET /v1/certify/analytics/courses
///
/// List all courses with their analytics summary.
Future<Response> coursesAnalyticsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewReports,
    jwtPermissions: auth.permissions,
  );

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  var perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  if (perPage > 100) perPage = 100;

  // Get all approved courses
  final courses = await supabase
      .from('courses')
      .select('id, name, course_code, passing_score')
      .eq('organization_id', auth.orgId)
      .eq('status', 'approved')
      .order('name', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  // Get assessment stats for each course
  final courseStats = <Map<String, dynamic>>[];

  for (final course in courses) {
    final courseId = course['id'] as String;

    final stats = await supabase
        .from('assessments')
        .select('status')
        .eq('course_id', courseId)
        .inFilter('status', ['passed', 'failed']);

    final total = stats.length;
    final passed = stats.where((s) => s['status'] == 'passed').length;
    final passRate = total > 0 
        ? (passed / total * 100).toStringAsFixed(1) 
        : 'N/A';

    courseStats.add({
      'id': course['id'],
      'name': course['name'],
      'code': course['course_code'],
      'passing_score': course['passing_score'],
      'total_attempts': total,
      'passed': passed,
      'failed': total - passed,
      'pass_rate': passRate,
    });
  }

  return ApiResponse.ok({
    'courses': courseStats,
    'pagination': {
      'page': page,
      'per_page': perPage,
    },
  }).toResponse();
}
