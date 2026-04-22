import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/certify/waivers
///
/// Employee submits a waiver request for a training obligation.
/// URS §5.1.38: Training waivers with justification.
///
/// Body:
/// ```json
/// {
///   "obligation_id": "uuid",       // employee_training_obligations row
///   "waiver_type": "exemption|deferral|substitution",
///   "waiver_reason": "string",     // short reason
///   "justification": "string",     // detailed justification
///   "effective_from": "2026-05-01",
///   "effective_to": "2026-12-31",  // null for permanent
///   "is_permanent": false,
///   "evidence_attachments": []     // optional file references
/// }
/// ```
Future<Response> waiverCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final obligationId = body['obligation_id'] as String?;
  final waiverType = body['waiver_type'] as String?;
  final waiverReason = (body['waiver_reason'] as String?)?.trim();
  final justification = (body['justification'] as String?)?.trim();
  final effectiveFrom = body['effective_from'] as String?;

  final errors = <String, String>{};
  if (obligationId == null) errors['obligation_id'] = 'Required';
  if (waiverType == null || !['exemption', 'deferral', 'substitution'].contains(waiverType)) {
    errors['waiver_type'] = 'Must be exemption, deferral, or substitution';
  }
  if (waiverReason == null || waiverReason.isEmpty) errors['waiver_reason'] = 'Required';
  if (justification == null || justification.isEmpty) errors['justification'] = 'Required';
  if (effectiveFrom == null) errors['effective_from'] = 'Required';

  if (errors.isNotEmpty) throw ValidationException(errors);

  // Verify the obligation belongs to this employee
  final obligation = await supabase
      .from('employee_training_obligations')
      .select('id, status, organization_id, course_id, document_id, ojt_master_id, assignment_id')
      .eq('id', obligationId!)
      .eq('employee_id', auth.employeeId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (obligation == null) {
    throw NotFoundException('Training obligation not found');
  }

  final obligationStatus = obligation['status'] as String? ?? '';
  if (['completed', 'waived', 'cancelled'].contains(obligationStatus)) {
    throw ConflictException('Cannot request a waiver for an obligation with status "$obligationStatus"');
  }

  // Check for existing pending waiver for this obligation
  final existing = await supabase
      .from('training_waivers')
      .select('id, status')
      .eq('assignment_id', obligationId)
      .eq('employee_id', auth.employeeId)
      .eq('status', 'pending_approval')
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('A pending waiver request already exists for this obligation');
  }

  // Generate unique waiver code
  final uniqueCode = await supabase
      .rpc('generate_next_number', params: {
        'p_organization_id': auth.orgId,
        'p_entity_type': 'waiver',
      }) as String?;

  final now = DateTime.now().toUtc().toIso8601String();

  final waiver = await supabase.from('training_waivers').insert({
    'organization_id': auth.orgId,
    'unique_code': uniqueCode ?? 'WVR-${DateTime.now().millisecondsSinceEpoch}',
    'employee_id': auth.employeeId,
    'waiver_type': waiverType,
    'course_id': obligation['course_id'],
    'document_id': obligation['document_id'],
    'assignment_id': obligationId,
    'waiver_reason': waiverReason,
    'justification': justification,
    'evidence_attachments': body['evidence_attachments'] ?? [],
    'requested_by': auth.employeeId,
    'requested_at': now,
    'effective_from': effectiveFrom,
    'effective_to': body['effective_to'],
    'is_permanent': body['is_permanent'] ?? false,
    'status': 'pending_approval',
    'created_at': now,
    'updated_at': now,
  }).select('id, unique_code, status, requested_at').single();

  return ApiResponse.created(waiver).toResponse();
}
