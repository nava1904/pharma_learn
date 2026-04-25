import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/auth/sessions
///
/// Returns all active sessions for the current employee.
Future<Response> sessionsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final sessions = await supabase
      .from('user_sessions')
      .select(
        'id, device_type, ip_address, user_agent, created_at, '
        'last_activity_at, expires_at, revoked_at',
      )
      .eq('employee_id', auth.employeeId)
      .isFilter('revoked_at', null)
      .gt('expires_at', DateTime.now().toUtc().toIso8601String())
      .order('created_at', ascending: false);

  // Mark the current session
  final result = (sessions as List).map((s) {
    return {
      ...Map<String, dynamic>.from(s as Map),
      'is_current': s['id'] == auth.sessionId,
    };
  }).toList();

  return ApiResponse.ok({'sessions': result}).toResponse();
}

/// POST /v1/auth/sessions/:id/revoke
///
/// Revokes a specific session. Employees can only revoke their own sessions.
Future<Response> sessionRevokeHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id];
  if (sessionId == null || sessionId.isEmpty) {
    return ErrorResponse.validation({'id': 'Session ID is required'})
        .toResponse();
  }

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify ownership
  final session = await supabase
      .from('user_sessions')
      .select('id, employee_id')
      .eq('id', sessionId)
      .maybeSingle();

  if (session == null) {
    throw NotFoundException('Session not found');
  }

  if (session['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('Cannot revoke another employee\'s session');
  }

  await supabase.rpc(
    'revoke_user_session',
    params: {'p_session_id': sessionId},
  );

  // Publish event
  try {
    await OutboxService(supabase).publish(
      aggregateType: 'auth',
      aggregateId: auth.employeeId,
      eventType: EventTypes.authSessionRevoked,
      payload: {'session_id': sessionId},
      orgId: auth.orgId,
    );
  } catch (_) {}

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/auth/sessions/revoke-all
///
/// Revokes all sessions for the current employee except the current one.
Future<Response> sessionsRevokeAllHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final exceptCurrent = body['except_current'] as bool? ?? true;

  var query = supabase
      .from('user_sessions')
      .update({
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('employee_id', auth.employeeId)
      .isFilter('revoked_at', null);

  if (exceptCurrent) {
    query = query.neq('id', auth.sessionId);
  }

  await query;

  return ApiResponse.ok({'message': 'Sessions revoked'}).toResponse();
}
