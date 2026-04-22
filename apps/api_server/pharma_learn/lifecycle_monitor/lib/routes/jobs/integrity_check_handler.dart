import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';
import 'package:crypto/crypto.dart';

/// POST /jobs/integrity-check
///
/// Verifies audit trail hash chain integrity.
/// 21 CFR §11.10(c) - Record protection via cryptographic chain.
/// Runs daily via scheduler.
Future<Response> integrityCheckHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final startTime = DateTime.now();

  // Get all audit records
  final records = await supabase
      .from('audit_trails')
      .select('id, entity_type, entity_id, action, details, hash, prev_hash, created_at')
      .order('created_at', ascending: true);

  var isValid = true;
  var brokenLinks = 0;
  var invalidHashes = 0;
  var recordsChecked = 0;
  String? previousHash;
  final issues = <Map<String, dynamic>>[];

  for (final record in records) {
    recordsChecked++;
    final recordHash = record['hash'] as String?;
    final recordPrevHash = record['prev_hash'] as String?;

    // Compute expected hash
    final expectedHash = _computeHash(record);

    // Check 1: Hash matches content
    if (recordHash != null && recordHash != expectedHash) {
      invalidHashes++;
      isValid = false;
      issues.add({
        'record_id': record['id'],
        'issue': 'hash_mismatch',
        'stored': recordHash,
        'computed': expectedHash,
      });
    }

    // Check 2: Chain linkage
    if (recordPrevHash != previousHash && previousHash != null) {
      brokenLinks++;
      isValid = false;
      issues.add({
        'record_id': record['id'],
        'issue': 'chain_broken',
        'expected_prev': previousHash,
        'actual_prev': recordPrevHash,
      });
    }

    previousHash = recordHash;
  }

  final duration = DateTime.now().difference(startTime);

  // Log result
  await supabase.from('job_executions').insert({
    'job_name': 'integrity_check',
    'started_at': startTime.toUtc().toIso8601String(),
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': isValid ? 'success' : 'failed',
    'result': jsonEncode({
      'records_checked': recordsChecked,
      'is_valid': isValid,
      'broken_links': brokenLinks,
      'invalid_hashes': invalidHashes,
      'issues_count': issues.length,
    }),
  });

  // If issues found, create alert
  if (!isValid) {
    await supabase.from('system_alerts').insert({
      'alert_type': 'integrity_violation',
      'severity': 'critical',
      'message': 'Audit trail integrity check failed: $brokenLinks broken links, $invalidHashes invalid hashes',
      'details': jsonEncode(issues.take(10).toList()), // First 10 issues
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  return ApiResponse.ok({
    'job': 'integrity_check',
    'is_valid': isValid,
    'records_checked': recordsChecked,
    'broken_links': brokenLinks,
    'invalid_hashes': invalidHashes,
    'duration_ms': duration.inMilliseconds,
    'compliance': {
      'standard': '21 CFR Part 11',
      'clause': '§11.10(c)',
    },
  }).toResponse();
}

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
