import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/documents/:id/readings/:readingId/acknowledge   [requires withEsig wrapper]
///
/// Completes a document reading via the `complete_document_reading` DB function.
/// E-signature is mandatory per URS §4.2.1.34 and enforced by a DB CHECK constraint.
///
/// Body: `{e_signature: {reauth_session_id, meaning:'acknowledged', reason?, is_first_in_session},
///         time_spent_minutes?, pages_viewed?}`
Future<Response> documentReadingAckHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final readingId = parsePathUuid(req.rawPathParameters[#readingId], fieldName: 'readingId');
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final esig = RequestContext.esig!;
  final body = RequestContext.body ?? await readJson(req);

  // Verify reading belongs to the calling employee (or manager override)
  final reading = await supabase
      .from('document_readings')
      .select('id, document_id, employee_id, status, organization_id')
      .eq('id', readingId)
      .eq('document_id', id)
      .maybeSingle();

  if (reading == null) throw NotFoundException('Document reading not found');
  if (reading['organization_id'] != auth.orgId) {
    throw PermissionDeniedException('Reading does not belong to your organisation');
  }

  // Employee can only acknowledge their own reading; managers need approveDocuments
  final isOwnReading = reading['employee_id'] == auth.employeeId;
  if (!isOwnReading) {
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.approveDocuments,
      jwtPermissions: auth.permissions,
    );
  }

  final readingStatus = reading['status'] as String? ?? '';
  if (readingStatus == 'COMPLETED') {
    throw ConflictException('Document reading has already been completed');
  }
  if (['WAIVED', 'CANCELLED'].contains(readingStatus)) {
    throw ConflictException(
      'Cannot acknowledge a $readingStatus reading',
    );
  }

  // Create e-signature — DB function validates + consumes reauth session
  final esigId = await EsigService(supabase).createEsignature(
    employeeId: auth.employeeId,
    meaning: 'acknowledged',
    entityType: 'document_reading',
    entityId: readingId,
    reauthSessionId: esig.reauthSessionId,
  );

  // Complete reading via DB RPC — enforces the CHK_ESIG_ON_COMPLETION constraint
  await supabase.rpc('complete_document_reading', params: {
    'p_reading_id': readingId,
    'p_esignature_id': esigId,
    'p_time_spent_minutes': body['time_spent_minutes'],
    'p_pages_viewed': body['pages_viewed'],
  });

  final updated = await supabase
      .from('document_readings')
      .select()
      .eq('id', readingId)
      .single();

  return ApiResponse.ok({'reading': updated, 'esig_id': esigId}).toResponse();
}
