import 'dart:convert';
import 'package:crypto/crypto.dart';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/certify/integrity/verify
///
/// Verifies the integrity of audit trail hash chain.
/// Implements 21 CFR §11.10(c) - record protection via cryptographic hash chain.
/// Admin only - used for compliance audits.
Future<Response> integrityVerifyHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('integrity.verify')) {
    throw PermissionDeniedException('You do not have permission to verify integrity');
  }

  final entityType = body['entity_type'] as String?;
  final entityId = body['entity_id'] as String?;
  final fullChain = body['full_chain'] as bool? ?? false;

  // Get audit records to verify
  var builder = supabase
      .from('audit_trails')
      .select('id, entity_type, entity_id, action, details, hash, prev_hash, created_at')
      .eq('organization_id', auth.orgId);

  if (entityType != null && entityType.isNotEmpty) {
    builder = builder.eq('entity_type', entityType);
  }
  if (entityId != null && entityId.isNotEmpty) {
    builder = builder.eq('entity_id', entityId);
  }

  final records = await builder.order('created_at', ascending: true);

  if (records.isEmpty) {
    return ApiResponse.ok({
      'is_valid': true,
      'message': 'No records to verify',
      'records_checked': 0,
    }).toResponse();
  }

  final verificationResults = <Map<String, dynamic>>[];
  var isValid = true;
  var brokenLinks = 0;
  var invalidHashes = 0;
  String? previousHash;

  for (final record in records) {
    final recordHash = record['hash'] as String?;
    final recordPrevHash = record['prev_hash'] as String?;

    // Compute expected hash
    final expectedHash = _computeHash(record);

    // Check 1: Hash matches content
    final hashMatches = recordHash == expectedHash;
    if (!hashMatches) {
      invalidHashes++;
      isValid = false;
    }

    // Check 2: Chain linkage (prev_hash points to previous record's hash)
    final chainValid = recordPrevHash == previousHash;
    if (!chainValid && previousHash != null) {
      brokenLinks++;
      isValid = false;
    }

    if (fullChain || !hashMatches || !chainValid) {
      verificationResults.add({
        'record_id': record['id'],
        'entity_type': record['entity_type'],
        'entity_id': record['entity_id'],
        'created_at': record['created_at'],
        'hash_valid': hashMatches,
        'chain_valid': chainValid,
        'stored_hash': recordHash,
        'computed_hash': expectedHash,
      });
    }

    previousHash = recordHash;
  }

  // Log the verification in audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'integrity_check',
    'entity_id': auth.employeeId,
    'action': 'INTEGRITY_VERIFIED',
    'event_category': 'COMPLIANCE',
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
    'details': jsonEncode({
      'target_entity_type': entityType,
      'target_entity_id': entityId,
      'records_checked': records.length,
      'is_valid': isValid,
      'broken_links': brokenLinks,
      'invalid_hashes': invalidHashes,
    }),
  });

  return ApiResponse.ok({
    'is_valid': isValid,
    'records_checked': records.length,
    'broken_links': brokenLinks,
    'invalid_hashes': invalidHashes,
    'verification_details': fullChain ? verificationResults : null,
    'verified_at': DateTime.now().toUtc().toIso8601String(),
    'verified_by': auth.employeeId,
    'compliance': {
      'standard': '21 CFR Part 11',
      'clause': '§11.10(c)',
      'requirement': 'Protection of records to enable their accurate and ready retrieval throughout the records retention period',
    },
  }).toResponse();
}

/// Computes SHA-256 hash of audit record for chain integrity.
String _computeHash(Map<String, dynamic> record) {
  final data = {
    'id': record['id'],
    'entity_type': record['entity_type'],
    'entity_id': record['entity_id'],
    'action': record['action'],
    'details': record['details'],
    'created_at': record['created_at'],
    'prev_hash': record['prev_hash'],
  };

  final jsonString = jsonEncode(data);
  final bytes = utf8.encode(jsonString);
  final digest = sha256.convert(bytes);

  return digest.toString();
}

/// GET /v1/certify/integrity/status
///
/// Returns the current integrity status of the audit chain.
Future<Response> integrityStatusHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission('integrity.view')) {
    throw PermissionDeniedException('You do not have permission to view integrity status');
  }

  // Get latest audit record
  final latest = await supabase
      .from('audit_trails')
      .select('id, hash, created_at')
      .eq('organization_id', auth.orgId)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  // Get count of records
  final countResult = await supabase
      .from('audit_trails')
      .select()
      .eq('organization_id', auth.orgId)
      .count();

  // Get last verification timestamp
  final lastVerification = await supabase
      .from('audit_trails')
      .select('created_at, details')
      .eq('organization_id', auth.orgId)
      .eq('action', 'INTEGRITY_VERIFIED')
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  return ApiResponse.ok({
    'total_records': countResult.count,
    'latest_record': latest != null
        ? {
            'id': latest['id'],
            'hash': latest['hash'],
            'created_at': latest['created_at'],
          }
        : null,
    'last_verification': lastVerification?['created_at'],
    'last_verification_result': lastVerification != null
        ? jsonDecode(lastVerification['details'] as String)
        : null,
  }).toResponse();
}
