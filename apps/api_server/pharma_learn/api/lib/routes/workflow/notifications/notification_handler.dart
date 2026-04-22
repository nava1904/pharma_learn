import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/notifications
///
/// Gets notifications for the authenticated user.
Future<Response> notificationsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  final unreadOnly = req.url.queryParameters['unread_only'] == 'true';
  final offset = (page - 1) * perPage;

  var query = supabase
      .from('notifications')
      .select('id, type, title, message, data, read_at, created_at')
      .eq('employee_id', auth.employeeId);

  if (unreadOnly) {
    query = query.isFilter('read_at', null);
  }

  final notifications = await query
      .order('created_at', ascending: false)
      .range(offset, offset + perPage - 1);

  // Get unread count
  final unreadCount = await supabase
      .from('notifications')
      .select()
      .eq('employee_id', auth.employeeId)
      .isFilter('read_at', null)
      .count();

  return ApiResponse.ok({
    'notifications': notifications,
    'unread_count': unreadCount.count,
  }).toResponse();
}

/// POST /v1/notifications/:id/read
///
/// Marks a notification as read.
Future<Response> notificationReadHandler(Request req) async {
  final notificationId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (notificationId == null) {
    throw ValidationException({'id': 'Notification ID is required'});
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final updated = await supabase
      .from('notifications')
      .update({'read_at': now})
      .eq('id', notificationId)
      .eq('employee_id', auth.employeeId)
      .select()
      .maybeSingle();

  if (updated == null) throw NotFoundException('Notification not found');

  return ApiResponse.ok({'notification': updated}).toResponse();
}

/// POST /v1/notifications/read-all
///
/// Marks all notifications as read.
Future<Response> notificationsReadAllHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('notifications')
      .update({'read_at': now})
      .eq('employee_id', auth.employeeId)
      .isFilter('read_at', null);

  return ApiResponse.ok({'message': 'All notifications marked as read'}).toResponse();
}

/// GET /v1/notifications/preferences
///
/// Gets notification preferences for the user.
Future<Response> notificationPrefsGetHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final prefs = await supabase
      .from('notification_preferences')
      .select('*')
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  // Return defaults if no preferences set
  final defaultPrefs = {
    'email_enabled': true,
    'push_enabled': true,
    'training_due_reminder': true,
    'approval_required': true,
    'session_reminders': true,
    'certificate_expiry': true,
    'quiet_hours_start': null,
    'quiet_hours_end': null,
  };

  return ApiResponse.ok({
    'preferences': prefs ?? defaultPrefs,
  }).toResponse();
}

/// PATCH /v1/notifications/preferences
///
/// Updates notification preferences.
Future<Response> notificationPrefsPatchHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  final allowedFields = [
    'email_enabled', 'push_enabled', 'training_due_reminder',
    'approval_required', 'session_reminders', 'certificate_expiry',
    'quiet_hours_start', 'quiet_hours_end',
  ];

  final updates = <String, dynamic>{};
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updates[field] = body[field];
    }
  }

  if (updates.isEmpty) {
    throw ValidationException({'body': 'No valid preference fields provided'});
  }

  updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

  // Upsert preferences
  final result = await supabase
      .from('notification_preferences')
      .upsert({
        'employee_id': auth.employeeId,
        ...updates,
      })
      .select()
      .single();

  return ApiResponse.ok({'preferences': result}).toResponse();
}
