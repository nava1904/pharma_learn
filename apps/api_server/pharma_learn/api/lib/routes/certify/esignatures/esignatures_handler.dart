import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// GET /v1/certify/esignatures
///
/// Lists e-signatures with filtering.
/// Query params:
/// - employee_id: filter by signer
/// - context_type: filter by context (e.g., 'document_approval', 'training_completion')
/// - from_date, to_date: date range
/// - page, per_page: pagination
Future<Response> esignaturesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.viewAudit)) {
    throw PermissionDeniedException('You do not have permission to view e-signatures');
  }

  final params = req.url.queryParameters;
  final employeeId = params['employee_id'];
  final contextType = params['context_type'];
  final fromDate = params['from_date'];
  final toDate = params['to_date'];
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;

  var query = supabase
      .from('electronic_signatures')
      .select('''
        id, meaning, context_type, context_id, signed_at, ip_address,
        hash_chain, is_valid,
        employees(id, employee_number, first_name, last_name)
      ''');

  if (employeeId != null) query = query.eq('employee_id', employeeId);
  if (contextType != null) query = query.eq('context_type', contextType);
  if (fromDate != null) query = query.gte('signed_at', fromDate);
  if (toDate != null) query = query.lte('signed_at', toDate);

  final signatures = await query
      .order('signed_at', ascending: false)
      .range((page - 1) * perPage, page * perPage - 1);

  return ApiResponse.ok(signatures).toResponse();
}

/// GET /v1/certify/esignatures/:id
///
/// Gets a specific e-signature with full details and verification.
Future<Response> esignatureGetHandler(Request req) async {
  final esigId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (esigId == null || esigId.isEmpty) {
    throw ValidationException({'id': 'E-signature ID is required'});
  }

  if (!auth.hasPermission(Permissions.viewAudit)) {
    throw PermissionDeniedException('You do not have permission to view e-signatures');
  }

  final esig = await supabase
      .from('electronic_signatures')
      .select('''
        *,
        employees(id, employee_number, first_name, last_name, email),
        reauth_sessions(id, reauth_type, reauth_at, ip_address)
      ''')
      .eq('id', esigId)
      .maybeSingle();

  if (esig == null) {
    throw NotFoundException('E-signature not found');
  }

  return ApiResponse.ok(esig).toResponse();
}

/// POST /v1/certify/esignatures
///
/// Creates a new e-signature after re-authentication.
/// Body: {
///   reauth_session_id: string,  // From re-authentication
///   meaning: string,            // e.g., 'APPROVE', 'COMPLETE', 'ACKNOWLEDGE'
///   context_type: string,       // e.g., 'document', 'training_record'
///   context_id: string,         // UUID of the entity being signed
///   comments?: string           // Optional signer comments
/// }
Future<Response> esignatureCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final reauthSessionId = requireUuid(body, 'reauth_session_id');
  final meaning = requireString(body, 'meaning');
  final contextType = requireString(body, 'context_type');
  final contextId = requireUuid(body, 'context_id');

  // Verify re-auth session is valid and belongs to current user
  final reauthSession = await supabase
      .from('reauth_sessions')
      .select('id, employee_id, is_valid, expires_at')
      .eq('id', reauthSessionId)
      .maybeSingle();

  if (reauthSession == null) {
    throw NotFoundException('Re-authentication session not found');
  }

  if (reauthSession['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('Re-authentication session does not belong to you');
  }

  if (reauthSession['is_valid'] != true) {
    throw ConflictException('Re-authentication session has been invalidated');
  }

  final expiresAt = DateTime.parse(reauthSession['expires_at'] as String);
  if (DateTime.now().toUtc().isAfter(expiresAt)) {
    throw ConflictException('Re-authentication session has expired');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Get last signature for hash chain
  final lastSig = await supabase
      .from('electronic_signatures')
      .select('id, hash_chain')
      .order('signed_at', ascending: false)
      .limit(1)
      .maybeSingle();

  final previousHash = lastSig?['hash_chain'] as String? ?? 'GENESIS';

  // Create hash chain entry
  final signatureData = {
    'employee_id': auth.employeeId,
    'meaning': meaning,
    'context_type': contextType,
    'context_id': contextId,
    'signed_at': now,
    'previous_hash': previousHash,
  };

  final hashInput = jsonEncode(signatureData);
  final hashChain = sha256.convert(utf8.encode(hashInput)).toString();

  // Get client IP from request headers
  final forwardedFor = req.headers['x-forwarded-for'];
  final ipAddress = forwardedFor != null 
      ? forwardedFor.first.split(',').first.trim()
      : (req.headers['x-real-ip']?.first ?? 'unknown');

  final esig = await supabase
      .from('electronic_signatures')
      .insert({
        'employee_id': auth.employeeId,
        'reauth_session_id': reauthSessionId,
        'meaning': meaning,
        'context_type': contextType,
        'context_id': contextId,
        'comments': body['comments'],
        'signed_at': now,
        'ip_address': ipAddress,
        'hash_chain': hashChain,
        'previous_hash': previousHash,
        'is_valid': true,
        'created_at': now,
      })
      .select()
      .single();

  // Invalidate the reauth session (one-time use)
  await supabase
      .from('reauth_sessions')
      .update({
        'is_valid': false,
        'used_at': now,
      })
      .eq('id', reauthSessionId);

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'electronic_signature',
    'entity_id': esig['id'],
    'action': 'create',
    'employee_id': auth.employeeId,
    'new_values': {
      'meaning': meaning,
      'context_type': contextType,
      'context_id': contextId,
    },
    'created_at': now,
  });

  return ApiResponse.created(esig).toResponse();
}

/// POST /v1/certify/esignatures/:id/verify
///
/// Verifies the integrity of an e-signature's hash chain.
Future<Response> esignatureVerifyHandler(Request req) async {
  final esigId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (esigId == null || esigId.isEmpty) {
    throw ValidationException({'id': 'E-signature ID is required'});
  }

  if (!auth.hasPermission(Permissions.viewAudit)) {
    throw PermissionDeniedException('You do not have permission to verify e-signatures');
  }

  final esig = await supabase
      .from('electronic_signatures')
      .select('*')
      .eq('id', esigId)
      .maybeSingle();

  if (esig == null) {
    throw NotFoundException('E-signature not found');
  }

  // Reconstruct the hash
  final signatureData = {
    'employee_id': esig['employee_id'],
    'meaning': esig['meaning'],
    'context_type': esig['context_type'],
    'context_id': esig['context_id'],
    'signed_at': esig['signed_at'],
    'previous_hash': esig['previous_hash'],
  };

  final hashInput = jsonEncode(signatureData);
  final computedHash = sha256.convert(utf8.encode(hashInput)).toString();
  final storedHash = esig['hash_chain'] as String;

  final isValid = computedHash == storedHash;

  // Verify chain continuity
  bool chainValid = true;
  if (esig['previous_hash'] != 'GENESIS') {
    final previousSig = await supabase
        .from('electronic_signatures')
        .select('hash_chain')
        .eq('hash_chain', esig['previous_hash'])
        .maybeSingle();

    if (previousSig == null) {
      chainValid = false;
    }
  }

  // Update validity if changed
  if (esig['is_valid'] != isValid) {
    await supabase
        .from('electronic_signatures')
        .update({
          'is_valid': isValid,
          'last_verified_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', esigId);
  }

  return ApiResponse.ok({
    'esignature_id': esigId,
    'hash_valid': isValid,
    'chain_valid': chainValid,
    'overall_valid': isValid && chainValid,
    'computed_hash': computedHash,
    'stored_hash': storedHash,
    'verified_at': DateTime.now().toUtc().toIso8601String(),
  }).toResponse();
}

/// GET /v1/certify/esignatures/history/:contextType/:contextId
///
/// Gets all e-signatures for a specific entity (e.g., document, training record).
Future<Response> esignatureHistoryHandler(Request req) async {
  final contextType = req.rawPathParameters[#contextType];
  final contextId = req.rawPathParameters[#contextId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (contextType == null || contextId == null) {
    throw ValidationException({
      'context': 'Context type and context ID are required'
    });
  }

  if (!auth.hasPermission(Permissions.viewAudit)) {
    throw PermissionDeniedException('You do not have permission to view e-signature history');
  }

  final signatures = await supabase
      .from('electronic_signatures')
      .select('''
        id, meaning, signed_at, ip_address, is_valid, comments,
        employees(id, employee_number, first_name, last_name)
      ''')
      .eq('context_type', contextType)
      .eq('context_id', contextId)
      .order('signed_at', ascending: true);

  return ApiResponse.ok(signatures).toResponse();
}
