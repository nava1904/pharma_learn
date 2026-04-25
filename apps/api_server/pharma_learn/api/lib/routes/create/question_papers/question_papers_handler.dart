import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/question-papers
///
/// Lists question papers (assessment templates).
Future<Response> questionPapersListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to view question papers');
  }

  final params = req.url.queryParameters;
  final courseId = params['course_id'];
  final status = params['status'];

  var query = supabase
      .from('question_papers')
      .select('''
        id, name, description, status, total_marks, passing_marks, 
        duration_minutes, randomize_questions, created_at,
        courses(id, name, course_code),
        question_paper_items(count)
      ''');

  if (courseId != null) query = query.eq('course_id', courseId);
  if (status != null) query = query.eq('status', status);

  final papers = await query.order('name', ascending: true);

  final data = papers.map((p) {
    final items = p['question_paper_items'] as List? ?? [];
    return {
      ...Map<String, dynamic>.from(p as Map)..remove('question_paper_items'),
      'question_count': items.isEmpty ? 0 : (items[0]['count'] ?? 0),
    };
  }).toList();

  return ApiResponse.ok(data).toResponse();
}

/// GET /v1/question-papers/:id
Future<Response> questionPaperGetHandler(Request req) async {
  final paperId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (paperId == null || paperId.isEmpty) {
    throw ValidationException({'id': 'Question paper ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to view question papers');
  }

  final paper = await supabase
      .from('question_papers')
      .select('''
        *,
        courses(id, name, course_code),
        question_paper_items(
          id, sort_order, marks,
          questions(id, question_text, question_type, difficulty, points)
        )
      ''')
      .eq('id', paperId)
      .maybeSingle();

  if (paper == null) {
    throw NotFoundException('Question paper not found');
  }

  return ApiResponse.ok(paper).toResponse();
}

/// POST /v1/question-papers
///
/// Creates a new question paper.
/// Body: { name, course_id?, total_marks, passing_marks, duration_minutes, ... }
Future<Response> questionPaperCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to create question papers');
  }

  final name = requireString(body, 'name');

  final now = DateTime.now().toUtc().toIso8601String();

  final paper = await supabase
      .from('question_papers')
      .insert({
        'name': name,
        'description': body['description'],
        'course_id': body['course_id'],
        'total_marks': body['total_marks'] ?? 100,
        'passing_marks': body['passing_marks'] ?? 60,
        'duration_minutes': body['duration_minutes'] ?? 60,
        'randomize_questions': body['randomize_questions'] ?? false,
        'show_results_immediately': body['show_results_immediately'] ?? true,
        'allow_review': body['allow_review'] ?? true,
        'max_attempts': body['max_attempts'] ?? 3,
        'status': 'draft',
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(paper).toResponse();
}

/// PATCH /v1/question-papers/:id
Future<Response> questionPaperUpdateHandler(Request req) async {
  final paperId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (paperId == null || paperId.isEmpty) {
    throw ValidationException({'id': 'Question paper ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to update question papers');
  }

  final existing = await supabase
      .from('question_papers')
      .select('id, status')
      .eq('id', paperId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Question paper not found');
  }

  if (existing['status'] == 'published') {
    throw ConflictException('Cannot modify a published question paper');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = [
    'name', 'description', 'course_id', 'total_marks', 'passing_marks',
    'duration_minutes', 'randomize_questions', 'show_results_immediately',
    'allow_review', 'max_attempts',
  ];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('question_papers')
      .update(updateData)
      .eq('id', paperId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// POST /v1/question-papers/:id/questions
///
/// Adds a question to a paper.
/// Body: { question_id, sort_order?, marks? }
Future<Response> questionPaperAddQuestionHandler(Request req) async {
  final paperId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (paperId == null || paperId.isEmpty) {
    throw ValidationException({'id': 'Question paper ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to modify question papers');
  }

  final questionId = requireUuid(body, 'question_id');

  await supabase.from('question_paper_items').upsert(
    {
      'question_paper_id': paperId,
      'question_id': questionId,
      'sort_order': body['sort_order'] ?? 0,
      'marks': body['marks'] ?? 1,
    },
    onConflict: 'question_paper_id,question_id',
  );

  return ApiResponse.ok({'message': 'Question added to paper'}).toResponse();
}

/// DELETE /v1/question-papers/:id/questions/:questionId
Future<Response> questionPaperRemoveQuestionHandler(Request req) async {
  final paperId = req.rawPathParameters[#id];
  final questionId = req.rawPathParameters[#questionId];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (paperId == null || questionId == null) {
    throw ValidationException({'id': 'Paper ID and Question ID are required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to modify question papers');
  }

  await supabase
      .from('question_paper_items')
      .delete()
      .eq('question_paper_id', paperId)
      .eq('question_id', questionId);

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/question-papers/:id/publish
///
/// Publishes a question paper.
Future<Response> questionPaperPublishHandler(Request req) async {
  final paperId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (paperId == null || paperId.isEmpty) {
    throw ValidationException({'id': 'Question paper ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to publish question papers');
  }

  final existing = await supabase
      .from('question_papers')
      .select('id, status')
      .eq('id', paperId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Question paper not found');
  }

  if (existing['status'] != 'draft') {
    throw ConflictException('Only draft papers can be published');
  }

  // Check it has questions
  final items = await supabase
      .from('question_paper_items')
      .select('id')
      .eq('question_paper_id', paperId)
      .limit(1);

  if (items.isEmpty) {
    throw ValidationException({'questions': 'Paper must have at least one question'});
  }

  await supabase
      .from('question_papers')
      .update({
        'status': 'published',
        'published_by': auth.employeeId,
        'published_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', paperId);

  return ApiResponse.ok({'message': 'Question paper published'}).toResponse();
}

/// DELETE /v1/question-papers/:id
Future<Response> questionPaperDeleteHandler(Request req) async {
  final paperId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (paperId == null || paperId.isEmpty) {
    throw ValidationException({'id': 'Question paper ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to delete question papers');
  }

  final existing = await supabase
      .from('question_papers')
      .select('id, status')
      .eq('id', paperId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Question paper not found');
  }

  if (existing['status'] == 'published') {
    throw ConflictException('Cannot delete a published question paper');
  }

  // Delete items first
  await supabase.from('question_paper_items').delete().eq('question_paper_id', paperId);
  
  // Delete paper
  await supabase.from('question_papers').delete().eq('id', paperId);

  return ApiResponse.noContent().toResponse();
}
