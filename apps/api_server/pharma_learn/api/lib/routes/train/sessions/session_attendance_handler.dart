import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/sessions/:id/attendance
///
/// Returns attendance records for a session.
/// Trainers see full list, participants see only their own.
Future<Response> sessionAttendanceListHandler(Request req) async {
  final sessionId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Check if user is trainer for this session
  final session = await supabase
      .from('training_sessions')
      .select('trainer_id')
      .eq('id', sessionId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (session == null) throw NotFoundException('Session not found');

  final isTrainer = session['trainer_id'] == auth.employeeId;

  // Build query
  var query = supabase
      .from('training_attendance')
      .select(
        '*, '
        'employees!employee_id ( id, first_name, last_name, employee_number )',
      )
      .eq('session_id', sessionId);

  // Non-trainers only see their own attendance
  if (!isTrainer) {
    query = query.eq('employee_id', auth.employeeId);
  }

  final records = await query.order('check_in_at', ascending: true);

  return ApiResponse.ok({'attendance': records}).toResponse();
}

/// POST /v1/sessions/:id/attendance
///
/// Mark attendance for a trainee (trainer only).
/// Supports post-dated entry with `attended_at` field.
/// URS Alfa §4.3.19: Post-dated attendance entry
Future<Response> sessionAttendanceMarkHandler(Request req) async {
  final sessionId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAttendance,
    jwtPermissions: auth.permissions,
  );

  // Verify session exists and user is trainer
  final session = await supabase
      .from('training_sessions')
      .select('id, trainer_id, status')
      .eq('id', sessionId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (session == null) throw NotFoundException('Session not found');

  if (session['trainer_id'] != auth.employeeId) {
    throw PermissionDeniedException('Only the assigned trainer can mark attendance');
  }

  final body = await readJson(req);
  final employeeIdRaw = body['employee_id'] as String?;
  if (employeeIdRaw == null || employeeIdRaw.isEmpty) {
    throw ValidationException({'employee_id': 'Required'});
  }
  final employeeId = parsePathUuid(employeeIdRaw, fieldName: 'employee_id');

  final checkInAt = body['check_in_at'] as String?;
  final checkOutAt = body['check_out_at'] as String?;
  final attendedAt = body['attended_at'] as String?; // For post-dated entry
  final notes = body['notes'] as String?;

  // Determine timestamps
  final now = DateTime.now().toUtc().toIso8601String();
  final effectiveCheckIn = checkInAt ?? attendedAt ?? now;

  // Check if attendance record already exists
  final existing = await supabase
      .from('training_attendance')
      .select('id')
      .eq('session_id', sessionId)
      .eq('employee_id', employeeId)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException(
      'Attendance already recorded for this employee. Use PATCH to update.',
    );
  }

  // Create attendance record
  final record = await supabase
      .from('training_attendance')
      .insert({
        'session_id': sessionId,
        'employee_id': employeeId,
        'check_in_at': effectiveCheckIn,
        'check_out_at': checkOutAt,
        'marked_by': auth.employeeId,
        'marked_at': now,
        'is_post_dated': attendedAt != null,
        'notes': notes,
      })
      .select()
      .single();

  return ApiResponse.created({'attendance': record}).toResponse();
}

/// PATCH /v1/sessions/:id/attendance/:employeeId
///
/// Correct attendance record (21 CFR Part 11 compliant).
/// Creates correction row, preserves original.
/// URS EE §5.1.23: Attendance correction with audit trail
Future<Response> sessionAttendanceCorrectionHandler(Request req) async {
  final sessionId = parsePathUuid(req.rawPathParameters[#id]);
  final employeeId = parsePathUuid(req.rawPathParameters[#employeeId]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAttendance,
    jwtPermissions: auth.permissions,
  );

  // Verify session and trainer
  final session = await supabase
      .from('training_sessions')
      .select('id, trainer_id')
      .eq('id', sessionId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (session == null) throw NotFoundException('Session not found');

  if (session['trainer_id'] != auth.employeeId) {
    throw PermissionDeniedException('Only the assigned trainer can correct attendance');
  }

  // Get existing attendance record
  final existing = await supabase
      .from('training_attendance')
      .select()
      .eq('session_id', sessionId)
      .eq('employee_id', employeeId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Attendance record not found');
  }

  final body = await readJson(req);
  final correctionReason = body['reason'] as String?;

  if (correctionReason == null || correctionReason.trim().isEmpty) {
    throw ValidationException({'reason': 'Correction reason is required'});
  }

  final newCheckInAt = body['check_in_at'] as String?;
  final newCheckOutAt = body['check_out_at'] as String?;
  final newNotes = body['notes'] as String?;

  // Build correction data
  final correctionData = <String, dynamic>{
    'original_record_id': existing['id'],
    'session_id': sessionId,
    'employee_id': employeeId,
    'original_check_in_at': existing['check_in_at'],
    'original_check_out_at': existing['check_out_at'],
    'corrected_check_in_at': newCheckInAt ?? existing['check_in_at'],
    'corrected_check_out_at': newCheckOutAt ?? existing['check_out_at'],
    'correction_reason': correctionReason,
    'corrected_by': auth.employeeId,
    'corrected_at': DateTime.now().toUtc().toIso8601String(),
  };

  // Insert correction record (immutable audit trail)
  final correction = await supabase
      .from('attendance_corrections')
      .insert(correctionData)
      .select()
      .single();

  // Update the attendance record with corrected values
  final updated = await supabase
      .from('training_attendance')
      .update({
        'check_in_at': newCheckInAt ?? existing['check_in_at'],
        'check_out_at': newCheckOutAt ?? existing['check_out_at'],
        'notes': newNotes ?? existing['notes'],
        'has_correction': true,
        'last_correction_id': correction['id'],
      })
      .eq('id', existing['id'])
      .select()
      .single();

  return ApiResponse.ok({
    'attendance': updated,
    'correction': correction,
  }).toResponse();
}

/// POST /v1/sessions/:id/attendance/upload
///
/// Upload scanned attendance sheet.
/// URS Alfa §4.3.19: Scanned sheet upload
Future<Response> sessionAttendanceUploadHandler(Request req) async {
  final sessionId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageAttendance,
    jwtPermissions: auth.permissions,
  );

  // Verify session and trainer
  final session = await supabase
      .from('training_sessions')
      .select('id, trainer_id')
      .eq('id', sessionId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (session == null) throw NotFoundException('Session not found');

  if (session['trainer_id'] != auth.employeeId) {
    throw PermissionDeniedException('Only the assigned trainer can upload attendance sheets');
  }

  // Read JSON body with base64 encoded file
  final body = await readJson(req);
  final fileBase64 = body['file_base64'] as String?;
  final fileName = body['file_name'] as String? ?? 'attendance_sheet.pdf';

  if (fileBase64 == null || fileBase64.isEmpty) {
    throw ValidationException({'file_base64': 'Attendance sheet file is required (base64 encoded)'});
  }

  // Decode base64
  final bytes = base64Decode(fileBase64);
  final fileSize = bytes.length;

  // Validate file type (PDF or image)
  final allowedTypes = ['.pdf', '.jpg', '.jpeg', '.png'];
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1) {
    throw ValidationException({'file_name': 'File name must have an extension'});
  }
  final extension = fileName.toLowerCase().substring(dotIndex);
  if (!allowedTypes.contains(extension)) {
    throw ValidationException({
      'file_name': 'Invalid file type. Allowed: ${allowedTypes.join(", ")}',
    });
  }

  // Upload to storage
  final storagePath = 'attendance_sheets/$sessionId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
  
  await supabase.storage
      .from('training-documents')
      .uploadBinary(storagePath, bytes);

  // Get public URL
  final publicUrl = supabase.storage
      .from('training-documents')
      .getPublicUrl(storagePath);

  // Save reference in database
  final upload = await supabase
      .from('attendance_uploads')
      .insert({
        'session_id': sessionId,
        'file_name': fileName,
        'file_size_bytes': fileSize,
        'storage_path': storagePath,
        'storage_url': publicUrl,
        'uploaded_by': auth.employeeId,
        'uploaded_at': DateTime.now().toUtc().toIso8601String(),
      })
      .select()
      .single();

  return ApiResponse.created({'upload': upload}).toResponse();
}
