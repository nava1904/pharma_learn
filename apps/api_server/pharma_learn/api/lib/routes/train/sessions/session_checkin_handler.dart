import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/sessions/:id/check-in
///
/// Records attendance for the current employee or (for coordinators) another employee.
///
/// Body:
/// ```json
/// {
///   "check_in_method": "QR" | "BIOMETRIC" | "MANUAL",
///   "qr_code": "PLT01-2026-00001",      // required if method = QR
///   "employee_id": "uuid",               // optional — for coordinator check-in
///   "biometric_verified": true           // required if method = BIOMETRIC
/// }
/// ```
///
/// Responses:
/// - 200 `{data: {attendance_id, checked_in_at, session_code}}`
/// - 400 Invalid QR code / missing biometric verification
/// - 404 Session not found
/// - 409 Session not in progress / already checked in
Future<Response> sessionCheckinHandler(Request req) async {
  final sessionId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final checkInMethod = body['check_in_method'] as String?;
  final qrCode = body['qr_code'] as String?;
  final targetEmployeeId = body['employee_id'] as String?;
  final biometricVerified = body['biometric_verified'] as bool? ?? false;

  if (checkInMethod == null ||
      !['QR', 'BIOMETRIC', 'MANUAL'].contains(checkInMethod)) {
    throw ValidationException({
      'check_in_method': 'Must be QR, BIOMETRIC, or MANUAL',
    });
  }

  // Determine target employee (self or other)
  final employeeId = targetEmployeeId ?? auth.employeeId;
  final isSelfCheckin = employeeId == auth.employeeId;

  // If checking in someone else, require coordinator permission
  if (!isSelfCheckin) {
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.manageAttendance,
      jwtPermissions: auth.permissions,
    );
  }

  // 1. Load session and verify status
  final session = await supabase
      .from('training_sessions')
      .select('id, session_code, status, schedule_id, course_id')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Training session not found');
  }

  final sessionStatus = session['status'] as String?;
  if (sessionStatus != 'in_progress' && sessionStatus != 'scheduled') {
    throw ConflictException(
      'Session is not available for check-in (status: $sessionStatus)',
    );
  }

  // 2. Validate check-in method requirements
  switch (checkInMethod) {
    case 'QR':
      if (qrCode == null || qrCode.isEmpty) {
        throw ValidationException({'qr_code': 'QR code required for QR check-in'});
      }
      if (qrCode != session['session_code']) {
        throw ValidationException({'qr_code': 'Invalid QR code for this session'});
      }
      break;
    case 'BIOMETRIC':
      if (!biometricVerified) {
        throw ValidationException({
          'biometric_verified': 'Biometric verification required',
        });
      }
      break;
    case 'MANUAL':
      // No additional validation — coordinator responsibility
      break;
  }

  // 3. Check for existing attendance
  final existingAttendance = await supabase
      .from('session_attendance')
      .select('id, check_in_time')
      .eq('session_id', sessionId)
      .eq('employee_id', employeeId)
      .maybeSingle();

  if (existingAttendance != null && existingAttendance['check_in_time'] != null) {
    throw ConflictException('Already checked in to this session');
  }

  // 4. Insert or update attendance record
  final now = DateTime.now().toUtc().toIso8601String();
  Map<String, dynamic> attendanceRecord;

  if (existingAttendance != null) {
    // Update existing record (pre-registered but not checked in)
    await supabase.from('session_attendance').update({
      'check_in_time': now,
      'attendance_status': 'present',
      'biometric_verified': checkInMethod == 'BIOMETRIC',
      'biometric_reference': checkInMethod == 'BIOMETRIC' ? 'client_verified' : null,
      'marked_by': isSelfCheckin ? null : auth.employeeId,
      'marked_at': now,
      'updated_at': now,
    }).eq('id', existingAttendance['id']);
    
    attendanceRecord = {'id': existingAttendance['id']};
  } else {
    // Insert new attendance record
    final inserted = await supabase.from('session_attendance').insert({
      'session_id': sessionId,
      'employee_id': employeeId,
      'check_in_time': now,
      'attendance_status': 'present',
      'biometric_verified': checkInMethod == 'BIOMETRIC',
      'biometric_reference': checkInMethod == 'BIOMETRIC' ? 'client_verified' : null,
      'marked_by': isSelfCheckin ? null : auth.employeeId,
      'marked_at': now,
    }).select('id').single();
    
    attendanceRecord = inserted;
  }

  // 5. Publish event
  await OutboxService(supabase).publish(
    aggregateType: 'session_attendance',
    aggregateId: attendanceRecord['id'] as String,
    eventType: EventTypes.attendanceCheckedIn,
    payload: {
      'session_id': sessionId,
      'employee_id': employeeId,
      'check_in_method': checkInMethod,
      'checked_in_by': auth.employeeId,
    },
    orgId: auth.orgId,
  );

  return ApiResponse.ok({
    'attendance_id': attendanceRecord['id'],
    'checked_in_at': now,
    'session_code': session['session_code'],
    'check_in_method': checkInMethod,
  }).toResponse();
}
