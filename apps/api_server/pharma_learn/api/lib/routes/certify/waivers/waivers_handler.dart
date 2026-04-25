import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/certify/waivers
///
/// Returns waiver requests for approval (admin view).
/// Query params:
/// - status: pending|approved|rejected (optional)
/// - page, per_page: pagination
Future<Response> waiversListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final status = req.url.queryParameters['status'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;

  // Verify user has permission to manage waivers
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  var query = supabase
      .from('waivers')
      .select('''
        id, reason, status, requested_at, approved_at, rejected_at, rejection_reason,
        employees!employee_id(id, first_name, last_name, employee_number),
        employee_assignments!inner(
          id, due_date,
          training_assignments!inner(
            name,
            courses!inner(id, title, course_code)
          )
        ),
        employees!approved_by(id, first_name, last_name)
      ''');

  if (status != null) {
    query = query.eq('status', status);
  }

  final response = await query
      .order('requested_at', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  return ApiResponse.ok(response).toResponse();
}

/// GET /v1/certify/waivers/:id
///
/// Returns waiver request details.
Future<Response> waiverGetHandler(Request req) async {
  final waiverId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify user has permission to manage waivers
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  final waiver = await supabase
      .from('waivers')
      .select('''
        id, reason, status, requested_at, approved_at, rejected_at, rejection_reason,
        employees!employee_id(id, first_name, last_name, employee_number, email),
        employee_assignments!inner(
          id, due_date, status,
          training_assignments!inner(
            name, description,
            courses!inner(id, title, course_code, description)
          )
        ),
        employees!approved_by(id, first_name, last_name),
        electronic_signatures(id, meaning, signed_at)
      ''')
      .eq('id', waiverId)
      .maybeSingle();

  if (waiver == null) {
    throw NotFoundException('Waiver request not found');
  }

  return ApiResponse.ok(waiver).toResponse();
}

/// POST /v1/certify/waivers/:id/approve
///
/// Approves a waiver request with e-signature.
///
/// Body:
/// ```json
/// {
///   "esignature": {
///     "reauth_session_id": "uuid",
///     "meaning": "APPROVE"
///   }
/// }
/// ```
Future<Response> waiverApproveHandler(Request req) async {
  final waiverId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final esigData = body['esignature'] as Map<String, dynamic>?;
  if (esigData == null || esigData['reauth_session_id'] == null) {
    throw ValidationException({'esignature': 'E-signature is required for approval'});
  }

  // Verify user has permission to manage waivers
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  // Get waiver request
  final waiver = await supabase
      .from('waivers')
      .select('id, status, employee_assignment_id')
      .eq('id', waiverId)
      .maybeSingle();

  if (waiver == null) {
    throw NotFoundException('Waiver request not found');
  }

  if (waiver['status'] != 'pending') {
    throw ConflictException('Waiver has already been ${waiver['status']}');
  }

  // Create e-signature
  final esig = await supabase.rpc(
    'create_esignature_from_reauth',
    params: {
      'p_reauth_session_id': esigData['reauth_session_id'],
      'p_employee_id': auth.employeeId,
      'p_meaning': 'APPROVE',
      'p_context_type': 'waiver_approval',
      'p_context_id': waiverId,
    },
  ) as Map<String, dynamic>;

  final now = DateTime.now().toUtc().toIso8601String();

  // Update waiver
  await supabase.from('waivers').update({
    'status': 'approved',
    'approved_by': auth.employeeId,
    'approved_at': now,
    'esignature_id': esig['esignature_id'],
  }).eq('id', waiverId);

  // Update employee assignment to waived
  await supabase.from('employee_assignments').update({
    'status': 'waived',
    'waived_at': now,
    'waiver_reason': 'Approved by manager',
  }).eq('id', waiver['employee_assignment_id']);

  return ApiResponse.ok({
    'waiver_id': waiverId,
    'status': 'approved',
    'approved_at': now,
  }).toResponse();
}

/// POST /v1/certify/waivers/:id/reject
///
/// Rejects a waiver request.
///
/// Body:
/// ```json
/// {
///   "reason": "Rejection reason"
/// }
/// ```
Future<Response> waiverRejectHandler(Request req) async {
  final waiverId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final reason = body['reason'] as String?;
  if (reason == null || reason.trim().isEmpty) {
    throw ValidationException({'reason': 'Rejection reason is required'});
  }

  // Verify user has permission to manage waivers
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageCompliance,
    jwtPermissions: auth.permissions,
  );

  // Get waiver request
  final waiver = await supabase
      .from('waivers')
      .select('id, status')
      .eq('id', waiverId)
      .maybeSingle();

  if (waiver == null) {
    throw NotFoundException('Waiver request not found');
  }

  if (waiver['status'] != 'pending') {
    throw ConflictException('Waiver has already been ${waiver['status']}');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Update waiver
  await supabase.from('waivers').update({
    'status': 'rejected',
    'rejected_by': auth.employeeId,
    'rejected_at': now,
    'rejection_reason': reason.trim(),
  }).eq('id', waiverId);

  return ApiResponse.ok({
    'waiver_id': waiverId,
    'status': 'rejected',
    'rejected_at': now,
  }).toResponse();
}

/// GET /v1/certify/waivers/my
///
/// Returns the current employee's waiver requests.
Future<Response> myWaiversHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final waivers = await supabase
      .from('waivers')
      .select('''
        id, reason, status, requested_at, approved_at, rejected_at, rejection_reason,
        employee_assignments!inner(
          id, due_date,
          training_assignments!inner(
            name,
            courses!inner(id, title, course_code)
          )
        )
      ''')
      .eq('employee_id', auth.employeeId)
      .order('requested_at', ascending: false);

  return ApiResponse.ok(waivers).toResponse();
}
