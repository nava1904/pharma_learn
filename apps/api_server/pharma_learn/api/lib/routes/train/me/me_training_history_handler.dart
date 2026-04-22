import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/me/training-history
///
/// Returns complete training history for the authenticated user.
/// URS EE §5.1.23: Full training history export
///
/// Query params:
/// - `status`: Filter by status (completed, in_progress, pending, expired)
/// - `course_type`: Filter by course type (classroom, e-learning, ojt, self_learning)
/// - `from_date`: Training completed after this date (ISO8601)
/// - `to_date`: Training completed before this date (ISO8601)
/// - `page`: Page number (default 1)
/// - `per_page`: Results per page (default 50, max 200)
Future<Response> meTrainingHistoryHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final status = req.url.queryParameters['status'];
  final courseType = req.url.queryParameters['course_type'];
  final fromDate = req.url.queryParameters['from_date'];
  final toDate = req.url.queryParameters['to_date'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  var perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '50') ?? 50;
  if (perPage > 200) perPage = 200;

  final employeeId = auth.employeeId;

  // Build comprehensive training history query
  // This aggregates from multiple sources:
  // 1. Course completions (e-learning, classroom)
  // 2. OJT completions
  // 3. Self-learning completions
  // 4. Document readings

  final results = <Map<String, dynamic>>[];

  // 1. Course-based training (from enrollments/obligations)
  var courseQuery = supabase
      .from('employee_training_obligations')
      .select('''
        id,
        status,
        due_date,
        completed_at,
        courses!inner (
          id,
          name,
          course_code,
          course_type,
          duration_minutes
        ),
        certificate_id
      ''')
      .eq('employee_id', employeeId)
      .eq('organization_id', auth.orgId);

  if (status != null) {
    courseQuery = courseQuery.eq('status', status);
  }
  if (fromDate != null) {
    courseQuery = courseQuery.gte('completed_at', fromDate);
  }
  if (toDate != null) {
    courseQuery = courseQuery.lte('completed_at', toDate);
  }

  final courseResults = await courseQuery.order('completed_at', ascending: false);

  for (final item in courseResults) {
    final course = item['courses'] as Map<String, dynamic>?;
    if (course == null) continue;
    
    if (courseType != null && course['course_type'] != courseType) continue;

    results.add({
      'id': item['id'],
      'type': 'course',
      'training_type': course['course_type'],
      'name': course['name'],
      'code': course['course_code'],
      'status': item['status'],
      'due_date': item['due_date'],
      'completed_at': item['completed_at'],
      'duration_minutes': course['duration_minutes'],
      'certificate_id': item['certificate_id'],
    });
  }

  // 2. OJT completions
  if (courseType == null || courseType == 'ojt') {
    var ojtQuery = supabase
        .from('employee_ojt')
        .select('''
          id,
          status,
          start_date,
          actual_completion_date,
          ojt_masters!inner(id, name, unique_code)
        ''')
        .eq('employee_id', employeeId);

    if (status != null) {
      ojtQuery = ojtQuery.eq('status', status);
    }
    if (fromDate != null) {
      ojtQuery = ojtQuery.gte('actual_completion_date', fromDate);
    }
    if (toDate != null) {
      ojtQuery = ojtQuery.lte('actual_completion_date', toDate);
    }

    final ojtResults = await ojtQuery.order('actual_completion_date', ascending: false);

    for (final item in ojtResults) {
      final ojt = item['ojt_masters'] as Map<String, dynamic>?;
      if (ojt == null) continue;
      
      results.add({
        'id': item['id'],
        'type': 'ojt',
        'training_type': 'ojt',
        'name': ojt['name'],
        'code': ojt['unique_code'],
        'status': item['status'],
        'due_date': item['start_date'],
        'completed_at': item['actual_completion_date'],
        'duration_minutes': null,
      });
    }
  }

  // 3. Self-learning completions (standalone, not compliance-driven)
  if (courseType == null || courseType == 'self_learning') {
    var selfLearnQuery = supabase
        .from('self_learning_assignments')
        .select('''
          id,
          status,
          assigned_at,
          completed_at,
          course_id,
          courses(id, name, course_code),
          document_id,
          documents(id, title, doc_number)
        ''')
        .eq('employee_id', employeeId);

    if (status != null) {
      selfLearnQuery = selfLearnQuery.eq('status', status);
    }
    if (fromDate != null) {
      selfLearnQuery = selfLearnQuery.gte('completed_at', fromDate);
    }
    if (toDate != null) {
      selfLearnQuery = selfLearnQuery.lte('completed_at', toDate);
    }

    final selfLearnResults = await selfLearnQuery.order('completed_at', ascending: false);

    for (final item in selfLearnResults) {
      // Self-learning can be for a course or a document
      final course = item['courses'] as Map<String, dynamic>?;
      final document = item['documents'] as Map<String, dynamic>?;
      
      String? name;
      String? code;
      if (course != null) {
        name = course['name'] as String?;
        code = course['course_code'] as String?;
      } else if (document != null) {
        name = document['title'] as String?;
        code = document['doc_number'] as String?;
      }
      
      if (name == null) continue;

      results.add({
        'id': item['id'],
        'type': 'self_learning',
        'training_type': 'self_learning',
        'name': name,
        'code': code,
        'status': item['status'],
        'started_at': item['assigned_at'],
        'completed_at': item['completed_at'],
        'duration_minutes': null,
        'certificate_id': null,
      });
    }
  }

  // Sort all results by completed_at descending
  results.sort((a, b) {
    final aDate = a['completed_at'] as String?;
    final bDate = b['completed_at'] as String?;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });

  // Paginate
  final total = results.length;
  final offset = (page - 1) * perPage;
  final paginatedResults = results.skip(offset).take(perPage).toList();

  // Calculate summary stats
  final completedCount = results.where((r) => r['status'] == 'completed').length;
  final totalMinutes = results
      .where((r) => r['status'] == 'completed' && r['duration_minutes'] != null)
      .fold<int>(0, (sum, r) => sum + (r['duration_minutes'] as int));

  return ApiResponse.ok({
    'history': paginatedResults,
    'summary': {
      'total_records': total,
      'completed_count': completedCount,
      'total_training_minutes': totalMinutes,
      'total_training_hours': (totalMinutes / 60).toStringAsFixed(1),
    },
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': total,
      'total_pages': (total / perPage).ceil(),
    },
  }).toResponse();
}
