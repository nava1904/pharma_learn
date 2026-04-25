import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/question-banks
///
/// Lists question banks with filters.
Future<Response> questionBanksListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to view question banks');
  }

  final params = req.url.queryParameters;
  final page = int.tryParse(params['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(params['per_page'] ?? '20') ?? 20;
  final courseId = params['course_id'];
  final category = params['category'];

  var countQuery = supabase.from('question_banks').select('id');
  if (courseId != null) countQuery = countQuery.eq('course_id', courseId);
  if (category != null) countQuery = countQuery.eq('category', category);
  final countResult = await countQuery;
  final total = countResult.length;

  var query = supabase
      .from('question_banks')
      .select('''
        id, name, description, category, is_active, created_at,
        courses(id, name, course_code),
        questions(count)
      ''');

  if (courseId != null) query = query.eq('course_id', courseId);
  if (category != null) query = query.eq('category', category);

  final banks = await query
      .order('name', ascending: true)
      .range((page - 1) * perPage, page * perPage - 1);

  // Transform to include question count
  final data = banks.map((b) {
    final questions = b['questions'] as List? ?? [];
    return {
      ...Map<String, dynamic>.from(b as Map)..remove('questions'),
      'question_count': questions.isEmpty ? 0 : (questions[0]['count'] ?? 0),
    };
  }).toList();

  return ApiResponse.paginated(
    data,
    Pagination.compute(page: page, perPage: perPage, total: total),
  ).toResponse();
}

/// GET /v1/question-banks/:id
///
/// Gets a question bank with its questions.
Future<Response> questionBankGetHandler(Request req) async {
  final bankId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (bankId == null || bankId.isEmpty) {
    throw ValidationException({'id': 'Question bank ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to view question banks');
  }

  final bank = await supabase
      .from('question_banks')
      .select('''
        *,
        courses(id, name, course_code),
        questions(
          id, question_text, question_type, difficulty, points, is_active,
          question_options(id, option_text, is_correct, sort_order)
        )
      ''')
      .eq('id', bankId)
      .maybeSingle();

  if (bank == null) {
    throw NotFoundException('Question bank not found');
  }

  return ApiResponse.ok(bank).toResponse();
}

/// POST /v1/question-banks
///
/// Creates a new question bank.
/// Body: { name, description?, course_id?, category? }
Future<Response> questionBankCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to create question banks');
  }

  final name = requireString(body, 'name');

  final now = DateTime.now().toUtc().toIso8601String();

  final bank = await supabase
      .from('question_banks')
      .insert({
        'name': name,
        'description': body['description'],
        'course_id': body['course_id'],
        'category': body['category'],
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  return ApiResponse.created(bank).toResponse();
}

/// PATCH /v1/question-banks/:id
///
/// Updates a question bank.
Future<Response> questionBankUpdateHandler(Request req) async {
  final bankId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (bankId == null || bankId.isEmpty) {
    throw ValidationException({'id': 'Question bank ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to update question banks');
  }

  final existing = await supabase
      .from('question_banks')
      .select('id')
      .eq('id', bankId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Question bank not found');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = ['name', 'description', 'course_id', 'category', 'is_active'];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('question_banks')
      .update(updateData)
      .eq('id', bankId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/question-banks/:id
///
/// Deletes a question bank (if no questions or unused in assessments).
Future<Response> questionBankDeleteHandler(Request req) async {
  final bankId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (bankId == null || bankId.isEmpty) {
    throw ValidationException({'id': 'Question bank ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to delete question banks');
  }

  // Check for questions
  final questions = await supabase
      .from('questions')
      .select('id')
      .eq('question_bank_id', bankId)
      .limit(1);

  if (questions.isNotEmpty) {
    throw ConflictException('Cannot delete question bank with questions. Remove questions first.');
  }

  await supabase.from('question_banks').delete().eq('id', bankId);

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/question-banks/:id/questions
///
/// Adds a question to a bank.
/// Body: { question_text, question_type, difficulty?, points?, options?: [...] }
Future<Response> questionCreateHandler(Request req) async {
  final bankId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (bankId == null || bankId.isEmpty) {
    throw ValidationException({'id': 'Question bank ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to create questions');
  }

  // Verify bank exists
  final bank = await supabase
      .from('question_banks')
      .select('id')
      .eq('id', bankId)
      .maybeSingle();

  if (bank == null) {
    throw NotFoundException('Question bank not found');
  }

  final questionText = requireString(body, 'question_text');
  final questionType = requireString(body, 'question_type');

  final now = DateTime.now().toUtc().toIso8601String();

  final question = await supabase
      .from('questions')
      .insert({
        'question_bank_id': bankId,
        'question_text': questionText,
        'question_type': questionType,
        'difficulty': body['difficulty'] ?? 'medium',
        'points': body['points'] ?? 1,
        'explanation': body['explanation'],
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  // Add options if provided (for multiple choice)
  final options = body['options'] as List?;
  if (options != null && options.isNotEmpty) {
    var sortOrder = 0;
    for (final option in options) {
      await supabase.from('question_options').insert({
        'question_id': question['id'],
        'option_text': option['text'],
        'is_correct': option['is_correct'] ?? false,
        'sort_order': sortOrder++,
      });
    }
  }

  // Refetch with options
  final fullQuestion = await supabase
      .from('questions')
      .select('*, question_options(*)')
      .eq('id', question['id'])
      .single();

  return ApiResponse.created(fullQuestion).toResponse();
}

/// PATCH /v1/questions/:id
///
/// Updates a question.
Future<Response> questionUpdateHandler(Request req) async {
  final questionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (questionId == null || questionId.isEmpty) {
    throw ValidationException({'id': 'Question ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to update questions');
  }

  final existing = await supabase
      .from('questions')
      .select('id')
      .eq('id', questionId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Question not found');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  final allowedFields = [
    'question_text', 'question_type', 'difficulty', 'points', 'explanation', 'is_active'
  ];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('questions')
      .update(updateData)
      .eq('id', questionId)
      .select('*, question_options(*)')
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/questions/:id
///
/// Deletes a question.
Future<Response> questionDeleteHandler(Request req) async {
  final questionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (questionId == null || questionId.isEmpty) {
    throw ValidationException({'id': 'Question ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageAssessments)) {
    throw PermissionDeniedException('You do not have permission to delete questions');
  }

  // Delete options first
  await supabase.from('question_options').delete().eq('question_id', questionId);
  
  // Delete question
  await supabase.from('questions').delete().eq('id', questionId);

  return ApiResponse.noContent().toResponse();
}
