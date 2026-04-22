import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/batches/:id/attendance-sheet
///
/// Generates a PDF attendance roster for paper sign-in.
/// Returns a signed URL to download the PDF.
Future<Response> batchAttendanceSheetHandler(Request req) async {
  final batchId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageTraining)) {
    throw PermissionDeniedException('You do not have permission to generate attendance sheets');
  }

  if (batchId == null || batchId.isEmpty) {
    throw ValidationException({'id': 'Batch ID is required'});
  }

  // Get batch details
  final batch = await supabase
      .from('training_batches')
      .select('''
        id, name, start_date, end_date,
        course:courses(id, title, course_code),
        sessions:training_sessions(
          id, session_date, start_time, end_time,
          venue:venues(id, name, address)
        ),
        organization:organizations(id, name, short_code)
      ''')
      .eq('id', batchId)
      .maybeSingle();

  if (batch == null) {
    throw NotFoundException('Batch not found');
  }

  // Get enrolled employees
  final enrollments = await supabase
      .from('schedule_enrollments')
      .select('''
        id,
        employee:employees(
          id, employee_code, first_name, last_name, 
          department:departments(id, name)
        )
      ''')
      .eq('batch_id', batchId)
      .order('employee.last_name');

  // Call Edge Function to generate PDF
  try {
    final response = await supabase.functions.invoke(
      'generate-attendance-sheet',
      body: {
        'batch_id': batchId,
        'batch': batch,
        'enrollments': enrollments,
        'generated_by': auth.employeeId,
        'organization_id': auth.orgId,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to generate attendance sheet: ${response.data}');
    }

    final data = response.data as Map<String, dynamic>;
    final storagePath = data['storage_path'] as String;

    // Get signed URL
    final signedUrl = await supabase.storage
        .from('pharmalearn-files')
        .createSignedUrl(storagePath, 3600); // 1 hour expiry

    return ApiResponse.ok({
      'download_url': signedUrl,
      'expires_in_seconds': 3600,
      'batch': {
        'id': batch['id'],
        'name': batch['name'],
      },
      'employee_count': (enrollments as List).length,
    }).toResponse();
  } catch (e) {
    // Fallback: generate data for client-side rendering
    return ApiResponse.ok({
      'batch': batch,
      'enrollments': enrollments,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'render_mode': 'client',
      'message': 'Edge Function unavailable. Use provided data for client-side PDF generation.',
    }).toResponse();
  }
}
