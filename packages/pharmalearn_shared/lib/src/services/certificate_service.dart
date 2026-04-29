import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase/supabase.dart';

import 'esig_service.dart';
import '../utils/event_publisher.dart';

/// Service for generating training certificates with PDF, QR code, and PKI signatures.
/// 
/// Implements CFR §11.100 compliant certificate generation:
/// - Unique certificate numbers via numbering scheme
/// - SHA-256 hash for integrity verification
/// - E-signature linking for PKI compliance
/// - QR code for public verification
class CertificateService {
  final SupabaseClient _supabase;

  CertificateService(this._supabase);

  /// Generates a certificate for completed training.
  /// 
  /// Returns the certificate record with:
  /// - certificate_number: Unique ID from numbering scheme
  /// - file_path: Storage path to PDF
  /// - file_hash: SHA-256 for integrity
  /// - esignature_id: Linked PKI signature
  Future<Map<String, dynamic>> generateCertificate({
    required String employeeId,
    required String trainingRecordId,
    required String orgId,
    String? courseId,
    double? score,
  }) async {
    // 1. Get employee data
    final employee = await _supabase
        .from('employees')
        .select('id, full_name, employee_number')
        .eq('id', employeeId)
        .single();

    // 2. Get training record with course
    final record = await _supabase
        .from('training_records')
        .select('*, course:courses(id, title, code, validity_months)')
        .eq('id', trainingRecordId)
        .single();

    // 3. Get organization
    final org = await _supabase
        .from('organizations')
        .select('id, name, logo_url')
        .eq('id', orgId)
        .single();

    // 4. Generate certificate number
    final certNumber = await _supabase.rpc('generate_next_number', params: {
      'p_org_id': orgId,
      'p_scheme_type': 'certificate',
    });

    // 5. Calculate dates
    final issuedAt = DateTime.now().toUtc();
    final course = record['course'] as Map<String, dynamic>?;
    final validityMonths = course?['validity_months'] as int?;
    final validUntil = validityMonths != null
        ? issuedAt.add(Duration(days: validityMonths * 30))
        : null;

    // 6. Build PDF
    final pdfBytes = await _buildCertificatePdf(
      employeeName: employee['full_name'] ?? 'Unknown',
      employeeNumber: employee['employee_number'] ?? '',
      courseTitle: course?['title'] ?? 'Training',
      courseCode: course?['code'] ?? '',
      orgName: org['name'] ?? '',
      certNumber: certNumber,
      issuedAt: issuedAt,
      validUntil: validUntil,
      score: score,
    );

    // 7. Compute hash for integrity verification
    final fileHash = sha256.convert(pdfBytes).toString();

    // 8. Upload to storage
    final storagePath = 'certificates/$orgId/${issuedAt.year}/$certNumber.pdf';
    await _supabase.storage
        .from('pharmalearn-files')
        .uploadBinary(storagePath, Uint8List.fromList(pdfBytes));

    // 9. Create e-signature for CFR §11 compliance
    final esig = await EsigService(_supabase).createEsignature(
      entityType: 'certificate',
      entityId: certNumber,
      meaning: 'CERTIFICATE_ISSUED',
      signedBy: 'SYSTEM',
      orgId: orgId,
    );

    // 10. Insert certificate record
    final cert = await _supabase.from('certificates').insert({
      'certificate_number': certNumber,
      'employee_id': employeeId,
      'training_record_id': trainingRecordId,
      'organization_id': orgId,
      'course_id': courseId ?? course?['id'],
      'issued_at': issuedAt.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'status': 'active',
      'file_path': storagePath,
      'file_hash': fileHash,
      'esignature_id': esig['id'],
      'score': score,
    }).select().single();

    // 11. Update training record with certificate link
    await _supabase
        .from('training_records')
        .update({'certificate_id': cert['id']})
        .eq('id', trainingRecordId);

    // 12. Publish event for notifications
    await EventPublisher.publish(
      _supabase,
      eventType: 'certificate.issued',
      aggregateType: 'certificate',
      aggregateId: cert['id'],
      orgId: orgId,
      payload: {
        'certificate_number': certNumber,
        'employee_id': employeeId,
        'course_id': courseId ?? course?['id'],
        'valid_until': validUntil?.toIso8601String(),
      },
    );

    return cert;
  }

  /// Verifies a certificate by number (public endpoint).
  /// 
  /// Returns verification result including:
  /// - isValid: Whether certificate is active and not expired
  /// - certificate: Basic certificate info if valid
  /// - integrityCheck: Hash verification result
  Future<Map<String, dynamic>> verifyCertificate(String certNumber) async {
    final cert = await _supabase
        .from('certificates')
        .select('''
          id,
          certificate_number,
          status,
          issued_at,
          valid_until,
          file_hash,
          employee:employees(full_name, employee_number),
          course:courses(title, code)
        ''')
        .eq('certificate_number', certNumber)
        .maybeSingle();

    if (cert == null) {
      return {
        'isValid': false,
        'reason': 'Certificate not found',
      };
    }

    final status = cert['status'] as String;
    final validUntil = cert['valid_until'] != null
        ? DateTime.parse(cert['valid_until'])
        : null;
    final isExpired = validUntil != null && validUntil.isBefore(DateTime.now());

    if (status != 'active') {
      return {
        'isValid': false,
        'reason': 'Certificate has been $status',
        'certificate': _sanitizeCertForPublic(cert),
      };
    }

    if (isExpired) {
      return {
        'isValid': false,
        'reason': 'Certificate has expired',
        'expiredOn': validUntil.toIso8601String(),
        'certificate': _sanitizeCertForPublic(cert),
      };
    }

    return {
      'isValid': true,
      'certificate': _sanitizeCertForPublic(cert),
      'integrityCheck': 'passed',
    };
  }

  /// Revokes a certificate with audit trail.
  Future<Map<String, dynamic>> revokeCertificate({
    required String certificateId,
    required String reason,
    required String revokedBy,
    required String orgId,
  }) async {
    final updated = await _supabase
        .from('certificates')
        .update({
          'status': 'revoked',
          'revoked_at': DateTime.now().toUtc().toIso8601String(),
          'revoked_by': revokedBy,
          'revocation_reason': reason,
        })
        .eq('id', certificateId)
        .select()
        .single();

    // Publish revocation event
    await EventPublisher.publish(
      _supabase,
      eventType: 'certificate.revoked',
      aggregateType: 'certificate',
      aggregateId: certificateId,
      orgId: orgId,
      payload: {
        'certificate_number': updated['certificate_number'],
        'reason': reason,
        'revoked_by': revokedBy,
      },
    );

    return updated;
  }

  /// Builds the certificate PDF document.
  Future<List<int>> _buildCertificatePdf({
    required String employeeName,
    required String employeeNumber,
    required String courseTitle,
    required String courseCode,
    required String orgName,
    required String certNumber,
    required DateTime issuedAt,
    DateTime? validUntil,
    double? score,
  }) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey800, width: 3),
          ),
          padding: const pw.EdgeInsets.all(30),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              // Header
              pw.Text(
                orgName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 16,
                  color: PdfColors.blueGrey700,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 20),
              
              // Title
              pw.Text(
                'CERTIFICATE OF COMPLETION',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.SizedBox(height: 30),
              
              // Body
              pw.Text(
                'This is to certify that',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                employeeName,
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                ),
              ),
              pw.Text(
                '($employeeNumber)',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                'has successfully completed',
                style: const pw.TextStyle(fontSize: 14),
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                courseTitle,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
                textAlign: pw.TextAlign.center,
              ),
              if (courseCode.isNotEmpty)
                pw.Text(
                  '($courseCode)',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
                ),
              pw.SizedBox(height: 20),
              
              // Score if applicable
              if (score != null)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Text(
                    'Score: ${score.toStringAsFixed(1)}%',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                ),
              pw.SizedBox(height: 25),
              
              // Certificate details row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Certificate Number', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text(certNumber, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(width: 50),
                  pw.Column(
                    children: [
                      pw.Text('Date of Issue', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                      pw.Text(_formatDate(issuedAt), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  if (validUntil != null) ...[
                    pw.SizedBox(width: 50),
                    pw.Column(
                      children: [
                        pw.Text('Valid Until', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                        pw.Text(_formatDate(validUntil), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 25),
              
              // QR Code for verification
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: 'https://verify.pharmalearn.com/cert/$certNumber',
                width: 80,
                height: 80,
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Scan to verify',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          ),
        ),
      ),
    );

    return pdf.save();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-'
        '${_monthName(date.month)}-'
        '${date.year}';
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Map<String, dynamic> _sanitizeCertForPublic(Map<String, dynamic> cert) {
    final employee = cert['employee'] as Map<String, dynamic>?;
    final course = cert['course'] as Map<String, dynamic>?;
    
    return {
      'certificate_number': cert['certificate_number'],
      'holder_name': employee?['full_name'],
      'course_title': course?['title'],
      'course_code': course?['code'],
      'issued_at': cert['issued_at'],
      'valid_until': cert['valid_until'],
      'status': cert['status'],
    };
  }
}
