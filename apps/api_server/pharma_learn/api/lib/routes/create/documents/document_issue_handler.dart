import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/documents/:id/issue-copy
///
/// Issues a controlled copy of a document.
/// Alfa A-SOP-QA-015 - Controlled copy management.
Future<Response> documentIssueCopyHandler(Request req) async {
  final docId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('documents.issue_copy')) {
    throw PermissionDeniedException('You do not have permission to issue document copies');
  }

  // Verify document exists and is approved
  final doc = await supabase
      .from('documents')
      .select('id, title, version, status, storage_path')
      .eq('id', docId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (doc == null) throw NotFoundException('Document not found');
  if (doc['status'] != 'approved' && doc['status'] != 'effective') {
    throw ConflictException('Only approved documents can have controlled copies issued');
  }

  final recipientId = body['recipient_id'] as String?;
  final copyType = body['copy_type'] as String? ?? 'controlled';
  final expiryDate = body['expiry_date'] as String?;
  final notes = body['notes'] as String?;

  if (recipientId == null) {
    throw ValidationException({'recipient_id': 'Recipient ID is required'});
  }

  // Generate copy number
  final existingCopies = await supabase
      .from('document_copies')
      .select('copy_number')
      .eq('document_id', docId)
      .order('copy_number', ascending: false)
      .limit(1)
      .maybeSingle();

  final copyNumber = (existingCopies?['copy_number'] as int? ?? 0) + 1;
  final now = DateTime.now().toUtc().toIso8601String();

  final copy = await supabase
      .from('document_copies')
      .insert({
        'document_id': docId,
        'copy_number': copyNumber,
        'copy_type': copyType,
        'issued_to': recipientId,
        'issued_by': auth.employeeId,
        'issued_at': now,
        'expiry_date': expiryDate,
        'status': 'active',
        'notes': notes,
        'organization_id': auth.orgId,
      })
      .select()
      .single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'document_copy',
    'entity_id': copy['id'],
    'action': 'COPY_ISSUED',
    'event_category': 'DOCUMENT',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'document_id': docId,
      'copy_number': copyNumber,
      'recipient_id': recipientId,
      'copy_type': copyType,
    }),
  });

  // Notify recipient
  await supabase.from('notifications').insert({
    'employee_id': recipientId,
    'type': 'document_copy_issued',
    'title': 'Controlled Document Copy Issued',
    'message': 'You have been issued a controlled copy of "${doc['title']}" (Copy #$copyNumber)',
    'data': jsonEncode({
      'document_id': docId,
      'copy_id': copy['id'],
      'copy_number': copyNumber,
    }),
    'created_at': now,
  });

  return ApiResponse.created({
    'copy': copy,
    'document_title': doc['title'],
  }).toResponse();
}
