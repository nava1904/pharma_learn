import 'package:supabase/supabase.dart';

/// Service wrapper for the send-notification Edge Function.
/// Handles all notification dispatch including email and in-app notifications.
class NotificationService {
  final SupabaseClient _supabase;

  NotificationService(this._supabase);

  /// Send a notification using a predefined template.
  ///
  /// [templateKey] - Key from mail_event_templates table
  /// [recipientEmployeeId] - Target employee UUID
  /// [variables] - Template variable substitutions
  /// [channels] - List of channels: 'email', 'in_app', 'push'
  Future<void> sendFromTemplate({
    required String templateKey,
    required String recipientEmployeeId,
    Map<String, dynamic>? variables,
    List<String> channels = const ['email', 'in_app'],
  }) async {
    await _supabase.functions.invoke(
      'send-notification',
      body: {
        'template_key': templateKey,
        'recipient_employee_id': recipientEmployeeId,
        'variables': variables ?? {},
        'channels': channels,
      },
    );
  }

  /// Send a custom notification without using a template.
  ///
  /// [recipientEmployeeId] - Target employee UUID
  /// [subject] - Email subject / notification title
  /// [body] - Notification body content
  /// [channels] - List of channels: 'email', 'in_app', 'push'
  Future<void> sendCustom({
    required String recipientEmployeeId,
    required String subject,
    required String body,
    List<String> channels = const ['email', 'in_app'],
  }) async {
    await _supabase.functions.invoke(
      'send-notification',
      body: {
        'recipient_employee_id': recipientEmployeeId,
        'subject': subject,
        'body': body,
        'channels': channels,
      },
    );
  }

  /// Send notification to multiple recipients.
  ///
  /// [templateKey] - Key from mail_event_templates table
  /// [recipientEmployeeIds] - List of target employee UUIDs
  /// [variables] - Template variable substitutions
  /// [channels] - List of channels: 'email', 'in_app', 'push'
  Future<void> sendBulk({
    required String templateKey,
    required List<String> recipientEmployeeIds,
    Map<String, dynamic>? variables,
    List<String> channels = const ['email', 'in_app'],
  }) async {
    await _supabase.functions.invoke(
      'send-notification',
      body: {
        'template_key': templateKey,
        'recipient_employee_ids': recipientEmployeeIds,
        'variables': variables ?? {},
        'channels': channels,
        'bulk': true,
      },
    );
  }

  /// Send training reminder notification.
  ///
  /// [employeeId] - Employee UUID
  /// [courseName] - Name of the course
  /// [dueDate] - Due date for training completion
  Future<void> sendTrainingReminder({
    required String employeeId,
    required String courseName,
    required DateTime dueDate,
  }) async {
    await sendFromTemplate(
      templateKey: 'training_reminder',
      recipientEmployeeId: employeeId,
      variables: {
        'course_name': courseName,
        'due_date': dueDate.toIso8601String().split('T').first,
      },
    );
  }

  /// Send overdue training escalation notification.
  ///
  /// [employeeId] - Employee UUID
  /// [courseName] - Name of the course
  /// [daysPastDue] - Number of days past due
  /// [escalationLevel] - 1=employee, 2=manager, 3=director
  Future<void> sendOverdueEscalation({
    required String employeeId,
    required String courseName,
    required int daysPastDue,
    required int escalationLevel,
  }) async {
    final templateKey = switch (escalationLevel) {
      1 => 'training_overdue_employee',
      2 => 'training_overdue_manager',
      _ => 'training_overdue_director',
    };

    await sendFromTemplate(
      templateKey: templateKey,
      recipientEmployeeId: employeeId,
      variables: {
        'course_name': courseName,
        'days_past_due': daysPastDue,
      },
    );
  }

  /// Send session enrollment confirmation.
  ///
  /// [employeeId] - Employee UUID
  /// [sessionName] - Name of the session
  /// [sessionDate] - Date of the session
  /// [venueName] - Venue name
  Future<void> sendSessionEnrollment({
    required String employeeId,
    required String sessionName,
    required DateTime sessionDate,
    required String venueName,
  }) async {
    await sendFromTemplate(
      templateKey: 'session_enrollment',
      recipientEmployeeId: employeeId,
      variables: {
        'session_name': sessionName,
        'session_date': sessionDate.toIso8601String().split('T').first,
        'venue_name': venueName,
      },
    );
  }

  /// Send certificate issued notification.
  ///
  /// [employeeId] - Employee UUID
  /// [courseName] - Name of the course
  /// [certificateNumber] - Certificate number
  Future<void> sendCertificateIssued({
    required String employeeId,
    required String courseName,
    required String certificateNumber,
  }) async {
    await sendFromTemplate(
      templateKey: 'certificate_issued',
      recipientEmployeeId: employeeId,
      variables: {
        'course_name': courseName,
        'certificate_number': certificateNumber,
      },
    );
  }

  /// Send approval required notification.
  ///
  /// [approverId] - Approver employee UUID
  /// [entityType] - Type of entity requiring approval (document, course, etc.)
  /// [entityName] - Name of the entity
  /// [requestorName] - Name of the requestor
  Future<void> sendApprovalRequired({
    required String approverId,
    required String entityType,
    required String entityName,
    required String requestorName,
  }) async {
    await sendFromTemplate(
      templateKey: 'approval_required',
      recipientEmployeeId: approverId,
      variables: {
        'entity_type': entityType,
        'entity_name': entityName,
        'requestor_name': requestorName,
      },
    );
  }
}
