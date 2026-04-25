import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/delegations
///
/// Lists delegations for the current user (both given and received).
Future<Response> delegationsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final params = req.url.queryParameters;
  final type = params['type']; // 'given' or 'received'
  final status = params['status']; // 'active', 'expired', 'revoked'

  var query = supabase
      .from('delegations')
      .select('''
        id, delegation_type, start_date, end_date, reason, status, created_at,
        delegator:employees!delegator_id(id, first_name, last_name, email),
        delegate:employees!delegate_id(id, first_name, last_name, email),
        permissions
      ''');

  if (type == 'given') {
    query = query.eq('delegator_id', auth.employeeId);
  } else if (type == 'received') {
    query = query.eq('delegate_id', auth.employeeId);
  } else {
    // Both
    query = query.or('delegator_id.eq.${auth.employeeId},delegate_id.eq.${auth.employeeId}');
  }

  if (status != null) {
    query = query.eq('status', status);
  }

  final delegations = await query.order('created_at', ascending: false);

  return ApiResponse.ok(delegations).toResponse();
}

/// GET /v1/delegations/:id
///
/// Gets a specific delegation.
Future<Response> delegationGetHandler(Request req) async {
  final delegationId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (delegationId == null || delegationId.isEmpty) {
    throw ValidationException({'id': 'Delegation ID is required'});
  }

  final delegation = await supabase
      .from('delegations')
      .select('''
        *,
        delegator:employees!delegator_id(id, first_name, last_name, email),
        delegate:employees!delegate_id(id, first_name, last_name, email)
      ''')
      .eq('id', delegationId)
      .maybeSingle();

  if (delegation == null) {
    throw NotFoundException('Delegation not found');
  }

  // Check access
  if (delegation['delegator_id'] != auth.employeeId &&
      delegation['delegate_id'] != auth.employeeId &&
      !auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have access to this delegation');
  }

  return ApiResponse.ok(delegation).toResponse();
}

/// POST /v1/delegations
///
/// Creates a new delegation.
/// Body: { delegate_id, delegation_type, permissions, start_date, end_date, reason }
Future<Response> delegationCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final delegateId = requireUuid(body, 'delegate_id');
  final delegationType = requireString(body, 'delegation_type');
  final startDate = requireString(body, 'start_date');
  final endDate = requireString(body, 'end_date');
  final reason = requireString(body, 'reason');
  final permissions = body['permissions'] as List?;

  // Validate delegation type
  final validTypes = ['approval', 'training_coordinator', 'full'];
  if (!validTypes.contains(delegationType)) {
    throw ValidationException({
      'delegation_type': 'Must be one of: ${validTypes.join(", ")}'
    });
  }

  // Cannot delegate to self
  if (delegateId == auth.employeeId) {
    throw ValidationException({'delegate_id': 'Cannot delegate to yourself'});
  }

  // Check delegate exists and is active
  final delegate = await supabase
      .from('employees')
      .select('id, status')
      .eq('id', delegateId)
      .maybeSingle();

  if (delegate == null) {
    throw NotFoundException('Delegate employee not found');
  }

  if (delegate['status'] != 'active') {
    throw ValidationException({'delegate_id': 'Delegate must be an active employee'});
  }

  // Check for overlapping active delegations
  final overlap = await supabase
      .from('delegations')
      .select('id')
      .eq('delegator_id', auth.employeeId)
      .eq('delegate_id', delegateId)
      .eq('delegation_type', delegationType)
      .eq('status', 'active')
      .or('start_date.lte.$endDate,end_date.gte.$startDate')
      .maybeSingle();

  if (overlap != null) {
    throw ConflictException('Overlapping delegation already exists');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final delegation = await supabase
      .from('delegations')
      .insert({
        'delegator_id': auth.employeeId,
        'delegate_id': delegateId,
        'delegation_type': delegationType,
        'permissions': permissions,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
        'status': 'active',
        'created_at': now,
      })
      .select()
      .single();

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'delegation.created',
    'entity_type': 'delegations',
    'entity_id': delegation['id'],
    'details': {
      'delegate_id': delegateId,
      'delegation_type': delegationType,
      'start_date': startDate,
      'end_date': endDate,
    },
    'created_at': now,
  });

  return ApiResponse.created(delegation).toResponse();
}

/// PATCH /v1/delegations/:id
///
/// Updates a delegation (only end_date can be extended).
Future<Response> delegationUpdateHandler(Request req) async {
  final delegationId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (delegationId == null || delegationId.isEmpty) {
    throw ValidationException({'id': 'Delegation ID is required'});
  }

  final existing = await supabase
      .from('delegations')
      .select('id, delegator_id, status, end_date')
      .eq('id', delegationId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Delegation not found');
  }

  if (existing['delegator_id'] != auth.employeeId &&
      !auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('Only the delegator can modify this delegation');
  }

  if (existing['status'] != 'active') {
    throw ConflictException('Cannot modify an inactive delegation');
  }

  final updateData = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  // Only allow extending end_date
  if (body.containsKey('end_date')) {
    final newEndDate = body['end_date'] as String;
    final currentEndDate = existing['end_date'] as String;
    if (newEndDate.compareTo(currentEndDate) <= 0) {
      throw ValidationException({
        'end_date': 'New end date must be after current end date'
      });
    }
    updateData['end_date'] = newEndDate;
  }

  final updated = await supabase
      .from('delegations')
      .update(updateData)
      .eq('id', delegationId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/delegations/:id
///
/// Revokes a delegation.
Future<Response> delegationRevokeHandler(Request req) async {
  final delegationId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (delegationId == null || delegationId.isEmpty) {
    throw ValidationException({'id': 'Delegation ID is required'});
  }

  final existing = await supabase
      .from('delegations')
      .select('id, delegator_id, status')
      .eq('id', delegationId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Delegation not found');
  }

  if (existing['delegator_id'] != auth.employeeId &&
      !auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('Only the delegator can revoke this delegation');
  }

  if (existing['status'] != 'active') {
    throw ConflictException('Delegation is already inactive');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('delegations')
      .update({
        'status': 'revoked',
        'revoked_at': now,
        'revoked_by': auth.employeeId,
      })
      .eq('id', delegationId);

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'delegation.revoked',
    'entity_type': 'delegations',
    'entity_id': delegationId,
    'created_at': now,
  });

  return ApiResponse.noContent().toResponse();
}
