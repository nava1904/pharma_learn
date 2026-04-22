import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/sessions/:id/complete
///
/// Marks a training session as complete and generates training records.
/// Implements:
/// - 80% attendance threshold (Alfa §4.3.19)
/// - Blended session rules (Alfa §4.3.13) - requires both ILT + WBT completion
/// - Certificate generation trigger
Future<Response> sessionCompleteHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check - trainer or coordinator
  final canComplete = auth.hasPermission('training.sessions.manage') ||
      auth.hasPermission('training.manage');
  if (!canComplete) {
    throw PermissionDeniedException('Trainer or coordinator access required');
  }

  // Get session with schedule details
  final session = await supabase
      .from('training_sessions')
      .select('''
        id, status, session_date, start_time, end_time,
        schedule_id, organization_id,
        training_schedules!inner(
          id, schedule_type, course_id, blended_wbt_deadline_days,
          courses!inner(id, title, course_type, certificate_template_id)
        )
      ''')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Session not found');
  }

  if (session['status'] == 'completed') {
    throw ConflictException('Session is already completed');
  }

  if (session['status'] != 'in_progress') {
    throw ConflictException('Session must be in progress to complete');
  }

  final schedule = session['training_schedules'] as Map<String, dynamic>;
  final course = schedule['courses'] as Map<String, dynamic>;
  final scheduleType = schedule['schedule_type'] as String;
  final isBlended = scheduleType == 'blended';
  final courseId = course['id'] as String;
  final orgId = session['organization_id'] as String;

  // Get all attendance records for this session
  final attendanceRecords = await supabase
      .from('session_attendance')
      .select('''
        id, employee_id, check_in_time, check_out_time,
        attendance_percentage, attendance_status
      ''')
      .eq('session_id', sessionId);

  final now = DateTime.now().toUtc();
  final results = <Map<String, dynamic>>[];
  int recordsCreated = 0;
  int partialRecords = 0;
  int blendedPending = 0;

  for (final attendance in attendanceRecords) {
    final employeeId = attendance['employee_id'] as String;
    final attendancePercentage = attendance['attendance_percentage'] as num? ?? 0;

    // 80% threshold check (Alfa §4.3.19)
    final isAttended = attendancePercentage >= 80;

    if (!isAttended) {
      // Mark as PARTIAL - does NOT generate training record
      await supabase.from('session_attendance').update({
        'attendance_status': 'partial',
        'finalized_at': now.toIso8601String(),
      }).eq('id', attendance['id']);

      partialRecords++;
      results.add({
        'employee_id': employeeId,
        'status': 'partial',
        'attendance_percentage': attendancePercentage,
        'reason': 'Below 80% attendance threshold',
      });
      continue;
    }

    // For blended sessions, check WBT completion (Alfa §4.3.13)
    if (isBlended) {
      final wbtProgress = await supabase
          .from('learning_progress')
          .select('id, status, completed_at')
          .eq('employee_id', employeeId)
          .eq('course_id', courseId)
          .maybeSingle();

      final wbtCompleted = wbtProgress?['status'] == 'completed';

      if (!wbtCompleted) {
        // ILT attended but WBT not completed - create pending obligation
        final wbtDeadlineDays = schedule['blended_wbt_deadline_days'] as int? ?? 14;
        final wbtDeadline = now.add(Duration(days: wbtDeadlineDays));

        // Check if WBT obligation already exists
        final existingWbtObligation = await supabase
            .from('employee_training_obligations')
            .select('id')
            .eq('employee_id', employeeId)
            .eq('course_id', courseId)
            .eq('obligation_type', 'blended_wbt')
            .maybeSingle();

        if (existingWbtObligation == null) {
          await supabase.from('employee_training_obligations').insert({
            'employee_id': employeeId,
            'course_id': courseId,
            'organization_id': orgId,
            'status': 'pending',
            'obligation_type': 'blended_wbt',
            'due_date': wbtDeadline.toIso8601String(),
            'source_session_id': sessionId,
            'assignment_type': 'blended_completion',
          });
        }

        // Mark ILT as attended but blended pending
        await supabase.from('session_attendance').update({
          'attendance_status': 'attended',
          'blended_wbt_pending': true,
          'finalized_at': now.toIso8601String(),
        }).eq('id', attendance['id']);

        blendedPending++;
        results.add({
          'employee_id': employeeId,
          'status': 'blended_pending',
          'attendance_percentage': attendancePercentage,
          'reason': 'WBT component not yet completed',
          'wbt_deadline': wbtDeadline.toIso8601String(),
        });
        continue;
      }
    }

    // Employee has met all requirements - create training record
    await supabase.from('session_attendance').update({
      'attendance_status': 'attended',
      'finalized_at': now.toIso8601String(),
    }).eq('id', attendance['id']);

    // Create training record
    final trainingRecord = await _createTrainingRecord(
      supabase: supabase,
      employeeId: employeeId,
      courseId: courseId,
      orgId: orgId,
      sessionId: sessionId,
      completedAt: now,
      completedBy: auth.employeeId,
      isBlended: isBlended,
    );

    recordsCreated++;
    results.add({
      'employee_id': employeeId,
      'status': 'completed',
      'attendance_percentage': attendancePercentage,
      'training_record_id': trainingRecord['id'],
    });

    // Trigger certificate generation if template configured
    if (course['certificate_template_id'] != null) {
      await _triggerCertificateGeneration(
        supabase: supabase,
        trainingRecordId: trainingRecord['id'] as String,
        employeeId: employeeId,
        courseId: courseId,
        orgId: orgId,
      );
    }
  }

  // Update session status
  await supabase.from('training_sessions').update({
    'status': 'completed',
    'completed_at': now.toIso8601String(),
    'completed_by': auth.employeeId,
  }).eq('id', sessionId);

  // Publish completion event
  await EventPublisher.publish(
    supabase,
    eventType: 'training.session_completed',
    aggregateType: 'training_session',
    aggregateId: sessionId,
    orgId: orgId,
    payload: {
      'session_id': sessionId,
      'records_created': recordsCreated,
      'partial_records': partialRecords,
      'blended_pending': blendedPending,
    },
  );

  return ApiResponse.ok({
    'session_id': sessionId,
    'status': 'completed',
    'completed_at': now.toIso8601String(),
    'summary': {
      'total_attendees': attendanceRecords.length,
      'records_created': recordsCreated,
      'partial_records': partialRecords,
      'blended_pending': blendedPending,
    },
    'results': results,
  }).toResponse();
}

/// Creates a training record for a completed training.
Future<Map<String, dynamic>> _createTrainingRecord({
  required dynamic supabase,
  required String employeeId,
  required String courseId,
  required String orgId,
  required String sessionId,
  required DateTime completedAt,
  required String completedBy,
  required bool isBlended,
}) async {
  // Check for existing record (idempotency)
  final existing = await supabase
      .from('training_records')
      .select('id')
      .eq('employee_id', employeeId)
      .eq('course_id', courseId)
      .eq('session_id', sessionId)
      .maybeSingle();

  if (existing != null) {
    return existing;
  }

  final record = await supabase.from('training_records').insert({
    'employee_id': employeeId,
    'course_id': courseId,
    'organization_id': orgId,
    'session_id': sessionId,
    'overall_status': 'completed',
    'completed_at': completedAt.toIso8601String(),
    'completion_method': isBlended ? 'blended' : 'classroom',
    'recorded_by': completedBy,
  }).select().single();

  return record;
}

/// Triggers certificate generation via edge function.
Future<void> _triggerCertificateGeneration({
  required dynamic supabase,
  required String trainingRecordId,
  required String employeeId,
  required String courseId,
  required String orgId,
}) async {
  // Publish event for certificate generation
  await EventPublisher.publish(
    supabase,
    eventType: 'certificate.generation_requested',
    aggregateType: 'training_record',
    aggregateId: trainingRecordId,
    orgId: orgId,
    payload: {
      'training_record_id': trainingRecordId,
      'employee_id': employeeId,
      'course_id': courseId,
    },
  );
}

/// POST /v1/train/sessions/:id/start
///
/// Marks a training session as in progress.
Future<Response> sessionStartHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check
  final canStart = auth.hasPermission('training.sessions.manage') ||
      auth.hasPermission('training.manage');
  if (!canStart) {
    throw PermissionDeniedException('Trainer or coordinator access required');
  }

  // Get session
  final session = await supabase
      .from('training_sessions')
      .select('id, status, session_date, organization_id')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Session not found');
  }

  if (session['status'] != 'scheduled') {
    throw ConflictException('Session must be scheduled to start');
  }

  final now = DateTime.now().toUtc();

  // Update session
  await supabase.from('training_sessions').update({
    'status': 'in_progress',
    'actual_start_time': now.toIso8601String(),
    'started_by': auth.employeeId,
  }).eq('id', sessionId);

  return ApiResponse.ok({
    'session_id': sessionId,
    'status': 'in_progress',
    'started_at': now.toIso8601String(),
  }).toResponse();
}

/// POST /v1/train/sessions/:id/cancel
///
/// Cancels a scheduled training session.
Future<Response> sessionCancelHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Permission check
  final canCancel = auth.hasPermission('training.sessions.manage') ||
      auth.hasPermission('training.manage');
  if (!canCancel) {
    throw PermissionDeniedException('Trainer or coordinator access required');
  }

  final reason = body['reason'] as String?;
  if (reason == null || reason.isEmpty) {
    throw ValidationException({'reason': 'Cancellation reason is required'});
  }

  // Get session
  final session = await supabase
      .from('training_sessions')
      .select('id, status, organization_id')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Session not found');
  }

  if (session['status'] == 'completed') {
    throw ConflictException('Cannot cancel a completed session');
  }

  if (session['status'] == 'cancelled') {
    throw ConflictException('Session is already cancelled');
  }

  final now = DateTime.now().toUtc();

  // Update session
  await supabase.from('training_sessions').update({
    'status': 'cancelled',
    'cancelled_at': now.toIso8601String(),
    'cancelled_by': auth.employeeId,
    'cancellation_reason': reason,
  }).eq('id', sessionId);

  // Notify enrolled attendees
  await EventPublisher.publish(
    supabase,
    eventType: 'training.session_cancelled',
    aggregateType: 'training_session',
    aggregateId: sessionId,
    orgId: session['organization_id'] as String,
    payload: {
      'session_id': sessionId,
      'reason': reason,
    },
  );

  return ApiResponse.ok({
    'session_id': sessionId,
    'status': 'cancelled',
    'cancelled_at': now.toIso8601String(),
    'reason': reason,
  }).toResponse();
}
