import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/documents/:id/reject   [requires withEsig wrapper]
///
/// Returns the document for correction (Learn-IQ: 'return' decision).
/// Document transitions pending_approval → returned.
///
/// Body: `{e_signature: {reauth_session_id, meaning:'rejected', reason, is_first_in_session},
///         comments, standard_reason_id?}`
///
/// Note: the API uses the term "reject" (user-facing) but the DB stores
/// the approval_decision as 'return' (the Learn-IQ lifecycle term for
/// "return for correction"). Use `drop` only when abandoning changes entirely.
Future<Response> documentRejectHandler(Request req) async {
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

  // 1. Find the pending approval
  final approval = await supabase
      .from('pending_approvals')
      .select()
      .eq('entity_type', 'document')
      .eq('entity_id', id)
      .eq('status', 'pending')
      .maybeSingle();

  if (approval == null) throw NotFoundException('No pending approval found for this document');

  // 2. Learn-IQ level check
  final canApprove = await supabase.rpc('can_user_approve', params: {
    'p_approval_id': approval['id'],
    'p_user_id': auth.employeeId,
  }) as bool? ?? false;

  if (!canApprove) {
    throw PermissionDeniedException(
      'Not authorized to reject/return. Your role level must be lower (higher authority) '
      'than the initiator\'s level (${approval['initiator_role_level']}).',
    );
  }

  final comments = requireString(body, 'comments');

  // 3. Create e-signature — DB function validates + consumes reauth session
  final esigId = await EsigService(supabase).createEsignature(
    employeeId: auth.employeeId,
    meaning: 'rejected',
    entityType: 'document',
    entityId: id,
    reason: comments,
    reauthSessionId: esig.reauthSessionId,
  );

  // 4. Resolve approval manually — 'return' decision
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

  await supabase.from('pending_approvals').update({
    'status': 'returned',
    'resolved_by': auth.employeeId,
    'resolver_name': resolverName,
    'resolver_role_level': resolverLevel,
    'resolved_at': now,
    'resolution_reason': comments,
    'standard_reason_id': body['standard_reason_id'],
    'esignature_id': esigId,
    'updated_at': now,
  }).eq('id', approval['id'] as String);

  // 5. Update document status to 'returned'
  await supabase.from('documents').update({'status': 'returned'}).eq('id', id);

  // 6. Record in approval_history
  await supabase.from('approval_history').insert({
    'pending_approval_id': approval['id'],
    'action': 'returned',
    'performed_by': auth.employeeId,
    'performer_name': resolverName,
    'performer_role_level': resolverLevel,
    'comments': comments,
    'esignature_id': esigId,
  });

  // 7. Publish event
  await OutboxService(supabase).publish(
    aggregateType: 'document',
    aggregateId: id,
    eventType: EventTypes.documentRejected,
    payload: {
      'rejected_by': auth.employeeId,
      'esig_id': esigId,
      'comments': comments,
      'standard_reason_id': body['standard_reason_id'],
    },
    orgId: auth.orgId,
  );

  final updated = await supabase.from('documents').select().eq('id', id).single();

  return ApiResponse.ok({'document': updated, 'esig_id': esigId}).toResponse();
}
