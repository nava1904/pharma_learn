import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/feedback-templates
///
/// Lists all feedback templates with pagination and filters.
/// Query params: page, per_page, is_active, type
Future<Response> feedbackTemplatesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;
  final isActive = params['is_active'];
  final templateType = params['type'];

  var query = supabase
      .from('feedback_templates')
      .select('''
        id, name, description, template_type, questions,
        is_active, created_at, updated_at,
        created_by_employee:employees!feedback_templates_created_by_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('organization_id', auth.orgId);

  if (isActive != null) {
    query = query.eq('is_active', isActive == 'true');
  }

  if (templateType != null) {
    query = query.eq('template_type', templateType);
  }

  final countQuery = supabase
      .from('feedback_templates')
      .select('id')
      .eq('organization_id', auth.orgId);

  final results = await query
      .order('name', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  final countResult = await countQuery;
  final total = (countResult as List).length;

  return ApiResponse.ok({
    'feedback_templates': results,
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': total,
      'total_pages': (total / perPage).ceil(),
    },
  }).toResponse();
}

/// POST /v1/feedback-templates
///
/// Creates a new feedback template.
/// Body: { name, description?, template_type, questions: [{text, type, options?, required?}], is_active? }
Future<Response> feedbackTemplateCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to create feedback templates');
  }

  final name = requireString(body, 'name');
  final description = body['description'] as String?;
  final templateType = requireString(body, 'template_type');
  final questions = body['questions'] as List<dynamic>?;
  if (questions == null || questions.isEmpty) {
    throw ValidationException({'questions': 'At least one question is required'});
  }
  final isActive = body['is_active'] as bool? ?? true;

  // Validate template_type
  if (!['session', 'trainer', 'course', 'general'].contains(templateType)) {
    throw ValidationException({
      'template_type': 'Must be one of: session, trainer, course, general',
    });
  }

  // Validate questions structure
  for (int i = 0; i < questions.length; i++) {
    final q = questions[i] as Map<String, dynamic>;
    if (q['text'] == null || (q['text'] as String).isEmpty) {
      throw ValidationException({
        'questions[$i].text': 'Question text is required',
      });
    }
    if (q['type'] == null) {
      throw ValidationException({
        'questions[$i].type': 'Question type is required',
      });
    }
    final validTypes = ['rating', 'text', 'single_choice', 'multiple_choice', 'scale'];
    if (!validTypes.contains(q['type'])) {
      throw ValidationException({
        'questions[$i].type': 'Must be one of: ${validTypes.join(', ')}',
      });
    }
  }

  final result = await supabase
      .from('feedback_templates')
      .insert({
        'organization_id': auth.orgId,
        'name': name,
        'description': description,
        'template_type': templateType,
        'questions': questions,
        'is_active': isActive,
        'created_by': auth.employeeId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'feedback_template',
    aggregateId: result['id'] as String,
    eventType: 'feedback_template.created',
    payload: {'name': name, 'type': templateType},
  );

  return ApiResponse.created(result).toResponse();
}

/// GET /v1/feedback-templates/:id
///
/// Gets a specific feedback template.
Future<Response> feedbackTemplateGetHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  final result = await supabase
      .from('feedback_templates')
      .select('''
        id, name, description, template_type, questions,
        is_active, created_at, updated_at,
        created_by_employee:employees!feedback_templates_created_by_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('id', templateId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    throw NotFoundException('Feedback template not found');
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/feedback-templates/:id
///
/// Updates a feedback template.
/// Body: { name?, description?, questions?, is_active? }
Future<Response> feedbackTemplatePatchHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to update feedback templates');
  }

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  // Check template exists
  final existing = await supabase
      .from('feedback_templates')
      .select('id, is_active')
      .eq('id', templateId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Feedback template not found');
  }

  final updates = <String, dynamic>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  if (body.containsKey('name')) {
    updates['name'] = requireString(body, 'name');
  }
  if (body.containsKey('description')) {
    updates['description'] = body['description'];
  }
  if (body.containsKey('questions')) {
    updates['questions'] = body['questions'];
  }
  if (body.containsKey('is_active')) {
    updates['is_active'] = body['is_active'] as bool;
  }

  final result = await supabase
      .from('feedback_templates')
      .update(updates)
      .eq('id', templateId)
      .select()
      .single();

  return ApiResponse.ok(result).toResponse();
}

/// DELETE /v1/feedback-templates/:id
///
/// Soft-deletes a feedback template (sets is_active=false).
/// If template has been used, marks inactive instead of deleting.
Future<Response> feedbackTemplateDeleteHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to delete feedback templates');
  }

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  // Check template exists
  final existing = await supabase
      .from('feedback_templates')
      .select('id')
      .eq('id', templateId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Feedback template not found');
  }

  // Check if template has been used in any feedback submissions
  final usageCount = await supabase
      .from('session_feedback')
      .select('id')
      .eq('feedback_template_id', templateId)
      .limit(1);

  if ((usageCount as List).isNotEmpty) {
    // Template has been used - soft delete only
    await supabase
        .from('feedback_templates')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', templateId);

    return ApiResponse.ok({
      'message': 'Template has been deactivated (has existing responses)',
      'deleted': false,
      'deactivated': true,
    }).toResponse();
  }

  // No usage - can hard delete
  await supabase
      .from('feedback_templates')
      .delete()
      .eq('id', templateId);

  return ApiResponse.noContent().toResponse();
}
