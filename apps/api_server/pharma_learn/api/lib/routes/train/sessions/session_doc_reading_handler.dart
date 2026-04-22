import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/sessions/:id/doc-reading/offline
///
/// Coordinator bulk-marks employees as having read document offline.
/// Body: { employee_ids: [], completed_at?, document_id, evidence_reference? }
Future<Response> sessionDocReadingOfflineHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to record offline document reading');
  }

  if (sessionId == null || sessionId.isEmpty) {
    throw ValidationException({'id': 'Session ID is required'});
  }

  final employeeIds = body['employee_ids'] as List<dynamic>?;
  if (employeeIds == null || employeeIds.isEmpty) {
    throw ValidationException({'employee_ids': 'At least one employee ID is required'});
  }
  final documentId = requireUuid(body, 'document_id');
  final evidenceReference = body['evidence_reference'] as String?;
  final completedAtStr = body['completed_at'] as String?;

  // Parse completed_at or use now
  DateTime completedAt = DateTime.now().toUtc();
  if (completedAtStr != null) {
    completedAt = DateTime.tryParse(completedAtStr) ?? completedAt;
  }

  // Verify session exists
  final session = await supabase
      .from('training_sessions')
      .select('id, batch_id, organization_id')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Session not found');
  }

  // Verify document exists
  final document = await supabase
      .from('documents')
      .select('id, title, version')
      .eq('id', documentId)
      .maybeSingle();

  if (document == null) {
    throw NotFoundException('Document not found');
  }

  // Process each employee
  final results = <Map<String, dynamic>>[];
  final errors = <Map<String, dynamic>>[];

  for (final employeeId in employeeIds) {
    try {
      // Verify employee is enrolled in session
      final enrollment = await supabase
          .from('session_attendance')
          .select('id')
          .eq('session_id', sessionId)
          .eq('employee_id', employeeId)
          .maybeSingle();

      if (enrollment == null) {
        errors.add({
          'employee_id': employeeId,
          'error': 'Employee not enrolled in session',
        });
        continue;
      }

      // Check if already completed
      final existingProgress = await supabase
          .from('learning_progress')
          .select('id, status')
          .eq('employee_id', employeeId)
          .eq('content_id', documentId)
          .eq('content_type', 'document')
          .maybeSingle();

      if (existingProgress != null && existingProgress['status'] == 'completed') {
        errors.add({
          'employee_id': employeeId,
          'error': 'Document reading already completed',
        });
        continue;
      }

      // Upsert content_view_tracking
      await supabase.from('content_view_tracking').upsert({
        'employee_id': employeeId,
        'content_type': 'document',
        'content_id': documentId,
        'session_id': sessionId,
        'view_type': 'offline',
        'started_at': completedAt.toIso8601String(),
        'completed_at': completedAt.toIso8601String(),
        'evidence_reference': evidenceReference,
        'recorded_by': auth.employeeId,
        'organization_id': auth.orgId,
      }, onConflict: 'employee_id,content_type,content_id');

      // Upsert learning_progress
      if (existingProgress != null) {
        await supabase
            .from('learning_progress')
            .update({
              'status': 'completed',
              'progress_percent': 100,
              'completed_at': completedAt.toIso8601String(),
              'completion_method': 'offline',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', existingProgress['id']);
      } else {
        await supabase.from('learning_progress').insert({
          'employee_id': employeeId,
          'content_type': 'document',
          'content_id': documentId,
          'session_id': sessionId,
          'status': 'completed',
          'progress_percent': 100,
          'started_at': completedAt.toIso8601String(),
          'completed_at': completedAt.toIso8601String(),
          'completion_method': 'offline',
          'organization_id': auth.orgId,
        });
      }

      results.add({
        'employee_id': employeeId,
        'status': 'completed',
      });
    } catch (e) {
      errors.add({
        'employee_id': employeeId,
        'error': e.toString(),
      });
    }
  }

  // Log audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'document_reading_offline',
    'entity_id': sessionId,
    'action': 'bulk_complete',
    'actor_id': auth.employeeId,
    'organization_id': auth.orgId,
    'changes': {
      'document_id': documentId,
      'employee_count': results.length,
      'completed_at': completedAt.toIso8601String(),
      'evidence_reference': evidenceReference,
    },
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  return ApiResponse.ok({
    'success_count': results.length,
    'error_count': errors.length,
    'results': results,
    'errors': errors,
    'document': {
      'id': document['id'],
      'title': document['title'],
      'version': document['version'],
    },
  }).toResponse();
}

/// POST /v1/train/sessions/:id/doc-reading/terminate
///
/// Admin terminates in-progress document reading assignments.
/// Body: { employee_ids: [], reason }
Future<Response> sessionDocReadingTerminateHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to terminate document reading');
  }

  if (sessionId == null || sessionId.isEmpty) {
    throw ValidationException({'id': 'Session ID is required'});
  }

  final employeeIds = body['employee_ids'] as List<dynamic>?;
  if (employeeIds == null || employeeIds.isEmpty) {
    throw ValidationException({'employee_ids': 'At least one employee ID is required'});
  }
  final reason = requireString(body, 'reason');

  int terminatedCount = 0;

  for (final employeeId in employeeIds) {
    // Update learning_progress
    final updateResult = await supabase
        .from('learning_progress')
        .update({
          'status': 'terminated',
          'termination_reason': reason,
          'terminated_by': auth.employeeId,
          'terminated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('session_id', sessionId)
        .eq('employee_id', employeeId)
        .eq('status', 'in_progress')
        .select();

    terminatedCount += (updateResult as List).length;

    // Update content_view_tracking
    await supabase
        .from('content_view_tracking')
        .update({
          'terminated': true,
          'termination_reason': reason,
          'terminated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('session_id', sessionId)
        .eq('employee_id', employeeId);
  }

  // Log audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'document_reading',
    'entity_id': sessionId,
    'action': 'bulk_terminate',
    'actor_id': auth.employeeId,
    'organization_id': auth.orgId,
    'changes': {
      'employee_ids': employeeIds,
      'reason': reason,
      'terminated_count': terminatedCount,
    },
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });

  return ApiResponse.ok({
    'message': 'Document reading assignments terminated',
    'terminated_count': terminatedCount,
  }).toResponse();
}
