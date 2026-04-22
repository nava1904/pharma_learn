import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// DELETE /v1/create/documents/:id
///
/// Deletes a document. Only allowed for documents in DRAFT status.
/// Per create_plan.md §document-delete, non-draft documents return 409.
///
/// 21 CFR §11.10 — approved/effective documents are immutable.
Future<Response> documentDeleteHandler(Request req) async {
  final docId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.deleteDocuments,
    jwtPermissions: auth.permissions,
  );

  // Load document
  final doc = await supabase
      .from('documents')
      .select('id, status, title, created_by')
      .eq('id', docId)
      .maybeSingle();

  if (doc == null) {
    throw NotFoundException('Document not found');
  }

  // Only drafts can be deleted
  if (doc['status'] != 'draft') {
    throw ConflictException(
      'Cannot delete document in ${doc['status']} status. Only draft documents can be deleted.',
    );
  }

  // Only creator or admin can delete
  if (doc['created_by'] != auth.employeeId) {
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.approveDocuments, // Admin-level permission
      jwtPermissions: auth.permissions,
    );
  }

  // Delete associated records first (cascade not automatic in Supabase)
  await supabase.from('document_attachments').delete().eq('document_id', docId);
  await supabase.from('document_versions').delete().eq('document_id', docId);

  // Delete the document
  await supabase.from('documents').delete().eq('id', docId);

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'document',
    'entity_id': docId,
    'action': 'DELETE',
    'event_category': 'DOCUMENT_DELETED',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'old_values': {'title': doc['title'], 'status': doc['status']},
  });

  return ApiResponse.noContent().toResponse();
}
