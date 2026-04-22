import 'dart:io';

import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart';

import '../../services/report_generator_service.dart';

/// POST /jobs/generate-reports
///
/// Triggered by cron to process queued report generation jobs.
/// This endpoint is called internally by the job scheduler.
Future<Response> reportGenerationHandler(Request req) async {
  // Get Supabase client from request context or environment
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  
  if (supabaseUrl == null || supabaseKey == null) {
    return Response(500, body: Body.fromString(
      '{"error": "Missing Supabase configuration"}',
      mimeType: MimeType.json,
    ));
  }

  final supabase = SupabaseClient(supabaseUrl, supabaseKey);
  final service = ReportGeneratorService(supabase);

  // Process queued reports (one at a time)
  await service.processQueuedReports();

  return Response(
    200,
    body: Body.fromString(
      '{"status": "ok"}',
      mimeType: MimeType.json,
    ),
  );
}
