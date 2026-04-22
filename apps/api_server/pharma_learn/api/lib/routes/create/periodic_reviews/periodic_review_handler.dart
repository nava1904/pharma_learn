import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/periodic-reviews/:id - Get periodic review by ID
Future<Response> periodicReviewGetHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;

  final result = await supabase
      .from('periodic_reviews')
      .select('*, document:documents(id, document_number, title)')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    return ErrorResponse.notFound('Periodic review not found').toResponse();
  }

  return ApiResponse.ok(result).toResponse();
}

/// POST /v1/periodic-reviews/:id/complete - Complete periodic review [esig]
/// Reference: Alfa §4.4.8 — periodic review completion
Future<Response> periodicReviewCompleteHandler(Request req, String id) async {
  final supabase = RequestContext.supabase;
  final auth = RequestContext.auth;
  final esig = RequestContext.esig;

  if (esig == null) {
    return ErrorResponse.esigRequired('E-signature required to complete periodic review').toResponse();
  }

  await PermissionChecker(supabase).require(
    auth.employeeId,
    'periodic_reviews.complete',
    jwtPermissions: auth.permissions,
  );

  // Verify review exists and is pending
  final existing = await supabase
      .from('periodic_reviews')
      .select('id, status, document_id')
      .eq('id', id)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    return ErrorResponse.notFound('Periodic review not found').toResponse();
  }

  if (existing['status'] != 'pending' && existing['status'] != 'overdue') {
    return ErrorResponse.conflict('Review is not in a completable status').toResponse();
  }

  final bodyStr = await req.readAsString();
  final body = bodyStr.isEmpty ? <String, dynamic>{} : jsonDecode(bodyStr) as Map<String, dynamic>;

  final outcome = body['outcome'] as String?;
  final comments = body['comments'] as String?;

  if (outcome == null || !['no_change', 'revision_required', 'retire'].contains(outcome)) {
    return ErrorResponse.validation({
      'outcome': 'outcome must be no_change, revision_required, or retire'
    }).toResponse();
  }

  // Create e-signature record
  final esigResult = await supabase.from('electronic_signatures').insert({
    'employee_id': auth.employeeId,
    'entity_type': 'periodic_reviews',
    'entity_id': id,
    'meaning': 'COMPLETE_REVIEW',
    'reason': esig.reason,
    'signed_at': DateTime.now().toUtc().toIso8601String(),
    'org_id': auth.orgId,
  }).select().single();

  // Update periodic review
  final result = await supabase
      .from('periodic_reviews')
      .update({
        'status': 'completed',
        'outcome': outcome,
        'comments': comments,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'completed_by': auth.employeeId,
        'esignature_id': esigResult['id'],
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id)
      .select()
      .single();

  // Schedule next review if applicable
  if (outcome == 'no_change') {
    // Get review schedule settings
    final settings = await supabase
        .from('system_settings')
        .select('value')
        .eq('key', 'periodic_review_interval_months')
        .maybeSingle();

    final intervalMonths = int.tryParse(settings?['value']?.toString() ?? '12') ?? 12;
    final nextDue = DateTime.now().add(Duration(days: intervalMonths * 30));

    await supabase.from('periodic_reviews').insert({
      'document_id': existing['document_id'],
      'due_date': nextDue.toIso8601String().split('T').first,
      'status': 'pending',
      'org_id': auth.orgId,
      'created_by': auth.employeeId,
    });
  }

  await supabase.from('audit_trails').insert({
    'entity_type': 'periodic_reviews',
    'entity_id': id,
    'action': 'COMPLETE',
    'performed_by': auth.employeeId,
    'changes': {'outcome': outcome, 'esignature_id': esigResult['id']},
    'org_id': auth.orgId,
  });

  return ApiResponse.ok(result).toResponse();
}
