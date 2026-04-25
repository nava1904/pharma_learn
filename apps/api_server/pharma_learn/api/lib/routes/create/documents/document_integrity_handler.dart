import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/documents/:id/integrity
///
/// Verifies the integrity of all electronic signatures attached to this
/// document via the `verify_esignature_integrity` DB function.
/// Admin / QA use only.
Future<Response> documentIntegrityHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewDocuments,
    jwtPermissions: auth.permissions,
  );

  final exists = await supabase
      .from('documents')
      .select('id, name')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (exists == null) throw NotFoundException('Document not found');

  // Fetch all signatures for this document
  final signatures = await supabase
      .from('electronic_signatures')
      .select('id, meaning, meaning_display, employee_name, timestamp, is_valid')
      .eq('entity_type', 'document')
      .eq('entity_id', id)
      .order('timestamp', ascending: true);

  // Verify each signature's integrity hash
  final results = <Map<String, dynamic>>[];
  var allValid = true;

  for (final sig in signatures as List) {
    final verifyResult = await supabase
        .rpc('verify_esignature_integrity', params: {'p_esig_id': sig['id']})
        .select()
        .single();

    final isValid = verifyResult['is_valid'] as bool? ?? false;
    if (!isValid) allValid = false;

    results.add({
      'signature_id': sig['id'],
      'meaning': sig['meaning_display'],
      'signer': sig['employee_name'],
      'signed_at': sig['timestamp'],
      'is_valid': isValid,
      'verification_status': verifyResult['verification_status'],
    });
  }

  return ApiResponse.ok({
    'document_id': id,
    'document_name': exists['name'],
    'all_signatures_valid': allValid,
    'signature_count': results.length,
    'signatures': results,
  }).toResponse();
}
