import 'dart:convert';

import 'package:supabase/supabase.dart';

/// Publishes domain events to the transactional outbox via the
/// `publish_event` Postgres function.
///
/// The database function is responsible for atomically writing the event to
/// the outbox table so it can be forwarded to the event bus by a separate
/// relay process.
class OutboxService {
  final SupabaseClient _supabase;

  OutboxService(this._supabase);

  /// Publishes a domain event.
  ///
  /// - [aggregateType]: The domain aggregate type, e.g. `'document'`.
  /// - [aggregateId]: UUID of the aggregate root.
  /// - [eventType]: The event type constant, e.g. `EventTypes.documentApproved`.
  /// - [payload]: Arbitrary event data — will be JSON-encoded before storage.
  /// - [orgId]: Optional organization UUID for multi-tenant partitioning.
  Future<void> publish({
    required String aggregateType,
    required String aggregateId,
    required String eventType,
    required Map<String, dynamic> payload,
    String? orgId,
  }) async {
    await _supabase.rpc(
      'publish_event',
      params: {
        'p_aggregate_type': aggregateType,
        'p_aggregate_id': aggregateId,
        'p_event_type': eventType,
        'p_payload': jsonEncode(payload),
        'p_org_id': orgId,
      },
    );
  }
}
