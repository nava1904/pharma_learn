import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/documents/:id/submit
///
/// Moves a document from `draft`/`initiated`/`returned` → `pending_approval`.
/// Inserts a row into `pending_approvals` manually because the DB
/// `submit_for_approval()` function relies on `get_current_user_id()` which
/// is not available with the service-role client.
///
/// Learn-IQ rule: approver must have a lower role-level number than initiator.
Future<Response> documentSubmitHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.createDocuments,
    jwtPermissions: auth.permissions,
  );

  final document = await supabase
      .from('documents')
      .select('id, name, status, organization_id, plant_id')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (document == null) throw NotFoundException('Document not found');

  final status = document['status'] as String? ?? '';
  if (!['draft', 'initiated', 'returned'].contains(status)) {
    throw ConflictException(
      'Document cannot be submitted from status "$status". '
      'Only draft, initiated, or returned documents may be submitted.',
    );
  }

  final body = await readJson(req);

  // Fetch initiator's minimum role level (lowest number = highest authority)
  final initiatorLevelRow = await supabase
      .from('employee_roles')
      .select('roles!inner(level)')
      .eq('employee_id', auth.employeeId)
      .order('roles(level)', ascending: true)
      .limit(1)
      .maybeSingle();

  final initiatorLevel =
      (initiatorLevelRow?['roles'] as Map?)?['level'] as num? ?? 99.99;

  // Fetch initiator's display name
  final initiatorRow = await supabase
      .from('employees')
      .select('first_name, last_name')
      .eq('id', auth.employeeId)
      .single();
  final initiatorName =
      '${initiatorRow['first_name']} ${initiatorRow['last_name']}';

  final now = DateTime.now().toUtc();

  // Insert pending_approvals row (mirrors what submit_for_approval() does)
  final approvalId = await supabase
      .from('pending_approvals')
      .insert({
        'entity_type': 'document',
        'entity_id': id,
        'entity_display_name': document['name'],
        'requested_action': 'submit_for_approval',
        'current_state': status,
        'target_state': 'active', // document goes active after approval
        'initiated_by': auth.employeeId,
        'initiator_name': initiatorName,
        'initiator_role_level': initiatorLevel,
        'requires_approval': true,
        'approval_type': 'by_approval_group',
        'due_date': body['due_date'] ?? now.add(const Duration(days: 7)).toIso8601String(),
        'comments': body['comments'],
        'status': 'pending',
        'organization_id': auth.orgId,
        'plant_id': auth.plantId,
      })
      .select('id')
      .single();

  // Transition document status → pending_approval
  await supabase
      .from('documents')
      .update({'status': 'pending_approval'})
      .eq('id', id);

  await OutboxService(supabase).publish(
    aggregateType: 'document',
    aggregateId: id,
    eventType: EventTypes.documentSubmitted,
    payload: {
      'submitted_by': auth.employeeId,
      'approval_id': approvalId['id'],
      'comments': body['comments'],
    },
    orgId: auth.orgId,
  );

  final updated = await supabase
      .from('documents')
      .select('*, pending_approvals!entity_id ( id, status, due_date )')
      .eq('id', id)
      .single();

  return ApiResponse.ok({
    'document': updated,
    'approval_id': approvalId['id'],
  }).toResponse();
}
