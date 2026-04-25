import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/sessions/:id/check-out
///
/// Records check-out time for the current employee.
///
/// Body: `{employee_id?: UUID}` — optional, for coordinator checkout
///
/// Responses:
/// - 200 `{data: {attendance_id, checked_out_at, attendance_hours}}`
/// - 404 No check-in found
Future<Response> sessionCheckoutHandler(Request req) async {
  final sessionId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final targetEmployeeId = body['employee_id'] as String?;
  final employeeId = targetEmployeeId ?? auth.employeeId;
  final isSelfCheckout = employeeId == auth.employeeId;

  // If checking out someone else, require coordinator permission
  if (!isSelfCheckout) {
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.manageAttendance,
      jwtPermissions: auth.permissions,
    );
  }

  // 1. Load existing attendance record
  final attendance = await supabase
      .from('session_attendance')
      .select('id, check_in_time, check_out_time')
      .eq('session_id', sessionId)
      .eq('employee_id', employeeId)
      .maybeSingle();

  if (attendance == null) {
    throw NotFoundException('No check-in found for this session');
  }

  if (attendance['check_in_time'] == null) {
    throw ConflictException('Must check in before checking out');
  }

  if (attendance['check_out_time'] != null) {
    throw ConflictException('Already checked out of this session');
  }

  // 2. Calculate attendance hours
  final checkInTime = DateTime.parse(attendance['check_in_time'] as String);
  final checkOutTime = DateTime.now().toUtc();
  final attendanceHours =
      checkOutTime.difference(checkInTime).inMinutes / 60.0;

  // 3. Update attendance record
  await supabase.from('session_attendance').update({
    'check_out_time': checkOutTime.toIso8601String(),
    'attendance_hours': attendanceHours,
    'updated_at': checkOutTime.toIso8601String(),
  }).eq('id', attendance['id']);

  // 4. Publish event
  await OutboxService(supabase).publish(
    aggregateType: 'session_attendance',
    aggregateId: attendance['id'] as String,
    eventType: EventTypes.attendanceCheckedOut,
    payload: {
      'session_id': sessionId,
      'employee_id': employeeId,
      'attendance_hours': attendanceHours,
    },
    orgId: auth.orgId,
  );

  return ApiResponse.ok({
    'attendance_id': attendance['id'],
    'checked_out_at': checkOutTime.toIso8601String(),
    'attendance_hours': double.parse(attendanceHours.toStringAsFixed(2)),
  }).toResponse();
}
