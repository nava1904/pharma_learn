import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/consent/:id/withdraw - Withdraw a consent
Future<Response> consentWithdrawHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final bodyStr = await req.readAsString();
  final body = bodyStr.isEmpty ? <String, dynamic>{} : jsonDecode(bodyStr) as Map<String, dynamic>;
  final reason = body['reason'] as String?;

  // Verify consent exists and belongs to user
  final existing = await supabase
      .from('consents')
      .select('id, employee_id, consent_type, status')
      .eq('id', id)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Consent not found').toResponse();
  }

  // Only the consent owner can withdraw
  if (existing['employee_id'] != auth.employeeId) {
    return ErrorResponse.permissionDenied('Not authorized to withdraw this consent').toResponse();
  }

  if (existing['status'] != 'granted') {
    return ErrorResponse.conflict('Only granted consents can be withdrawn').toResponse();
  }

  final result = await supabase
      .from('consents')
      .update({
        'status': 'withdrawn',
        'withdrawn_at': DateTime.now().toUtc().toIso8601String(),
        'withdrawal_reason': reason,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  await supabase.from('audit_trails').insert({
    'entity_type': 'consents',
    'entity_id': id,
    'action': 'WITHDRAW',
    'performed_by': auth.employeeId,
    'changes': {
      'consent_type': existing['consent_type'],
      'reason': reason,
    },
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
