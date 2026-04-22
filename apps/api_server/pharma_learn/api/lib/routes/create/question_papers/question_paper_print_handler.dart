import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/question-papers/:id/print
///
/// Generates a PDF of the question paper for offline exams.
/// Query params: include_answers=true for answer key variant
Future<Response> questionPaperPrintHandler(Request req) async {
  final paperId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to print question papers');
  }

  if (paperId == null || paperId.isEmpty) {
    throw ValidationException({'id': 'Question Paper ID is required'});
  }

  final includeAnswers = req.url.queryParameters['include_answers'] == 'true';

  // Get question paper
  final paper = await supabase
      .from('question_papers')
      .select('''
        id, name, paper_code, status, total_marks, time_limit_minutes,
        instructions, pass_mark,
        course:courses(id, title, course_code),
        items:question_paper_items(
          id, sequence_order, marks,
          question:question_bank_questions(
            id, question_text, question_type, options,
            correct_answer, explanation, marks
          )
        )
      ''')
      .eq('id', paperId)
      .eq('organization_id', auth.orgId)
      .maybeSingle();

  if (paper == null) {
    throw NotFoundException('Question paper not found');
  }

  // Verify paper is published
  if (paper['status'] != 'published') {
    throw ValidationException({
      'paper': 'Question paper must be published before printing',
    });
  }

  // Sort items by sequence order
  final items = paper['items'] as List;
  items.sort((a, b) => 
    (a['sequence_order'] as int).compareTo(b['sequence_order'] as int));

  // Call Edge Function to generate PDF
  try {
    final response = await supabase.functions.invoke(
      'generate-question-paper',
      body: {
        'paper_id': paperId,
        'paper': paper,
        'include_answers': includeAnswers,
        'generated_by': auth.employeeId,
        'organization_id': auth.orgId,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to generate question paper PDF: ${response.data}');
    }

    final data = response.data as Map<String, dynamic>;
    final storagePath = data['storage_path'] as String;

    // Get signed URL
    final signedUrl = await supabase.storage
        .from('pharmalearn-files')
        .createSignedUrl(storagePath, 3600); // 1 hour expiry

    // Log audit trail
    await supabase.from('audit_trails').insert({
      'entity_type': 'question_paper',
      'entity_id': paperId,
      'action': 'print_generated',
      'actor_id': auth.employeeId,
      'organization_id': auth.orgId,
      'changes': {
        'include_answers': includeAnswers,
        'question_count': items.length,
      },
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    return ApiResponse.ok({
      'download_url': signedUrl,
      'expires_in_seconds': 3600,
      'paper': {
        'id': paper['id'],
        'name': paper['name'],
        'paper_code': paper['paper_code'],
      },
      'question_count': items.length,
      'includes_answers': includeAnswers,
    }).toResponse();
  } catch (e) {
    // Fallback: return data for client-side rendering
    // Remove correct answers if not requested
    final sanitizedItems = includeAnswers
        ? items
        : items.map((item) {
            final question = Map<String, dynamic>.from(item['question'] as Map);
            question.remove('correct_answer');
            question.remove('explanation');
            return {
              ...item,
              'question': question,
            };
          }).toList();

    return ApiResponse.ok({
      'paper': {
        'id': paper['id'],
        'name': paper['name'],
        'paper_code': paper['paper_code'],
        'instructions': paper['instructions'],
        'total_marks': paper['total_marks'],
        'time_limit_minutes': paper['time_limit_minutes'],
        'course': paper['course'],
      },
      'items': sanitizedItems,
      'includes_answers': includeAnswers,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'render_mode': 'client',
      'message': 'Edge Function unavailable. Use provided data for client-side PDF generation.',
    }).toResponse();
  }
}
