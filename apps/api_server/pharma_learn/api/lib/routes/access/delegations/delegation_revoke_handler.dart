import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/access/delegations/:id/revoke - Revoke a delegation
/// Reference: Alfa §4.4.6 — unplanned leave delegation management
Future<Response> delegationRevokeHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final bodyStr = await req.readAsString();
  final body = bodyStr.isEmpty ? <String, dynamic>{} : jsonDecode(bodyStr) as Map<String, dynamic>;
  final reason = body['reason'] as String?;

  if (reason == null || reason.trim().isEmpty) {
    return ErrorResponse.validation({'reason': 'Revocation reason is required'}).toResponse();
  }

  // Verify delegation exists and is active
  final existing = await supabase
      .from('delegations')
      .select('id, status, delegator_id')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Delegation not found').toResponse();
  }

  if (existing['status'] != 'active') {
    return ErrorResponse.conflict('Only active delegations can be revoked').toResponse();
  }

  // Only delegator or admin can revoke
  final isAdmin = auth.hasPermission('delegations.admin');
  final isDelegator = existing['delegator_id'] == auth.employeeId;
  
  if (!isAdmin && !isDelegator) {
    return ErrorResponse.permissionDenied('Only the delegator or admin can revoke this delegation').toResponse();
  }

  final result = await supabase
      .from('delegations')
      .update({
        'status': 'revoked',
        'revoked_at': DateTime.now().toUtc().toIso8601String(),
        'revoked_by': auth.employeeId,
        'revocation_reason': reason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'delegations',
    'entity_id': id,
    'action': 'REVOKE',
    'performed_by': auth.employeeId,
    'changes': {'reason': reason},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
