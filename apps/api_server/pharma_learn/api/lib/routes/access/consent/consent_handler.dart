import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/consent/policies
///
/// Lists consent policies.
Future<Response> consentPoliciesListHandler(Request req) async {
  final supabase = RequestContext.supabase;

  final policies = await supabase
      .from('consent_policies')
      .select('id, name, description, policy_type, version, is_active, effective_date')
      .eq('is_active', true)
      .order('name', ascending: true);

  return ApiResponse.ok(policies).toResponse();
}

/// GET /v1/consent/policies/:id
///
/// Gets a specific consent policy with full content.
Future<Response> consentPolicyGetHandler(Request req) async {
  final policyId = req.rawPathParameters[#id];
  final supabase = RequestContext.supabase;

  if (policyId == null || policyId.isEmpty) {
    throw ValidationException({'id': 'Policy ID is required'});
  }

  final policy = await supabase
      .from('consent_policies')
      .select('*')
      .eq('id', policyId)
      .maybeSingle();

  if (policy == null) {
    throw NotFoundException('Consent policy not found');
  }

  return ApiResponse.ok(policy).toResponse();
}

/// GET /v1/consent/me
///
/// Gets the current user's consent records.
Future<Response> myConsentsHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final consents = await supabase
      .from('employee_consents')
      .select('''
        id, status, consented_at, revoked_at,
        consent_policies(id, name, policy_type, version)
      ''')
      .eq('employee_id', auth.employeeId)
      .order('consented_at', ascending: false);

  return ApiResponse.ok(consents).toResponse();
}

/// GET /v1/consent/pending
///
/// Gets policies the current user hasn't consented to.
Future<Response> pendingConsentsHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Get all active policies
  final policies = await supabase
      .from('consent_policies')
      .select('id, name, description, policy_type, version')
      .eq('is_active', true)
      .eq('requires_consent', true);

  // Get user's consents
  final consents = await supabase
      .from('employee_consents')
      .select('policy_id')
      .eq('employee_id', auth.employeeId)
      .eq('status', 'consented');

  final consentedPolicyIds = consents.map((c) => c['policy_id']).toSet();

  // Filter to pending
  final pending = policies
      .where((p) => !consentedPolicyIds.contains(p['id']))
      .toList();

  return ApiResponse.ok(pending).toResponse();
}

/// POST /v1/consent/:policyId/accept
///
/// Records consent acceptance.
Future<Response> acceptConsentHandler(Request req) async {
  final policyId = req.rawPathParameters[#policyId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (policyId == null || policyId.isEmpty) {
    throw ValidationException({'policyId': 'Policy ID is required'});
  }

  // Verify policy exists and is active
  final policy = await supabase
      .from('consent_policies')
      .select('id, name, version')
      .eq('id', policyId)
      .eq('is_active', true)
      .maybeSingle();

  if (policy == null) {
    throw NotFoundException('Consent policy not found or inactive');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Upsert consent record
  final consent = await supabase
      .from('employee_consents')
      .upsert(
        {
          'employee_id': auth.employeeId,
          'policy_id': policyId,
          'policy_version': policy['version'],
          'status': 'consented',
          'consented_at': now,
          'ip_address': req.headers['x-forwarded-for']?.first ?? req.headers['x-real-ip']?.first,
          'user_agent': req.headers['user-agent']?.first,
        },
        onConflict: 'employee_id,policy_id',
      )
      .select()
      .single();

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'consent.accepted',
    'entity_type': 'employee_consents',
    'entity_id': consent['id'],
    'details': {'policy_id': policyId, 'policy_name': policy['name']},
    'created_at': now,
  });

  return ApiResponse.ok({
    'message': 'Consent recorded successfully',
    'consent_id': consent['id'],
  }).toResponse();
}

/// POST /v1/consent/:policyId/revoke
///
/// Revokes a previously given consent.
Future<Response> revokeConsentHandler(Request req) async {
  final policyId = req.rawPathParameters[#policyId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (policyId == null || policyId.isEmpty) {
    throw ValidationException({'policyId': 'Policy ID is required'});
  }

  final reason = optionalString(body, 'reason');

  // Check existing consent
  final consent = await supabase
      .from('employee_consents')
      .select('id, status')
      .eq('employee_id', auth.employeeId)
      .eq('policy_id', policyId)
      .maybeSingle();

  if (consent == null) {
    throw NotFoundException('No consent record found');
  }

  if (consent['status'] != 'consented') {
    throw ConflictException('Consent is not active');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('employee_consents')
      .update({
        'status': 'revoked',
        'revoked_at': now,
        'revocation_reason': reason,
      })
      .eq('id', consent['id']);

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'consent.revoked',
    'entity_type': 'employee_consents',
    'entity_id': consent['id'],
    'details': {'policy_id': policyId, 'reason': reason},
    'created_at': now,
  });

  return ApiResponse.ok({'message': 'Consent revoked successfully'}).toResponse();
}

/// POST /v1/consent/policies (Admin)
///
/// Creates a new consent policy.
Future<Response> createConsentPolicyHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to create consent policies');
  }

  final name = requireString(body, 'name');
  final policyType = requireString(body, 'policy_type');
  final content = requireString(body, 'content');

  final now = DateTime.now().toUtc().toIso8601String();

  final policy = await supabase
      .from('consent_policies')
      .insert({
        'name': name,
        'description': body['description'],
        'policy_type': policyType,
        'content': content,
        'version': 1,
        'is_active': true,
        'requires_consent': body['requires_consent'] ?? true,
        'effective_date': body['effective_date'] ?? now,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(policy).toResponse();
}

/// PATCH /v1/consent/policies/:id (Admin)
///
/// Updates a consent policy (creates new version).
Future<Response> updateConsentPolicyHandler(Request req) async {
  final policyId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (policyId == null || policyId.isEmpty) {
    throw ValidationException({'id': 'Policy ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to update consent policies');
  }

  final existing = await supabase
      .from('consent_policies')
      .select('id, version')
      .eq('id', policyId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Consent policy not found');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  // If content changes, increment version
  if (body.containsKey('content')) {
    updateData['content'] = body['content'];
    updateData['version'] = (existing['version'] as int) + 1;
  }

  final allowedFields = ['name', 'description', 'is_active', 'requires_consent'];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('consent_policies')
      .update(updateData)
      .eq('id', policyId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}
