import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart' show CountOption;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/query_parser.dart';

/// GET /v1/train/me/sessions - List my upcoming and past sessions
Future<Response> meSessionsHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final q = QueryParams.fromRequest(req);
  final qp = req.url.queryParameters;
  final offset = (q.page - 1) * q.perPage;

  // Get sessions where user is enrolled
  var query = supabase
      .from('session_attendance')
      .select('''
        *,
        session:training_sessions(
          id, session_date, start_time, end_time, status,
          schedule:training_schedules(id, name, course:courses(id, code, name)),
          venue:venues(id, name, location),
          trainer:trainers(id, employee:employees(id, full_name))
        )
      ''')
      .eq('employee_id', auth.employeeId);

  // Filter by status
  if (qp['status'] != null) {
    switch (qp['status']) {
      case 'upcoming':
        query = query.eq('session.status', 'scheduled');
        break;
      case 'completed':
        query = query.eq('session.status', 'completed');
        break;
      case 'in_progress':
        query = query.eq('session.status', 'in_progress');
        break;
    }
  }

  final response = await query
      .order('session(session_date)', ascending: qp['status'] == 'upcoming')
      .range(offset, offset + q.perPage - 1)
      .count(CountOption.exact);

  final pagination = Pagination(
    page: q.page,
    perPage: q.perPage,
    total: response.count,
    totalPages: response.count == 0 ? 1 : (response.count / q.perPage).ceil(),
  );

  return ApiResponse.paginated(response.data, pagination).toResponse();
}
