import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/evaluation-templates
///
/// Lists all evaluation templates with pagination and filters.
/// Query params: page, per_page, is_active, evaluation_type
Future<Response> evaluationTemplatesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;
  final isActive = params['is_active'];
  final evalType = params['evaluation_type'];

  var query = supabase
      .from('evaluation_templates')
      .select('''
        id, name, description, evaluation_type, questions,
        rating_scale, is_active, created_at, updated_at,
        created_by_employee:employees!evaluation_templates_created_by_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('organization_id', auth.orgId);

  if (isActive != null) {
    query = query.eq('is_active', isActive == 'true');
  }

  if (evalType != null) {
    query = query.eq('evaluation_type', evalType);
  }

  final countQuery = supabase
      .from('evaluation_templates')
      .select('id')
      .eq('organization_id', auth.orgId);

  final results = await query
      .order('name', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  final countResult = await countQuery;
  final total = (countResult as List).length;

  return ApiResponse.ok({
    'evaluation_templates': results,
    'pagination': {
      'page': page,
      'per_page': perPage,
      'total': total,
      'total_pages': (total / perPage).ceil(),
    },
  }).toResponse();
}

/// POST /v1/evaluation-templates
///
/// Creates a new evaluation template.
/// Body: { name, description?, evaluation_type, questions: [], rating_scale?, is_active? }
Future<Response> evaluationTemplateCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to create evaluation templates');
  }

  final name = requireString(body, 'name');
  final description = body['description'] as String?;
  final evaluationType = requireString(body, 'evaluation_type');
  final questions = body['questions'] as List<dynamic>?;
  if (questions == null || questions.isEmpty) {
    throw ValidationException({'questions': 'At least one question is required'});
  }
  final ratingScale = body['rating_scale'] as Map<String, dynamic>?;
  final isActive = body['is_active'] as bool? ?? true;

  // Validate evaluation_type
  if (!['short_term', 'long_term', 'competency', 'performance'].contains(evaluationType)) {
    throw ValidationException({
      'evaluation_type': 'Must be one of: short_term, long_term, competency, performance',
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
  }

  final result = await supabase
      .from('evaluation_templates')
      .insert({
        'organization_id': auth.orgId,
        'name': name,
        'description': description,
        'evaluation_type': evaluationType,
        'questions': questions,
        'rating_scale': ratingScale ?? {
          'min': 1,
          'max': 5,
          'labels': {
            '1': 'Poor',
            '2': 'Below Average',
            '3': 'Average',
            '4': 'Good',
            '5': 'Excellent',
          },
        },
        'is_active': isActive,
        'created_by': auth.employeeId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      })
      .select()
      .single();

  await OutboxService(supabase).publish(
    aggregateType: 'evaluation_template',
    aggregateId: result['id'] as String,
    eventType: 'evaluation_template.created',
    payload: {'name': name, 'type': evaluationType},
  );

  return ApiResponse.created(result).toResponse();
}

/// GET /v1/evaluation-templates/:id
///
/// Gets a specific evaluation template.
Future<Response> evaluationTemplateGetHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  final result = await supabase
      .from('evaluation_templates')
      .select('''
        id, name, description, evaluation_type, questions,
        rating_scale, is_active, created_at, updated_at,
        created_by_employee:employees!evaluation_templates_created_by_fkey(
          id, first_name, last_name
        )
      ''')
      .eq('id', templateId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (result == null) {
    throw NotFoundException('Evaluation template not found');
  }

  return ApiResponse.ok(result).toResponse();
}

/// PATCH /v1/evaluation-templates/:id
///
/// Updates an evaluation template.
/// Body: { name?, description?, questions?, rating_scale?, is_active? }
Future<Response> evaluationTemplatePatchHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to update evaluation templates');
  }

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  // Check template exists
  final existing = await supabase
      .from('evaluation_templates')
      .select('id')
      .eq('id', templateId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Evaluation template not found');
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
  if (body.containsKey('rating_scale')) {
    updates['rating_scale'] = body['rating_scale'];
  }
  if (body.containsKey('is_active')) {
    updates['is_active'] = body['is_active'] as bool;
  }

  final result = await supabase
      .from('evaluation_templates')
      .update(updates)
      .eq('id', templateId)
      .select()
      .single();

  return ApiResponse.ok(result).toResponse();
}

/// DELETE /v1/evaluation-templates/:id
///
/// Soft-deletes an evaluation template.
Future<Response> evaluationTemplateDeleteHandler(Request req) async {
  final templateId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to delete evaluation templates');
  }

  if (templateId == null || templateId.isEmpty) {
    throw ValidationException({'id': 'Template ID is required'});
  }

  // Check template exists
  final existing = await supabase
      .from('evaluation_templates')
      .select('id')
      .eq('id', templateId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Evaluation template not found');
  }

  // Check if template has been used
  final shortTermUsage = await supabase
      .from('short_term_evaluations')
      .select('id')
      .eq('evaluation_template_id', templateId)
      .limit(1);

  final longTermUsage = await supabase
      .from('long_term_evaluations')
      .select('id')
      .eq('evaluation_template_id', templateId)
      .limit(1);

  if ((shortTermUsage as List).isNotEmpty || (longTermUsage as List).isNotEmpty) {
    // Template has been used - soft delete only
    await supabase
        .from('evaluation_templates')
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', templateId);

    return ApiResponse.ok({
      'message': 'Template has been deactivated (has existing evaluations)',
      'deleted': false,
      'deactivated': true,
    }).toResponse();
  }

  // No usage - can hard delete
  await supabase
      .from('evaluation_templates')
      .delete()
      .eq('id', templateId);

  return ApiResponse.noContent().toResponse();
}
