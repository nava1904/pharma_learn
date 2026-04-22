import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/self-learning/assign - Assign self-learning course
Future<Response> selfLearningAssignHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'self_learning.assign',
    jwtPermissions: auth.permissions,
  );

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  final errors = <String, String>{};
  if (body['employee_id'] == null) {
    errors['employee_id'] = 'employee_id is required';
  }
  if (body['course_id'] == null) {
    errors['course_id'] = 'course_id is required';
  }

  if (errors.isNotEmpty) {
    return ErrorResponse.validation(errors).toResponse();
  }

  final result = await supabase.from('self_learning_assignments').insert({
    'employee_id': body['employee_id'],
    'course_id': body['course_id'],
    'due_date': body['due_date'],
    'assigned_by': auth.employeeId,
    'status': 'assigned',
    'org_id': auth.orgId,
  }).select().single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'self_learning_assignments',
    'entity_id': result['id'],
    'action': 'ASSIGN',
    'performed_by': auth.employeeId,
    'changes': body,
    'org_id': auth.orgId,
  });

  return ApiResponse.created(result).toResponse();
}

/// GET /v1/train/self-learning/:id/progress - Get learning progress
Future<Response> selfLearningProgressGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('learning_progress')
      .select('*')
      .eq('assignment_id', id)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (result == null) {
    // Return empty progress
    return ApiResponse.ok({
      'assignment_id': id,
      'progress_percent': 0,
      'status': 'not_started',
    }).toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/train/self-learning/:id/progress - Update learning progress
Future<Response> selfLearningProgressUpdateHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final bodyStr = await req.readAsString();
  if (bodyStr.isEmpty) {
    return ErrorResponse.validation({'body': 'Request body is required'}).toResponse();
  }

  final body = jsonDecode(bodyStr) as Map<String, dynamic>;

  // Check if progress record exists
  final existing = await supabase
      .from('learning_progress')
      .select('id')
      .eq('assignment_id', id)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (existing != null) {
    // Update existing
    final result = await supabase
        .from('learning_progress')
        .update({
          'progress_percent': body['progress_percent'],
          'current_location': body['current_location'],
          'time_spent_seconds': body['time_spent_seconds'],
          'status': body['status'] ?? 'in_progress',
          'last_accessed_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', existing['id'])
        .select()
        .single();

    return ApiResponse.ok(result).toResponse();
  }

  // Create new
  final result = await supabase.from('learning_progress').insert({
    'assignment_id': id,
    'employee_id': auth.employeeId,
    'progress_percent': body['progress_percent'] ?? 0,
    'current_location': body['current_location'],
    'time_spent_seconds': body['time_spent_seconds'] ?? 0,
    'status': body['status'] ?? 'in_progress',
    'started_at': DateTime.now().toUtc().toIso8601String(),
    'last_accessed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  return ApiResponse.created(result).toResponse();
}

/// POST /v1/train/self-learning/:id/complete - Complete self-learning
Future<Response> selfLearningCompleteHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  // Verify assignment exists and belongs to user
  final assignment = await supabase
      .from('self_learning_assignments')
      .select('id, status, employee_id, course_id')
      .eq('id', id)
      .maybeSingle();

  if (assignment == null) {
    return ErrorResponse.notFound('Self-learning assignment not found').toResponse();
  }

  if (assignment['employee_id'] != auth.employeeId) {
    return ErrorResponse.permissionDenied('Cannot complete another user\'s assignment').toResponse();
  }

  if (assignment['status'] == 'completed') {
    return ErrorResponse.conflict('Assignment already completed').toResponse();
  }

  // Update learning progress
  await supabase
      .from('learning_progress')
      .update({
        'status': 'completed',
        'progress_percent': 100,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('assignment_id', id)
      .eq('employee_id', auth.employeeId);

  // Update assignment status
  final result = await supabase
      .from('self_learning_assignments')
      .update({
        'status': 'completed',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  // Publish event for certificate generation
  await OutboxService(supabase).publish(
    aggregateType: 'self_learning_assignments',
    aggregateId: id,
    eventType: 'training.completed',
    payload: {
      'assignment_id': id,
      'employee_id': auth.employeeId,
      'course_id': assignment['course_id'],
      'training_type': 'self_learning',
    },
    orgId: auth.orgId,
  );

  await supabase.from('audit_trails').insert({
    'entity_type': 'self_learning_assignments',
    'entity_id': id,
    'action': 'COMPLETE',
    'performed_by': auth.employeeId,
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
