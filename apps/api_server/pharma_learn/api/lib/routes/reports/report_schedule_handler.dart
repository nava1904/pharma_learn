import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/reports/schedules/:id
///
/// Retrieves a single report schedule.
Future<Response> reportScheduleGetHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify permission
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageReports,
    jwtPermissions: auth.permissions,
  );

  // Fetch schedule from scheduled_reports table
  final schedule = await supabase
      .from('scheduled_reports')
      .select('''
        id,
        template_id,
        schedule_name,
        parameters,
        cron_expression,
        timezone,
        recipients,
        delivery_method,
        is_active,
        last_run_at,
        last_run_report_id,
        next_run_at,
        run_count,
        created_by,
        created_at,
        updated_at,
        employees!created_by ( id, first_name, last_name ),
        report_executions!last_run_report_id ( id, status, report_number, completed_at )
      ''')
      .eq('id', scheduleId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Report schedule not found');
  }

  return ApiResponse.ok({'schedule': schedule}).toResponse();
}

/// PATCH /v1/reports/schedules/:id
///
/// Updates a report schedule.
///
/// Body (all fields optional):
/// ```json
/// {
///   "name": "Updated Name",
///   "parameters": { "department_id": "uuid" },
///   "cron_expression": "0 9 * * 1-5",
///   "recipients": [...],
///   "is_active": false
/// }
/// ```
Future<Response> reportScheduleUpdateHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify permission
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageReports,
    jwtPermissions: auth.permissions,
  );

  // Verify schedule exists and belongs to org
  final existing = await supabase
      .from('scheduled_reports')
      .select('id, template_id')
      .eq('id', scheduleId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Report schedule not found');
  }

  // Parse body
  final body = await readJson(req);
  final updates = <String, dynamic>{};
  final oldValues = <String, dynamic>{};

  // Validate and collect updates
  if (body.containsKey('name')) {
    updates['name'] = body['name'];
  }
  if (body.containsKey('description')) {
    updates['description'] = body['description'];
  }
  if (body.containsKey('parameters')) {
    updates['parameters'] = body['parameters'];
  }
  if (body.containsKey('timezone')) {
    final timezone = body['timezone'] as String;
    final validTimezones = [
      'Asia/Kolkata',
      'UTC',
      'America/New_York',
      'America/Los_Angeles',
      'Europe/London',
      'Europe/Berlin',
    ];
    if (!validTimezones.contains(timezone)) {
      throw ValidationException({
        'timezone': 'Unsupported timezone',
      });
    }
    updates['timezone'] = timezone;
  }
  if (body.containsKey('cron_expression')) {
    final cronExpression = body['cron_expression'] as String;
    final cronParts = cronExpression.trim().split(' ');
    if (cronParts.length != 5) {
      throw ValidationException({
        'cron_expression': 'Invalid cron format',
      });
    }
    updates['cron_expression'] = cronExpression;
    // Recalculate next_run_at (simplified)
    updates['next_run_at'] =
        DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String();
  }
  if (body.containsKey('recipients')) {
    final recipients = body['recipients'] as List<dynamic>;
    if (recipients.isEmpty) {
      throw ValidationException({
        'recipients': 'At least one recipient is required',
      });
    }
    updates['recipients'] = recipients;
  }
  if (body.containsKey('delivery_method')) {
    final method = body['delivery_method'] as String;
    if (!['email', 'storage', 'both'].contains(method)) {
      throw ValidationException({
        'delivery_method': 'Invalid delivery method',
      });
    }
    updates['delivery_method'] = method;
  }
  if (body.containsKey('is_active')) {
    updates['is_active'] = body['is_active'] as bool;
  }

  if (updates.isEmpty) {
    throw ValidationException({'_': 'No valid fields to update'});
  }

  // Capture old values for audit
  final oldRecord = await supabase
      .from('scheduled_reports')
      .select()
      .eq('id', scheduleId)
      .single();

  for (final key in updates.keys) {
    oldValues[key] = oldRecord[key];
  }

  // Apply updates
  final updated = await supabase
      .from('scheduled_reports')
      .update(updates)
      .eq('id', scheduleId)
      .select()
      .single();

  // Write audit trail
  await supabase.from('audit_trails').insert({
    'organization_id': auth.orgId,
    'employee_id': auth.employeeId,
    'action': 'UPDATE',
    'entity_type': 'report_schedule',
    'entity_id': scheduleId,
    'event_category': 'REPORT',
    'old_values': oldValues,
    'new_values': updates,
    'ip_address': req.headers['x-forwarded-for']?.first,
    'user_agent': req.headers['user-agent']?.first,
  });

  return ApiResponse.ok({'schedule': updated}).toResponse();
}

/// DELETE /v1/reports/schedules/:id
///
/// Deletes a report schedule.
Future<Response> reportScheduleDeleteHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify permission
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageReports,
    jwtPermissions: auth.permissions,
  );

  // Verify schedule exists and belongs to org
  final existing = await supabase
      .from('scheduled_reports')
      .select('id, template_id, schedule_name')
      .eq('id', scheduleId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Report schedule not found');
  }

  // Delete schedule
  await supabase.from('scheduled_reports').delete().eq('id', scheduleId);

  // Write audit trail
  await supabase.from('audit_trails').insert({
    'organization_id': auth.orgId,
    'employee_id': auth.employeeId,
    'action': 'DELETE',
    'entity_type': 'report_schedule',
    'entity_id': scheduleId,
    'event_category': 'REPORT',
    'old_values': existing,
    'ip_address': req.headers['x-forwarded-for']?.first,
    'user_agent': req.headers['user-agent']?.first,
  });

  return ApiResponse.noContent().toResponse();
}
