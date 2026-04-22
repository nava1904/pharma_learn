import 'package:supabase/supabase.dart';

/// Centralized event publisher wrapping the `publish_event()` SQL function.
///
/// Usage:
/// ```dart
/// await EventPublisher.publish(
///   supabase,
///   eventType: 'document.submitted',
///   aggregateType: 'document',
///   aggregateId: docId,
///   payload: {'title': doc.title, 'version': doc.version},
///   orgId: auth.orgId,
/// );
/// ```
///
/// The event is published WITHIN the same database transaction as your
/// data changes, ensuring atomicity (no dual-write problem).
class EventPublisher {
  /// Server name for source_server column (set via environment)
  static const String _serverName = String.fromEnvironment(
    'SERVER_NAME',
    defaultValue: 'api',
  );

  /// Publishes a domain event to the events_outbox table.
  ///
  /// Returns the UUID of the created event.
  ///
  /// Parameters:
  /// - [supabase]: The Supabase client (uses service role for RPC)
  /// - [eventType]: Event verb, e.g., 'document.submitted', 'certificate.issued'
  /// - [aggregateType]: Entity type, e.g., 'document', 'certificate'
  /// - [aggregateId]: UUID of the entity
  /// - [payload]: Event data (will be stored as JSONB)
  /// - [traceId]: Optional OpenTelemetry trace ID for distributed tracing
  /// - [correlationId]: Optional ID linking related events
  /// - [orgId]: Organization ID for RLS and routing
  static Future<String> publish(
    SupabaseClient supabase, {
    required String eventType,
    required String aggregateType,
    required String aggregateId,
    Map<String, dynamic> payload = const {},
    String? traceId,
    String? correlationId,
    String? orgId,
  }) async {
    final result = await supabase.rpc('publish_event', params: {
      'p_aggregate_type': aggregateType,
      'p_aggregate_id': aggregateId,
      'p_event_type': eventType,
      'p_payload': payload,
      'p_trace_id': traceId,
      'p_correlation_id': correlationId,
      'p_source_server': _serverName,
      'p_org_id': orgId,
    });

    return result as String;
  }

  /// Convenience method for document events
  static Future<String> publishDocumentEvent(
    SupabaseClient supabase, {
    required String event, // 'submitted', 'approved', 'rejected', 'effective'
    required String documentId,
    required String orgId,
    Map<String, dynamic> payload = const {},
    String? traceId,
  }) {
    return publish(
      supabase,
      eventType: 'document.$event',
      aggregateType: 'document',
      aggregateId: documentId,
      payload: payload,
      orgId: orgId,
      traceId: traceId,
    );
  }

  /// Convenience method for course events
  static Future<String> publishCourseEvent(
    SupabaseClient supabase, {
    required String event, // 'submitted', 'approved', 'rejected', 'published'
    required String courseId,
    required String orgId,
    Map<String, dynamic> payload = const {},
    String? traceId,
  }) {
    return publish(
      supabase,
      eventType: 'course.$event',
      aggregateType: 'course',
      aggregateId: courseId,
      payload: payload,
      orgId: orgId,
      traceId: traceId,
    );
  }

  /// Convenience method for training record events
  static Future<String> publishTrainingRecordEvent(
    SupabaseClient supabase, {
    required String event, // 'created', 'completed', 'failed'
    required String trainingRecordId,
    required String orgId,
    Map<String, dynamic> payload = const {},
    String? traceId,
  }) {
    return publish(
      supabase,
      eventType: 'training_record.$event',
      aggregateType: 'training_record',
      aggregateId: trainingRecordId,
      payload: payload,
      orgId: orgId,
      traceId: traceId,
    );
  }

  /// Convenience method for certificate events
  static Future<String> publishCertificateEvent(
    SupabaseClient supabase, {
    required String event, // 'issued', 'revoked', 'expired'
    required String certificateId,
    required String orgId,
    Map<String, dynamic> payload = const {},
    String? traceId,
  }) {
    return publish(
      supabase,
      eventType: 'certificate.$event',
      aggregateType: 'certificate',
      aggregateId: certificateId,
      payload: payload,
      orgId: orgId,
      traceId: traceId,
    );
  }

  /// Convenience method for assessment events
  static Future<String> publishAssessmentEvent(
    SupabaseClient supabase, {
    required String event, // 'started', 'submitted', 'passed', 'failed'
    required String attemptId,
    required String orgId,
    Map<String, dynamic> payload = const {},
    String? traceId,
  }) {
    return publish(
      supabase,
      eventType: 'assessment.$event',
      aggregateType: 'assessment_attempt',
      aggregateId: attemptId,
      payload: payload,
      orgId: orgId,
      traceId: traceId,
    );
  }

  /// Convenience method for employee events
  static Future<String> publishEmployeeEvent(
    SupabaseClient supabase, {
    required String event, // 'created', 'updated', 'deactivated', 'role_changed'
    required String employeeId,
    required String orgId,
    Map<String, dynamic> payload = const {},
    String? traceId,
  }) {
    return publish(
      supabase,
      eventType: 'employee.$event',
      aggregateType: 'employee',
      aggregateId: employeeId,
      payload: payload,
      orgId: orgId,
      traceId: traceId,
    );
  }
}
