import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/access/mail-settings/templates
///
/// Lists all mail event templates.
Future<Response> mailTemplatesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final query = req.url.queryParameters;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to view mail settings');
  }

  var builder = supabase
      .from('mail_event_templates')
      .select('''
        id, event_code, language_code, subject_template,
        from_name, from_address, reply_to, cc_addresses,
        is_active, created_at, updated_at,
        plant:plants(id, name)
      ''')
      .eq('organization_id', auth.orgId);

  if (query['event_code'] != null) {
    builder = builder.eq('event_code', query['event_code']!);
  }
  if (query['is_active'] != null) {
    builder = builder.eq('is_active', query['is_active'] == 'true');
  }
  if (query['plant_id'] != null) {
    builder = builder.eq('plant_id', query['plant_id']!);
  }
  if (query['language_code'] != null) {
    builder = builder.eq('language_code', query['language_code']!);
  }

  final result = await builder.order('event_code');

  return ApiResponse.ok({
    'mail_templates': result,
  }).toResponse();
}

/// POST /v1/access/mail-settings/templates
///
/// Creates a new mail event template.
Future<Response> mailTemplateCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to create mail templates');
  }

  final eventCode = requireString(body, 'event_code');
  final languageCode = body['language_code'] as String? ?? 'en';
  final subjectTemplate = requireString(body, 'subject_template');
  final bodyHtmlTemplate = requireString(body, 'body_html_template');
  final bodyTextTemplate = body['body_text_template'] as String?;
  final triggerCondition = body['trigger_condition'] as String?;
  final fromName = body['from_name'] as String?;
  final fromAddress = body['from_address'] as String?;
  final replyTo = body['reply_to'] as String?;
  final ccAddresses = body['cc_addresses'] as List?;
  final plantId = body['plant_id'] as String?;

  final result = await supabase
      .from('mail_event_templates')
      .insert({
        'event_code': eventCode,
        'organization_id': auth.orgId,
        'plant_id': plantId,
        'language_code': languageCode,
        'subject_template': subjectTemplate,
        'body_html_template': bodyHtmlTemplate,
        'body_text_template': bodyTextTemplate,
        'trigger_condition': triggerCondition,
        'from_name': fromName,
        'from_address': fromAddress,
        'reply_to': replyTo,
        'cc_addresses': ccAddresses,
        'is_active': true,
        'created_by': auth.employeeId,
      })
      .select()
      .single();

  return ApiResponse.created({
    'mail_template': result,
    'message': 'Mail template created successfully',
  }).toResponse();
}

/// GET /v1/access/mail-settings/templates/:id
Future<Response> mailTemplateGetHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to view mail templates');
  }

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  final result = await supabase
      .from('mail_event_templates')
      .select('''
        id, event_code, language_code, subject_template,
        body_html_template, body_text_template, trigger_condition,
        from_name, from_address, reply_to, cc_addresses,
        is_active, created_at, updated_at,
        plant:plants(id, name)
      ''')
      .eq('id', templateId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    throw NotFoundException('Mail template not found');
  }

  return ApiResponse.ok({'mail_template': result}).toResponse();
}

/// PATCH /v1/access/mail-settings/templates/:id
Future<Response> mailTemplateUpdateHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to update mail templates');
  }

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = [
    'subject_template', 'body_html_template', 'body_text_template',
    'trigger_condition', 'from_name', 'from_address', 'reply_to',
    'cc_addresses', 'is_active'
  ];

  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updates[field] = body[field];
    }
  }

  final result = await supabase
      .from('mail_event_templates')
      .update(updates)
      .eq('id', templateId)
      .eq('organization_id', auth.orgId)
      .select()
      .single();

  return ApiResponse.ok({
    'mail_template': result,
    'message': 'Mail template updated successfully',
  }).toResponse();
}

/// DELETE /v1/access/mail-settings/templates/:id
Future<Response> mailTemplateDeleteHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to delete mail templates');
  }

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  await supabase
      .from('mail_event_templates')
      .update({
        'is_active': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', templateId)
      .eq('organization_id', auth.orgId);

  return ApiResponse.ok({
    'message': 'Mail template deactivated',
  }).toResponse();
}

/// GET /v1/access/mail-settings/event-codes
///
/// Lists all available event codes with descriptions.
Future<Response> mailEventCodesListHandler(Request req) async {
  // Static list of supported event codes
  final eventCodes = [
    {'code': 'training.assigned', 'description': 'Training assigned to employee', 'category': 'training'},
    {'code': 'training.reminder', 'description': 'Training due reminder', 'category': 'training'},
    {'code': 'training.overdue', 'description': 'Training overdue notification', 'category': 'training'},
    {'code': 'training.completed', 'description': 'Training completion confirmation', 'category': 'training'},
    {'code': 'assessment.assigned', 'description': 'Assessment assigned', 'category': 'assessment'},
    {'code': 'assessment.reminder', 'description': 'Assessment due reminder', 'category': 'assessment'},
    {'code': 'assessment.completed', 'description': 'Assessment completed', 'category': 'assessment'},
    {'code': 'assessment.result', 'description': 'Assessment result available', 'category': 'assessment'},
    {'code': 'approval.pending', 'description': 'Approval request pending', 'category': 'workflow'},
    {'code': 'approval.approved', 'description': 'Item approved', 'category': 'workflow'},
    {'code': 'approval.rejected', 'description': 'Item rejected', 'category': 'workflow'},
    {'code': 'certificate.issued', 'description': 'Certificate issued', 'category': 'certification'},
    {'code': 'certificate.expiring', 'description': 'Certificate expiring soon', 'category': 'certification'},
    {'code': 'certificate.expired', 'description': 'Certificate expired', 'category': 'certification'},
    {'code': 'compliance.warning', 'description': 'Compliance warning', 'category': 'compliance'},
    {'code': 'compliance.escalation', 'description': 'Compliance escalation', 'category': 'compliance'},
    {'code': 'induction.assigned', 'description': 'Induction assigned', 'category': 'induction'},
    {'code': 'induction.reminder', 'description': 'Induction reminder', 'category': 'induction'},
    {'code': 'induction.completed', 'description': 'Induction completed', 'category': 'induction'},
    {'code': 'document.new_version', 'description': 'New document version available', 'category': 'document'},
    {'code': 'document.reading_due', 'description': 'Document reading due', 'category': 'document'},
    {'code': 'password.expiring', 'description': 'Password expiring soon', 'category': 'security'},
    {'code': 'account.locked', 'description': 'Account locked', 'category': 'security'},
  ];

  return ApiResponse.ok({
    'event_codes': eventCodes,
  }).toResponse();
}

/// GET /v1/access/mail-settings/subscriptions
///
/// Lists employee's mail subscriptions (current user or admin view).
Future<Response> mailSubscriptionsListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final query = req.url.queryParameters;

  String employeeId = auth.employeeId;
  
  // Admin can view any employee's subscriptions
  if (query['employee_id'] != null && auth.hasPermission(Permissions.manageEmployees)) {
    employeeId = query['employee_id']!;
  }

  final result = await supabase
      .from('mail_event_subscriptions')
      .select('''
        id, event_code, is_subscribed, delivery_method,
        digest_enabled, digest_frequency, created_at, updated_at
      ''')
      .eq('employee_id', employeeId)
      .order('event_code');

  return ApiResponse.ok({
    'employee_id': employeeId,
    'subscriptions': result,
  }).toResponse();
}

/// POST /v1/access/mail-settings/subscriptions
///
/// Creates or updates a mail subscription.
Future<Response> mailSubscriptionUpsertHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final eventCode = requireString(body, 'event_code');
  final isSubscribed = body['is_subscribed'] as bool? ?? true;
  final deliveryMethod = body['delivery_method'] as String? ?? 'EMAIL';
  final digestEnabled = body['digest_enabled'] as bool? ?? false;
  final digestFrequency = body['digest_frequency'] as String? ?? 'DAILY';

  // Validate delivery method
  if (!['EMAIL', 'IN_APP', 'BOTH', 'NONE'].contains(deliveryMethod)) {
    throw ValidationException({
      'delivery_method': 'Must be EMAIL, IN_APP, BOTH, or NONE',
    });
  }

  // Validate digest frequency
  if (!['IMMEDIATE', 'DAILY', 'WEEKLY'].contains(digestFrequency)) {
    throw ValidationException({
      'digest_frequency': 'Must be IMMEDIATE, DAILY, or WEEKLY',
    });
  }

  final result = await supabase
      .from('mail_event_subscriptions')
      .upsert({
        'employee_id': auth.employeeId,
        'event_code': eventCode,
        'is_subscribed': isSubscribed,
        'delivery_method': deliveryMethod,
        'digest_enabled': digestEnabled,
        'digest_frequency': digestFrequency,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .select()
      .single();

  return ApiResponse.ok({
    'subscription': result,
    'message': 'Mail subscription updated',
  }).toResponse();
}

/// DELETE /v1/access/mail-settings/subscriptions/:eventCode
///
/// Removes a mail subscription (sets is_subscribed to false).
Future<Response> mailSubscriptionDeleteHandler(Request req) async {
  final eventCode = req.rawPathParameters[#eventCode];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (eventCode == null || eventCode.isEmpty) {
    throw ValidationException({'eventCode': 'Event code is required'});
  }

  await supabase
      .from('mail_event_subscriptions')
      .update({
        'is_subscribed': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('employee_id', auth.employeeId)
      .eq('event_code', eventCode);

  return ApiResponse.ok({
    'message': 'Unsubscribed from event',
  }).toResponse();
}

/// POST /v1/access/mail-settings/templates/:id/test
///
/// Sends a test email using a template.
Future<Response> mailTemplateTestHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageEmployees)) {
    throw PermissionDeniedException('You do not have permission to test mail templates');
  }

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  final recipientEmail = body['recipient_email'] as String? ?? auth.email;
  final testVariables = body['variables'] as Map<String, dynamic>? ?? {};

  if (recipientEmail == null || recipientEmail.isEmpty) {
    throw ValidationException({'recipient_email': 'Recipient email is required'});
  }

  // Get template
  final template = await supabase
      .from('mail_event_templates')
      .select('*')
      .eq('id', templateId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (template == null) {
    throw NotFoundException('Mail template not found');
  }

  // Publish test email event
  await OutboxService(supabase).publish(
    aggregateType: 'mail_template_test',
    aggregateId: templateId,
    eventType: 'mail.test_requested',
    payload: {
      'template_id': templateId,
      'recipient_email': recipientEmail,
      'variables': testVariables,
      'requested_by': auth.employeeId,
    },
  );

  return ApiResponse.ok({
    'message': 'Test email queued for delivery',
    'recipient': recipientEmail,
  }).toResponse();
}
