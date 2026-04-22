import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/me/obligations
///
/// Returns the authenticated employee's training to-do list.
/// URS §5.1.5: pending, in-progress, overdue, and upcoming obligations.
///
/// Query params:
/// - `status`: Filter by status (pending|in_progress|overdue|completed)
/// - `item_type`: Filter by type (course|document|ojt|assessment)
/// - `page`: Page number (default 1)
/// - `per_page`: Results per page (default 50, max 200)
Future<Response> meObligationsHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final status = req.url.queryParameters['status'];
  final itemType = req.url.queryParameters['item_type'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  var perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '50') ?? 50;
  if (perPage > 200) perPage = 200;

  var query = supabase
      .from('employee_training_obligations')
      .select('''
        id,
        item_type,
        status,
        due_date,
        assigned_at,
        started_at,
        completed_at,
        is_induction,
        courses ( id, title, course_code, course_type, estimated_duration_minutes ),
        documents ( id, title, document_number ),
        ojt_masters ( id, name, unique_code )
      ''')
      .eq('employee_id', auth.employeeId)
      .eq('organization_id', auth.orgId);

  if (status != null) {
    query = query.eq('status', status);
  }
  if (itemType != null) {
    query = query.eq('item_type', itemType);
  }

  final results = await query
      .order('due_date', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  final total = (results as List).length;

  // Summary counts for the dashboard
  final allObligations = await supabase
      .from('employee_training_obligations')
      .select('status, due_date')
      .eq('employee_id', auth.employeeId)
      .eq('organization_id', auth.orgId);

  int pendingCount = 0, inProgressCount = 0, overdueCount = 0, completedCount = 0;
  for (final o in allObligations as List) {
    final s = o['status'] as String? ?? '';
    switch (s) {
      case 'pending':
        pendingCount++;
        break;
      case 'in_progress':
        inProgressCount++;
        break;
      case 'overdue':
        overdueCount++;
        break;
      case 'completed':
        completedCount++;
        break;
    }
  }

  return ApiResponse.ok({
    'obligations': results,
    'summary': {
      'pending': pendingCount,
      'in_progress': inProgressCount,
      'overdue': overdueCount,
      'completed': completedCount,
      'total': allObligations.length,
    },
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': total,
      'total_pages': total == 0 ? 1 : (total / perPage).ceil(),
    },
  }).toResponse();
}
