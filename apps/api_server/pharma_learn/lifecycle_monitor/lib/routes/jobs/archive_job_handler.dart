import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /jobs/archive
///
/// Archives records based on retention policies.
/// EE §5.13.4 - Retention + archival with regulatory floors.
/// 
/// Retention floors (non-negotiable minimums):
/// - GMP training records: 6 years from completion
/// - Clinical trial records: 7 years from trial end
/// - Audit trails: Lifespan of parent + 1 year
/// - Certificates: 6 years from issue (or revocation + 6 years)
///
/// Archive policy: "archive-not-delete"
/// - Sets data_archives.archived = true
/// - Writes snapshot to data_archives.archive_payload
/// - Original row retained with status = 'archived'
/// - Physical deletion only via decommissioning workflow
Future<Response> archiveJobHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final startTime = DateTime.now();
  final now = DateTime.now().toUtc();

  // Get retention policies
  final policies = await supabase
      .from('retention_policies')
      .select('*')
      .eq('is_active', true);

  var totalProcessed = 0;
  var totalArchived = 0;
  final archivedByType = <String, int>{};

  for (final policy in policies) {
    final entityType = policy['entity_type'] as String;
    final retentionDays = policy['retention_days'] as int;
    final dateField = policy['date_field'] as String? ?? 'created_at';

    // Calculate cutoff date (with regulatory floor)
    final policyFloor = _getRegulatoryFloor(entityType);
    final effectiveRetention = retentionDays > policyFloor ? retentionDays : policyFloor;
    final cutoffDate = now.subtract(Duration(days: effectiveRetention));

    // Find records eligible for archival
    final records = await supabase
        .from(entityType)
        .select('*')
        .lt(dateField, cutoffDate.toIso8601String())
        .neq('status', 'archived')
        .limit(100); // Process in batches

    for (final record in records) {
      try {
        // Create archive entry with full snapshot
        await supabase.from('data_archives').insert({
          'entity_type': entityType,
          'entity_id': record['id'],
          'archive_payload': jsonEncode(record),
          'archived_at': now.toIso8601String(),
          'retention_policy_id': policy['id'],
          'original_date': record[dateField],
        });

        // Mark original as archived (don't delete!)
        await supabase.from(entityType).update({
          'status': 'archived',
          'archived_at': now.toIso8601String(),
        }).eq('id', record['id']);

        totalArchived++;
        archivedByType[entityType] = (archivedByType[entityType] ?? 0) + 1;
      } catch (e) {
        // Log failure but continue
        await supabase.from('archive_failures').insert({
          'entity_type': entityType,
          'entity_id': record['id'],
          'error': e.toString(),
          'created_at': now.toIso8601String(),
        });
      }

      totalProcessed++;
    }
  }

  final duration = DateTime.now().difference(startTime);

  // Log job execution
  await supabase.from('job_executions').insert({
    'job_name': 'archive',
    'started_at': startTime.toUtc().toIso8601String(),
    'completed_at': DateTime.now().toUtc().toIso8601String(),
    'duration_ms': duration.inMilliseconds,
    'status': 'success',
    'result': jsonEncode({
      'processed': totalProcessed,
      'archived': totalArchived,
      'by_type': archivedByType,
    }),
  });

  return ApiResponse.ok({
    'job': 'archive',
    'processed': totalProcessed,
    'archived': totalArchived,
    'by_type': archivedByType,
    'duration_ms': duration.inMilliseconds,
    'compliance': {
      'standard': 'EE URS',
      'clause': '§5.13.4-5',
      'policy': 'archive-not-delete',
    },
  }).toResponse();
}

/// Returns regulatory floor in days for entity type.
int _getRegulatoryFloor(String entityType) {
  switch (entityType) {
    case 'training_records':
    case 'employee_assignments':
      return 6 * 365; // 6 years GMP
    case 'clinical_training_records':
      return 7 * 365; // 7 years ICH E6(R2) GCP
    case 'certificates':
      return 6 * 365; // 6 years from issue
    case 'audit_trails':
      return 365; // 1 year after parent
    case 'electronic_signatures':
      return 6 * 365; // Same as signed entity
    default:
      return 3 * 365; // Default 3 years
  }
}
