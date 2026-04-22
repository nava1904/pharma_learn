import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/me/certificates
///
/// Returns certificates earned by the authenticated employee.
/// URS §5.1.23: Training completion certificates with verification link.
///
/// Query params:
/// - `status`: Filter by status (active|expired|revoked)
/// - `page`: Page number (default 1)
/// - `per_page`: Results per page (default 50, max 200)
Future<Response> meCertificatesHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final status = req.url.queryParameters['status'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  var perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '50') ?? 50;
  if (perPage > 200) perPage = 200;

  var query = supabase
      .from('certificates')
      .select('''
        id,
        certificate_number,
        status,
        issued_at,
        valid_until,
        qr_code_data,
        verification_hash,
        certificate_data,
        training_records (
          id,
          completed_at,
          training_type,
          courses ( id, title, course_code )
        )
      ''')
      .eq('employee_id', auth.employeeId)
      .eq('organization_id', auth.orgId);

  if (status != null) {
    query = query.eq('status', status);
  }

  final certificates = await query
      .order('issued_at', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  final total = (certificates as List).length;

  return ApiResponse.ok({
    'certificates': certificates,
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': total,
      'total_pages': total == 0 ? 1 : (total / perPage).ceil(),
    },
  }).toResponse();
}
