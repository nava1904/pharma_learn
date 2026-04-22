import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/reports/schedules
///
/// Lists all report schedules for the organization.
/// Only users with manage_reports permission can access.
Future<Response> reportSchedulesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify permission - scheduling requires manage permission
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageReports,
    jwtPermissions: auth.permissions,
  );

  // Parse query params
  final templateId = req.url.queryParameters['template_id'];
  final isActive = req.url.queryParameters['is_active'];

  // Build query - using scheduled_reports table (from 13_analytics schema)
  var query = supabase
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
        next_run_at,
        run_count,
        created_by,
        created_at,
        employees!created_by ( id, first_name, last_name )
      ''')
      .eq('organization_id', auth.orgId);

  // Apply filters
  if (templateId != null) {
    query = query.eq('template_id', templateId);
  }
  if (isActive != null) {
    query = query.eq('is_active', isActive == 'true');
  }

  final schedules = await query.order('created_at', ascending: false);

  return ApiResponse.ok({'schedules': schedules}).toResponse();
}

/// POST /v1/reports/schedules
///
/// Creates a new report schedule.
///
/// Body:
/// ```json
/// {
///   "template_id": "overdue_training_report",
///   "name": "Weekly Overdue Report",
///   "description": "Sent every Monday at 8am",
///   "parameters": { "department_id": "uuid" },
///   "cron_expression": "0 8 * * 1",
///   "timezone": "Asia/Kolkata",
///   "recipients": [
///     {"employee_id": "uuid"},
///     {"role": "qa_head"}
///   ],
///   "delivery_method": "email"
/// }
/// ```
Future<Response> reportSchedulesCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify permission
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageReports,
    jwtPermissions: auth.permissions,
  );

  // Parse body
  final body = await readJson(req);

  // Validate required fields
  final templateId = body['template_id'] as String?;
  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'template_id': 'Template ID is required'});
  }

  final cronExpression = body['cron_expression'] as String?;
  if (cronExpression == null || cronExpression.isEmpty) {
    throw ValidationException(
        {'cron_expression': 'Cron expression is required'});
  }

  final recipients = body['recipients'] as List<dynamic>?;
  if (recipients == null || recipients.isEmpty) {
    throw ValidationException(
        {'recipients': 'At least one recipient is required'});
  }

  // Verify template exists
  final template = ReportTemplate.byId(templateId);
  if (template == null) {
    throw NotFoundException('Report template not found: $templateId');
  }

  // Validate cron expression format (basic validation)
  final cronParts = cronExpression.trim().split(' ');
  if (cronParts.length != 5) {
    throw ValidationException({
      'cron_expression': 'Invalid cron format. Expected 5 parts: minute hour day month weekday',
    });
  }

  // Validate timezone
  final timezone = body['timezone'] as String? ?? 'Asia/Kolkata';
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
      'timezone': 'Unsupported timezone. Use one of: ${validTimezones.join(", ")}',
    });
  }

  // Validate delivery method
  final deliveryMethod = body['delivery_method'] as String? ?? 'email';
  if (!['email', 'storage', 'both'].contains(deliveryMethod)) {
    throw ValidationException({
      'delivery_method': 'Invalid delivery method. Use: email, storage, or both',
    });
  }

  // Calculate next run time (simplified - actual calc would use cron parser)
  // In production, lifecycle_monitor would compute this properly
  final now = DateTime.now().toUtc();
  final nextRunAt = now.add(const Duration(days: 1)); // Placeholder

  // Insert schedule into scheduled_reports table
  final schedule = await supabase
      .from('scheduled_reports')
      .insert({
        'organization_id': auth.orgId,
        'template_id': templateId,
        'schedule_name': body['name'] as String? ?? template.name,
        'frequency': 'custom', // Using cron_expression instead
        'schedule_config': <String, dynamic>{}, // Empty since we use cron
        'parameters': body['parameters'] ?? <String, dynamic>{},
        'cron_expression': cronExpression,
        'timezone': timezone,
        'recipients': recipients,
        'delivery_method': deliveryMethod,
        'export_format': 'pdf',
        'is_active': body['is_active'] ?? true,
        'next_run_at': nextRunAt.toIso8601String(),
        'created_by': auth.employeeId,
      })
      .select()
      .single();

  // Write audit trail
  await supabase.from('audit_trails').insert({
    'organization_id': auth.orgId,
    'employee_id': auth.employeeId,
    'action': 'CREATE',
    'entity_type': 'report_schedule',
    'entity_id': schedule['id'],
    'event_category': 'REPORT',
    'new_values': {
      'template_id': templateId,
      'cron_expression': cronExpression,
      'recipients': recipients,
    },
    'ip_address': req.headers['x-forwarded-for']?.first,
    'user_agent': req.headers['user-agent']?.first,
  });

  return ApiResponse.created({'schedule': schedule}).toResponse();
}
