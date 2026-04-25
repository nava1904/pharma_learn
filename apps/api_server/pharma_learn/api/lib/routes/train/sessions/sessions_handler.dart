import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/sessions/:id
///
/// Returns session details including attendance summary.
Future<Response> sessionGetHandler(Request req) async {
  final sessionId = parsePathUuid(req.rawPathParameters[#id]);
  final supabase = RequestContext.supabase;

  final session = await supabase
      .from('training_sessions')
      .select('''
        *,
        training_schedules!inner(name, description),
        courses!inner(name, course_code),
        trainers(first_name, last_name),
        training_venues(name, location)
      ''')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Training session not found');
  }

  // Get attendance stats
  final attendanceStats = await supabase
      .from('session_attendance')
      .select('attendance_status')
      .eq('session_id', sessionId);

  final totalAttendees = attendanceStats.length;
  final presentCount = attendanceStats
      .where((a) => a['attendance_status'] == 'present')
      .length;

  return ApiResponse.ok({
    ...session,
    'attendance_summary': {
      'total': totalAttendees,
      'present': presentCount,
      'absent': totalAttendees - presentCount,
    },
  }).toResponse();
}

/// GET /v1/sessions
///
/// Lists sessions with filtering.
/// Query: ?schedule_id=UUID&status=scheduled|in_progress|completed&date=YYYY-MM-DD
Future<Response> sessionsListHandler(Request req) async {
  final supabase = RequestContext.supabase;

  final scheduleId = req.url.queryParameters['schedule_id'];
  final status = req.url.queryParameters['status'];
  final dateStr = req.url.queryParameters['date'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;

  // Get total count first
  final countQuery = supabase.from('training_sessions').select('id');
  var countFiltered = countQuery;
  if (scheduleId != null) countFiltered = countFiltered.eq('schedule_id', scheduleId);
  if (status != null) countFiltered = countFiltered.eq('status', status);
  if (dateStr != null) countFiltered = countFiltered.eq('session_date', dateStr);
  final countResult = await countFiltered;
  final total = countResult.length;

  // Get paginated data
  var query = supabase
      .from('training_sessions')
      .select('''
        id, session_code, session_number, session_date, start_time, end_time,
        status, training_method, online_offline,
        training_schedules!inner(name),
        courses!inner(name, course_code)
      ''');

  if (scheduleId != null) {
    query = query.eq('schedule_id', scheduleId);
  }
  if (status != null) {
    query = query.eq('status', status);
  }
  if (dateStr != null) {
    query = query.eq('session_date', dateStr);
  }

  final response = await query
      .order('session_date', ascending: false)
      .order('start_time', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  return ApiResponse.paginated(
    response,
    Pagination.compute(
      page: page,
      perPage: perPage,
      total: total,
    ),
  ).toResponse();
}
