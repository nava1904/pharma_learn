import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/courses/:id/approve   [requires withEsig wrapper]
///
/// Body: `{e_signature: {...}, comments?}`
Future<Response> courseApproveHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final esig = RequestContext.esig!;
  final body = RequestContext.body ?? await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId, Permissions.approveCourses, jwtPermissions: auth.permissions,
  );

  final approval = await supabase
      .from('pending_approvals')
      .select()
      .eq('entity_type', 'course')
      .eq('entity_id', id)
      .eq('status', 'pending')
      .maybeSingle();

  if (approval == null) throw NotFoundException('No pending approval found for this course');

  final canApprove = await supabase.rpc('can_user_approve', params: {
    'p_approval_id': approval['id'],
    'p_user_id': auth.employeeId,
  }) as bool? ?? false;

  if (!canApprove) {
    throw PermissionDeniedException(
      'Not authorized to approve. Your role level must be lower than initiator\'s level (${approval['initiator_role_level']}).',
    );
  }

  final esigId = await EsigService(supabase).createEsignature(
    employeeId: auth.employeeId,
    meaning: 'approved',
    entityType: 'course',
    entityId: id,
    reason: body['comments'] as String?,
    reauthSessionId: esig.reauthSessionId,
  );

  final resolverRow = await supabase.from('employees').select('first_name, last_name').eq('id', auth.employeeId).single();
  final resolverName = '${resolverRow['first_name']} ${resolverRow['last_name']}';

  final resolverLevelRow = await supabase
      .from('employee_roles').select('roles!inner(level)').eq('employee_id', auth.employeeId)
      .order('roles(level)', ascending: true).limit(1).maybeSingle();
  final resolverLevel = (resolverLevelRow?['roles'] as Map?)?['level'] as num?;

  final now = DateTime.now().toUtc().toIso8601String();
  final targetState = approval['target_state'] as String? ?? 'active';
  final newEntityState = targetState == 'approved' ? 'active' : targetState;

  await supabase.from('pending_approvals').update({
    'status': 'approved',
    'resolved_by': auth.employeeId,
    'resolver_name': resolverName,
    'resolver_role_level': resolverLevel,
    'resolved_at': now,
    'resolution_reason': body['comments'],
    'esignature_id': esigId,
    'updated_at': now,
  }).eq('id', approval['id'] as String);

  await supabase.from('courses').update({
    'status': newEntityState,
    'approved_at': now,
    'approved_by': auth.employeeId,
  }).eq('id', id);

  await supabase.from('approval_history').insert({
    'pending_approval_id': approval['id'],
    'action': 'approved',
    'performed_by': auth.employeeId,
    'performer_name': resolverName,
    'performer_role_level': resolverLevel,
    'comments': body['comments'],
    'esignature_id': esigId,
  });

  await OutboxService(supabase).publish(
    aggregateType: 'course',
    aggregateId: id,
    eventType: EventTypes.courseApproved,
    payload: {'approved_by': auth.employeeId, 'esig_id': esigId},
    orgId: auth.orgId,
  );

  final updated = await supabase.from('courses').select().eq('id', id).single();
  return ApiResponse.ok({'course': updated, 'esig_id': esigId}).toResponse();
}
