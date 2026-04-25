import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/documents/:id/approve   [requires withEsig wrapper]
///
/// Approves the pending approval for this document (Learn-IQ: 'approve' decision).
/// The document transitions pending_approval → active.
///
/// Body: `{e_signature: {reauth_session_id, meaning:'approved', reason?, is_first_in_session}, comments?}`
///
/// The `resolve_approval()` RPC uses `get_current_user_id()` which returns a
/// system UUID with the service-role key, so approval logic is implemented
/// manually here.
Future<Response> documentApproveHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final esig = RequestContext.esig!;
  final body = RequestContext.body ?? await readJson(req);

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.approveDocuments,
    jwtPermissions: auth.permissions,
  );

  // 1. Find the pending approval for this document
  final approval = await supabase
      .from('pending_approvals')
      .select()
      .eq('entity_type', 'document')
      .eq('entity_id', id)
      .eq('status', 'pending')
      .maybeSingle();

  if (approval == null) throw NotFoundException('No pending approval found for this document');

  // 2. Learn-IQ level check: can_user_approve takes explicit params — works with service role
  final canApprove = await supabase.rpc('can_user_approve', params: {
    'p_approval_id': approval['id'],
    'p_user_id': auth.employeeId,
  }) as bool? ?? false;

  if (!canApprove) {
    throw PermissionDeniedException(
      'Not authorized to approve. Your role level must be lower (higher authority) '
      'than the initiator\'s level (${approval['initiator_role_level']}).',
    );
  }

  // 3. Create e-signature — DB function validates + consumes reauth session
  final esigId = await EsigService(supabase).createEsignature(
    employeeId: auth.employeeId,
    meaning: 'approved',
    entityType: 'document',
    entityId: id,
    reason: body['comments'] as String?,
    reauthSessionId: esig.reauthSessionId,
  );

  // 4. Resolve the approval manually (mirrors resolve_approval logic)
  final resolverRow = await supabase
      .from('employees')
      .select('first_name, last_name')
      .eq('id', auth.employeeId)
      .single();
  final resolverName = '${resolverRow['first_name']} ${resolverRow['last_name']}';

  final resolverLevelRow = await supabase
      .from('employee_roles')
      .select('roles!inner(level)')
      .eq('employee_id', auth.employeeId)
      .order('roles(level)', ascending: true)
      .limit(1)
      .maybeSingle();
  final resolverLevel =
      (resolverLevelRow?['roles'] as Map?)?['level'] as num?;

  final now = DateTime.now().toUtc().toIso8601String();

  // Determine new entity state: if target_state == 'approved', auto-activate
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

  // 5. Update document status
  await supabase.from('documents').update({
    'status': newEntityState,
    'approved_at': now,
    'approved_by': auth.employeeId,
  }).eq('id', id);

  // 6. Record in approval_history
  await supabase.from('approval_history').insert({
    'pending_approval_id': approval['id'],
    'action': 'approved',
    'performed_by': auth.employeeId,
    'performer_name': resolverName,
    'performer_role_level': resolverLevel,
    'comments': body['comments'],
    'esignature_id': esigId,
  });

  // 7. Publish event
  await OutboxService(supabase).publish(
    aggregateType: 'document',
    aggregateId: id,
    eventType: EventTypes.documentApproved,
    payload: {
      'approved_by': auth.employeeId,
      'esig_id': esigId,
      'new_status': newEntityState,
    },
    orgId: auth.orgId,
  );

  final updated = await supabase
      .from('documents')
      .select()
      .eq('id', id)
      .single();

  return ApiResponse.ok({'document': updated, 'esig_id': esigId}).toResponse();
}
