import 'package:supabase/supabase.dart';

/// Service for PDF generation via Supabase Edge Functions.
///
/// Calls the 'generate-pdf' Edge Function which:
/// 1. Generates the PDF using a template
/// 2. Stores it in Supabase Storage
/// 3. Returns the storage path
///
/// Reference: plan.md — Certificate PDF generation (calls Edge Function)
class PdfService {
  final SupabaseClient _supabase;

  /// Storage bucket for generated PDFs
  static const String certificateBucket = 'certificates';
  static const String documentBucket = 'documents';

  PdfService(this._supabase);

  /// Generates a certificate PDF for a training completion.
  ///
  /// Calls the 'generate-certificate-pdf' Edge Function with certificate data.
  /// Returns the storage path of the generated PDF.
  ///
  /// Reference: EE §5.1.12 — print certificates
  Future<String> generateCertificatePdf({
    required String certificateId,
    required String certificateNumber,
    required String employeeName,
    required String courseName,
    required String courseCode,
    required DateTime issuedAt,
    required DateTime? validUntil,
    required String organizationName,
    required String orgId,
  }) async {
    final response = await _supabase.functions.invoke(
      'generate-certificate-pdf',
      body: {
        'certificate_id': certificateId,
        'certificate_number': certificateNumber,
        'employee_name': employeeName,
        'course_name': courseName,
        'course_code': courseCode,
        'issued_at': issuedAt.toIso8601String(),
        'valid_until': validUntil?.toIso8601String(),
        'organization_name': organizationName,
        'org_id': orgId,
      },
    );

    if (response.status != 200) {
      throw PdfGenerationException(
        'Failed to generate certificate PDF: ${response.data}',
      );
    }

    final data = response.data as Map<String, dynamic>;
    return data['storage_path'] as String;
  }

  /// Generates a document export PDF with approval history.
  ///
  /// Creates a PDF containing:
  /// - Document content
  /// - Version history
  /// - All e-signature records
  /// - Audit trail
  ///
  /// Reference: 21 CFR §11.10(b) — printable/retrievable format
  Future<String> generateDocumentExportPdf({
    required String documentId,
    required String documentNumber,
    required String title,
    required String content,
    required List<Map<String, dynamic>> versions,
    required List<Map<String, dynamic>> signatures,
    required List<Map<String, dynamic>> auditTrail,
    required String orgId,
  }) async {
    final response = await _supabase.functions.invoke(
      'generate-document-pdf',
      body: {
        'document_id': documentId,
        'document_number': documentNumber,
        'title': title,
        'content': content,
        'versions': versions,
        'signatures': signatures,
        'audit_trail': auditTrail,
        'org_id': orgId,
      },
    );

    if (response.status != 200) {
      throw PdfGenerationException(
        'Failed to generate document PDF: ${response.data}',
      );
    }

    final data = response.data as Map<String, dynamic>;
    return data['storage_path'] as String;
  }

  /// Generates an audit trail export PDF/CSV.
  ///
  /// Reference: 21 CFR §11.10(b) — printable audit trail for inspection
  Future<String> generateAuditExportPdf({
    required String entityType,
    required String entityId,
    required List<Map<String, dynamic>> auditEntries,
    required String exportFormat, // 'pdf' or 'csv'
    required String orgId,
  }) async {
    final response = await _supabase.functions.invoke(
      'generate-audit-export',
      body: {
        'entity_type': entityType,
        'entity_id': entityId,
        'audit_entries': auditEntries,
        'format': exportFormat,
        'org_id': orgId,
      },
    );

    if (response.status != 200) {
      throw PdfGenerationException(
        'Failed to generate audit export: ${response.data}',
      );
    }

    final data = response.data as Map<String, dynamic>;
    return data['storage_path'] as String;
  }

  /// Gets a signed URL for downloading a PDF.
  ///
  /// The URL is valid for [expiresIn] seconds (default 5 minutes).
  Future<String> getSignedDownloadUrl(
    String bucket,
    String path, {
    int expiresIn = 300,
  }) async {
    return _supabase.storage.from(bucket).createSignedUrl(path, expiresIn);
  }

  /// Generates a training record summary PDF for an employee.
  ///
  /// Reference: EE §5.1.23 — training history export
  Future<String> generateTrainingHistoryPdf({
    required String employeeId,
    required String employeeName,
    required String employeeNumber,
    required List<Map<String, dynamic>> trainingRecords,
    required List<Map<String, dynamic>> certificates,
    required String orgId,
  }) async {
    final response = await _supabase.functions.invoke(
      'generate-training-history-pdf',
      body: {
        'employee_id': employeeId,
        'employee_name': employeeName,
        'employee_number': employeeNumber,
        'training_records': trainingRecords,
        'certificates': certificates,
        'org_id': orgId,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    if (response.status != 200) {
      throw PdfGenerationException(
        'Failed to generate training history PDF: ${response.data}',
      );
    }

    final data = response.data as Map<String, dynamic>;
    return data['storage_path'] as String;
  }

  /// Generates a compliance report PDF.
  ///
  /// Reference: Alfa §4.3.3 — plant-wise compliance report
  Future<String> generateComplianceReportPdf({
    required String reportTitle,
    required DateTime asOfDate,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> departmentBreakdown,
    required List<Map<String, dynamic>> overdueObligations,
    required String orgId,
    String? plantId,
    String? departmentId,
  }) async {
    final response = await _supabase.functions.invoke(
      'generate-compliance-report-pdf',
      body: {
        'report_title': reportTitle,
        'as_of_date': asOfDate.toIso8601String(),
        'metrics': metrics,
        'department_breakdown': departmentBreakdown,
        'overdue_obligations': overdueObligations,
        'org_id': orgId,
        'plant_id': plantId,
        'department_id': departmentId,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    if (response.status != 200) {
      throw PdfGenerationException(
        'Failed to generate compliance report PDF: ${response.data}',
      );
    }

    final data = response.data as Map<String, dynamic>;
    return data['storage_path'] as String;
  }
}

/// Exception thrown when PDF generation fails.
class PdfGenerationException implements Exception {
  final String message;

  PdfGenerationException(this.message);

  @override
  String toString() => 'PdfGenerationException: $message';
}
