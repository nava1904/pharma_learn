import 'package:crypto/crypto.dart';
import 'package:supabase/supabase.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'pdf_service.dart';

/// Service for generating and managing training certificates.
/// 
/// Implements CFR §11.100 compliant certificate generation:
/// - Unique certificate numbers via numbering scheme
/// - PDF generation via Edge Function
/// - SHA-256 hash for integrity verification
/// - E-signature linking for PKI compliance
/// - QR code for public verification
class CertificateService {
  final SupabaseClient _supabase;
  final PdfService _pdfService;

  CertificateService(this._supabase) : _pdfService = PdfService(_supabase);

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
    String? issuedById,
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
        .select('id, name')
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

    // 6. Create initial certificate record (for ID)
    final certId = await _supabase.from('certificates').insert({
      'certificate_number': certNumber,
      'employee_id': employeeId,
      'training_record_id': trainingRecordId,
      'organization_id': orgId,
      'course_id': courseId ?? course?['id'],
      'issued_at': issuedAt.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'status': 'generating',
      'score': score,
    }).select('id').single();

    final certificateId = certId['id'] as String;

    // 7. Generate PDF via Edge Function
    final storagePath = await _pdfService.generateCertificatePdf(
      certificateId: certificateId,
      certificateNumber: certNumber,
      employeeName: employee['full_name'] ?? 'Unknown',
      courseName: course?['title'] ?? 'Training',
      courseCode: course?['code'] ?? '',
      issuedAt: issuedAt,
      validUntil: validUntil,
      organizationName: org['name'] ?? '',
      orgId: orgId,
    );

    // 8. Calculate hash from storage file for integrity
    final fileBytes = await _supabase.storage
        .from('pharmalearn-files')
        .download(storagePath);
    final fileHash = sha256.convert(fileBytes).toString();

    // 9. Create e-signature for CFR §11 compliance
    final esigService = EsigService(_supabase);
    final esigId = await esigService.createEsignature(
      employeeId: issuedById ?? 'SYSTEM',
      meaning: 'CERTIFICATE_ISSUED',
      entityType: 'certificate',
      entityId: certificateId,
      reason: 'Certificate issued for training completion',
      dataSnapshot: {
        'certificate_number': certNumber,
        'employee_id': employeeId,
        'course_id': courseId ?? course?['id'],
        'score': score,
      },
    );

    // 10. Update certificate with file info and activate
    final cert = await _supabase
        .from('certificates')
        .update({
          'status': 'active',
          'file_path': storagePath,
          'file_hash': fileHash,
          'esignature_id': esigId,
        })
        .eq('id', certificateId)
        .select()
        .single();

    // 11. Update training record with certificate link
    await _supabase
        .from('training_records')
        .update({'certificate_id': certificateId})
        .eq('id', trainingRecordId);

    // 12. Publish event for notifications
    final outbox = OutboxService(_supabase);
    await outbox.publish(
      eventType: 'certificate.issued',
      aggregateType: 'certificate',
      aggregateId: certificateId,
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
          file_path,
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

    // Verify file integrity if hash exists
    String integrityStatus = 'not_checked';
    if (cert['file_path'] != null && cert['file_hash'] != null) {
      try {
        final fileBytes = await _supabase.storage
            .from('pharmalearn-files')
            .download(cert['file_path']);
        final currentHash = sha256.convert(fileBytes).toString();
        integrityStatus = currentHash == cert['file_hash'] ? 'passed' : 'failed';
      } catch (_) {
        integrityStatus = 'error';
      }
    }

    return {
      'isValid': true,
      'certificate': _sanitizeCertForPublic(cert),
      'integrityCheck': integrityStatus,
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

    // Create e-signature for revocation
    final esigService = EsigService(_supabase);
    await esigService.createEsignature(
      employeeId: revokedBy,
      meaning: 'CERTIFICATE_REVOKED',
      entityType: 'certificate',
      entityId: certificateId,
      reason: reason,
    );

    // Publish revocation event
    final outbox = OutboxService(_supabase);
    await outbox.publish(
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

  /// Gets a signed download URL for the certificate PDF.
  Future<String> getDownloadUrl(String certificateId) async {
    final cert = await _supabase
        .from('certificates')
        .select('file_path')
        .eq('id', certificateId)
        .single();

    final filePath = cert['file_path'] as String?;
    if (filePath == null) {
      throw Exception('Certificate PDF not found');
    }

    final signedUrl = await _supabase.storage
        .from('pharmalearn-files')
        .createSignedUrl(filePath, 3600); // 1 hour expiry

    return signedUrl;
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
