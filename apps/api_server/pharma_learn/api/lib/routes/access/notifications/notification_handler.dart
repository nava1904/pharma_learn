import 'dart:convert';

import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/access/notifications
/// Returns paginated list of notifications for the authenticated user.
/// Query params:
///   - status: 'unread' | 'read' | 'all' (default: 'all')
///   - page: number (default: 1)
///   - per_page: number (default: 50, max: 100)
Future<Response> notificationListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final status = req.url.queryParameters['status'] ?? 'all';
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1')
      ?.clamp(1, 1000) ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '50')
      ?.clamp(1, 100) ?? 50;
  final offset = (page - 1) * perPage;

  int total;
  List notifications;

  if (status == 'unread') {
    notifications = await supabase
        .from('notifications')
        .select()
        .eq('employee_id', auth.employeeId)
        .isFilter('deleted_at', null)
        .isFilter('read_at', null)
        .order('created_at', ascending: false)
        .range(offset, offset + perPage - 1);

    final countResult = await supabase
        .from('notifications')
        .select()
        .eq('employee_id', auth.employeeId)
        .isFilter('deleted_at', null)
        .isFilter('read_at', null)
        .count();
    total = countResult.count;
  } else if (status == 'read') {
    notifications = await supabase
        .from('notifications')
        .select()
        .eq('employee_id', auth.employeeId)
        .isFilter('deleted_at', null)
        .not('read_at', 'is', null)
        .order('created_at', ascending: false)
        .range(offset, offset + perPage - 1);

    final countResult = await supabase
        .from('notifications')
        .select()
        .eq('employee_id', auth.employeeId)
        .isFilter('deleted_at', null)
        .not('read_at', 'is', null)
        .count();
    total = countResult.count;
  } else {
    notifications = await supabase
        .from('notifications')
        .select()
        .eq('employee_id', auth.employeeId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false)
        .range(offset, offset + perPage - 1);

    final countResult = await supabase
        .from('notifications')
        .select()
        .eq('employee_id', auth.employeeId)
        .isFilter('deleted_at', null)
        .count();
    total = countResult.count;
  }

  return ApiResponse.paginated(
    {'notifications': notifications},
    Pagination.compute(page: page, perPage: perPage, total: total),
  ).toResponse();
}

/// GET /v1/access/notifications/unread-count
/// Returns count of unread notifications for authenticated user.
Future<Response> notificationUnreadCountHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final result = await supabase
      .from('notifications')
      .select()
      .eq('employee_id', auth.employeeId)
      .isFilter('read_at', null)
      .count();

  return ApiResponse.ok({'unread_count': result.count}).toResponse();
}

/// PATCH /v1/access/notifications/:id/read
/// Marks a single notification as read.
Future<Response> notificationMarkReadHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final updated = await supabase
      .from('notifications')
      .update({
        'read_at': DateTime.now().toIso8601String(),
      })
      .eq('id', id)
      .eq('employee_id', auth.employeeId) // RLS: can only mark own notifications
      .select()
      .maybeSingle();

  if (updated == null) {
    throw NotFoundException('Notification not found');
  }

  return ApiResponse.ok({'notification': updated}).toResponse();
}

/// PATCH /v1/access/notifications/read-all
/// Marks all unread notifications as read for authenticated user.
Future<Response> notificationMarkAllReadHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  await supabase
      .from('notifications')
      .update({
        'read_at': DateTime.now().toIso8601String(),
      })
      .eq('employee_id', auth.employeeId)
      .isFilter('read_at', null);

  return ApiResponse.ok({'marked_all_read': true}).toResponse();
}

/// DELETE /v1/access/notifications/:id
/// Soft-deletes a notification (sets deleted_at, keeps for audit).
Future<Response> notificationDeleteHandler(Request req) async {
  final id = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final updated = await supabase
      .from('notifications')
      .update({
        'deleted_at': DateTime.now().toIso8601String(),
      })
      .eq('id', id)
      .eq('employee_id', auth.employeeId)
      .select()
      .maybeSingle();

  if (updated == null) {
    throw NotFoundException('Notification not found');
  }

  return ApiResponse.noContent().toResponse();
}

/// GET /v1/access/notifications/settings
/// Returns notification preferences for authenticated user.
Future<Response> notificationSettingsGetHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final settings = await supabase
      .from('notification_settings')
      .select()
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  // Return defaults if no settings exist yet
  if (settings == null) {
    return ApiResponse.ok({
      'settings': {
        'email_enabled': true,
        'push_enabled': true,
        'approval_notifications': true,
        'training_reminders': true,
        'cert_expiry_warnings': true,
        'digest_frequency': 'instant',
      }
    }).toResponse();
  }

  return ApiResponse.ok({'settings': settings}).toResponse();
}

/// PATCH /v1/access/notifications/settings
/// Updates notification preferences for authenticated user.
Future<Response> notificationSettingsPatchHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  const allowedFields = {
    'email_enabled',
    'push_enabled',
    'approval_notifications',
    'training_reminders',
    'cert_expiry_warnings',
    'digest_frequency',
  };

  final updates = Map<String, dynamic>.fromEntries(
    body.entries.where((e) => allowedFields.contains(e.key)),
  );

  if (updates.isEmpty) {
    throw ValidationException({'body': 'No valid settings provided'});
  }

  updates['updated_at'] = DateTime.now().toIso8601String();

  // Upsert: insert if not exists, update if exists
  final upserted = await supabase
      .from('notification_settings')
      .upsert({
        'employee_id': auth.employeeId,
        ...updates,
      })
      .select()
      .single();

  return ApiResponse.ok({'settings': upserted}).toResponse();
}
