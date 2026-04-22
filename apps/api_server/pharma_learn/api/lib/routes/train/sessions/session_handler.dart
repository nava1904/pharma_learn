import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/sessions/:id - Get session by ID
Future<Response> sessionGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('training_sessions')
      .select('''
        *,
        schedule:training_schedules(id, name, course:courses(id, code, name)),
        venue:venues(id, name, location),
        trainer:trainers(id, employee:employees(id, full_name)),
        session_attendance(*)
      ''')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Session not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/train/sessions/:id - Update session
Future<Response> sessionUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sessions.update',
    jwtPermissions: auth.permissions,
  );

  final existing = await supabase
      .from('training_sessions')
      .select('id, status')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Session not found').toResponse();
  }

  if (existing['status'] == 'completed') {
    return ErrorResponse.conflict('Completed sessions cannot be edited').toResponse();
  }

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final updateData = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
    'updated_by': auth.employeeId,
  };

  if (body['session_date'] != null) updateData['session_date'] = body['session_date'];
  if (body['start_time'] != null) updateData['start_time'] = body['start_time'];
  if (body['end_time'] != null) updateData['end_time'] = body['end_time'];
  if (body['venue_id'] != null) updateData['venue_id'] = body['venue_id'];
  if (body['trainer_id'] != null) updateData['trainer_id'] = body['trainer_id'];
  if (body['status'] != null) updateData['status'] = body['status'];

  final result = await supabase
      .from('training_sessions')
      .update(updateData)
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_sessions',
    'entity_id': id,
    'action': 'UPDATE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/train/sessions/:id/attendance/:empId - Mark attendance for employee
/// Reference: 21 CFR §11.10 immutability - corrections go to attendance_correction table
Future<Response> sessionAttendanceMarkHandler(Request req, String sessionId, String empId) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sessions.mark_attendance',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  // Check if attendance already exists
  final existing = await supabase
      .from('session_attendance')
      .select('id, status, check_in_time')
      .eq('session_id', sessionId)
      .eq('employee_id', empId)
      .maybeSingle();

  if (existing != null && existing['check_in_time'] != null) {
    // Already checked in - must use correction endpoint per 21 CFR §11.10
    return ErrorResponse.conflict(
      'Attendance already recorded. Use POST /sessions/:id/attendance/:empId/correct for corrections.'
    ).toResponse();
  }

  final now = DateTime.now().toUtc();

  if (existing != null) {
    // Update existing row (not yet checked in)
    final result = await supabase
        .from('session_attendance')
        .update({
          'status': body['status'] ?? 'present',
          'check_in_time': body['check_in_time'] ?? now.toIso8601String(),
          'marked_by': auth.employeeId,
          'updated_at': now.toIso8601String(),
        })
        .eq('id', existing['id'])
        .select()
        .single();

    await supabase.from('audit_trails').insert({
      'entity_type': 'session_attendance',
      'entity_id': existing['id'],
      'action': 'MARK_ATTENDANCE',
      'performed_by': auth.employeeId,
      'changes': body,
      'org_id': auth.orgId,
    });

    return ApiResponse.ok(result).toResponse();
  }

  // Create new attendance record
  final result = await supabase.from('session_attendance').insert({
    'session_id': sessionId,
    'employee_id': empId,
    'status': body['status'] ?? 'present',
    'check_in_time': body['check_in_time'] ?? now.toIso8601String(),
    'marked_by': auth.employeeId,
    'org_id': auth.orgId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'session_attendance',
    'entity_id': result['id'],
    'action': 'CREATE_ATTENDANCE',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}

/// POST /v1/train/sessions/:id/attendance/:empId/correct - Correct attendance
/// Reference: 21 CFR §11.10 immutability - creates correction record, doesn't modify original
Future<Response> attendanceCorrectionHandler(Request req, String sessionId, String empId) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sessions.correct_attendance',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final reason = body['reason'] as String?;
  if (reason == null || reason.trim().isEmpty) {
    return ErrorResponse.validation({'reason': 'Correction reason is required'}).toResponse();
  }

  // Find original attendance record
  final original = await supabase
      .from('session_attendance')
      .select('id, status, check_in_time, check_out_time, attendance_percentage')
      .eq('session_id', sessionId)
      .eq('employee_id', empId)
      .maybeSingle();

  if (original == null) {
    return ErrorResponse.notFound('Original attendance record not found').toResponse();
  }

  // Create correction record (immutable audit trail)
  final result = await supabase.from('attendance_corrections').insert({
    'original_attendance_id': original['id'],
    'session_id': sessionId,
    'employee_id': empId,
    'corrected_by': auth.employeeId,
    'correction_reason': reason,
    'original_status': original['status'],
    'corrected_status': body['corrected_status'],
    'original_check_in': original['check_in_time'],
    'corrected_check_in': body['corrected_check_in'],
    'original_check_out': original['check_out_time'],
    'corrected_check_out': body['corrected_check_out'],
    'original_percentage': original['attendance_percentage'],
    'corrected_percentage': body['corrected_percentage'],
    'org_id': auth.orgId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'attendance_corrections',
    'entity_id': result['id'],
    'action': 'CREATE_CORRECTION',
    'performed_by': auth.employeeId,
    'changes': {
      'original_attendance_id': original['id'],
      'reason': reason,
      'corrections': body,
    },
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}

/// POST /v1/train/sessions/:id/mark-attendance - Bulk mark attendance
Future<Response> sessionAttendanceBulkHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'sessions.mark_attendance',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;
  final attendanceList = body['attendance'] as List? ?? [];

  if (attendanceList.isEmpty) {
    return ErrorResponse.validation({'attendance': 'attendance array is required'}).toResponse();
  }

  final now = DateTime.now().toUtc();
  final insertData = attendanceList.map((a) => {
    'session_id': id,
    'employee_id': a['employee_id'],
    'status': a['status'] ?? 'present',
    'check_in_time': a['check_in_time'] ?? now.toIso8601String(),
    'marked_by': auth.employeeId,
    'org_id': auth.orgId,
  }).toList();

  await supabase.from('session_attendance').upsert(
    insertData,
    onConflict: 'session_id,employee_id',
    ignoreDuplicates: false,
  );

  await supabase.from('audit_trails').insert({
    'entity_type': 'training_sessions',
    'entity_id': id,
    'action': 'BULK_MARK_ATTENDANCE',
    'performed_by': auth.employeeId,
    'changes': {'marked_count': attendanceList.length},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok({
    'session_id': id,
    'marked_count': attendanceList.length,
  }).toResponse();
}
