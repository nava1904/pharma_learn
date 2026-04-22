import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:logger/logger.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pharmalearn_shared/pharmalearn_shared.dart';
import 'package:supabase/supabase.dart';

/// Service to generate PDF/CSV reports from templates.
/// This service polls for queued reports and processes them.
class ReportGeneratorService {
  final SupabaseClient _supabase;
  final Logger _logger = Logger();
  
  // Storage bucket name
  static const String _bucket = 'pharmalearn-files';
  
  ReportGeneratorService(this._supabase);

  /// Polls for queued reports and processes them
  Future<void> processQueuedReports() async {
    try {
      // Get next queued report (ordered by priority, then requested time)
      final queued = await _supabase
          .from('compliance_reports')
          .select()
          .eq('status', 'queued')
          .order('priority')
          .order('generated_at')
          .limit(1)
          .maybeSingle();

      if (queued == null) {
        return; // No pending reports
      }

      final reportId = queued['id'] as String;
      final templateId = queued['template_id'] as String?;
      final parameters = queued['parameters'] as Map<String, dynamic>? ?? {};
      final orgId = queued['organization_id'] as String;

      _logger.i('Processing report: $reportId (template: $templateId)');

      // Mark as processing
      await _supabase
          .from('compliance_reports')
          .update({
            'status': 'processing',
            'progress_percent': 5,
          })
          .eq('id', reportId);

      try {
        // Generate report based on template
        final template = templateId != null
            ? ReportTemplate.byId(templateId)
            : null;

        if (template == null) {
          throw Exception('Unknown template: $templateId');
        }

        // Update progress
        await _updateProgress(reportId, 10);

        // Fetch report data
        final reportData = await _fetchReportData(
          templateId: templateId!,
          parameters: parameters,
          orgId: orgId,
        );

        await _updateProgress(reportId, 40);

        // Get organization details for letterhead
        final org = await _supabase
            .from('organizations')
            .select('name, short_code, address, phone, email')
            .eq('id', orgId)
            .single();

        await _updateProgress(reportId, 50);

        // Generate PDF
        final pdfBytes = await _generatePdf(
          template: template,
          data: reportData,
          organization: org,
          reportNumber: queued['report_number'] as String?,
          generatedAt: DateTime.parse(queued['generated_at'] as String),
        );

        await _updateProgress(reportId, 70);

        // Generate CSV if supported
        Uint8List? csvBytes;
        if (template.supportsCsv) {
          csvBytes = _generateCsv(template: template, data: reportData);
        }

        await _updateProgress(reportId, 80);

        // Upload to storage
        final year = DateTime.now().year;
        final reportNumber = queued['report_number'] as String? ?? reportId;
        final basePath = 'reports/$orgId/$year/$reportNumber';
        
        final pdfPath = '$basePath.pdf';
        await _supabase.storage.from(_bucket).uploadBinary(
          pdfPath,
          pdfBytes,
          fileOptions: const FileOptions(contentType: 'application/pdf'),
        );

        String? csvPath;
        if (csvBytes != null) {
          csvPath = '$basePath.csv';
          await _supabase.storage.from(_bucket).uploadBinary(
            csvPath,
            csvBytes,
            fileOptions: const FileOptions(contentType: 'text/csv'),
          );
        }

        await _updateProgress(reportId, 95);

        // Mark as complete
        await _supabase
            .from('compliance_reports')
            .update({
              'status': 'ready',
              'progress_percent': 100,
              'completed_at': DateTime.now().toUtc().toIso8601String(),
              'storage_path': pdfPath,
              'storage_path_csv': csvPath,
              'file_size_bytes': pdfBytes.length,
              'report_data': reportData,
            })
            .eq('id', reportId);

        _logger.i('Report $reportId completed successfully');
      } catch (e, stack) {
        _logger.e('Report $reportId failed: $e\n$stack');
        
        await _supabase
            .from('compliance_reports')
            .update({
              'status': 'failed',
              'error_message': e.toString(),
              'completed_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', reportId);
      }
    } catch (e, stack) {
      _logger.e('ReportGeneratorService error: $e\n$stack');
    }
  }

  Future<void> _updateProgress(String reportId, int percent) async {
    await _supabase
        .from('compliance_reports')
        .update({'progress_percent': percent})
        .eq('id', reportId);
  }

  /// Fetches data for a specific report template
  Future<Map<String, dynamic>> _fetchReportData({
    required String templateId,
    required Map<String, dynamic> parameters,
    required String orgId,
  }) async {
    switch (templateId) {
      case 'employee_training_dossier':
        return _fetchEmployeeTrainingDossier(parameters, orgId);
      case 'department_compliance_summary':
        return _fetchDepartmentComplianceSummary(parameters, orgId);
      case 'overdue_training_report':
        return _fetchOverdueTrainingReport(parameters, orgId);
      case 'certificate_expiry_report':
        return _fetchCertificateExpiryReport(parameters, orgId);
      case 'sop_acknowledgment_report':
        return _fetchSopAcknowledgmentReport(parameters, orgId);
      case 'assessment_performance_report':
        return _fetchAssessmentPerformanceReport(parameters, orgId);
      case 'esignature_audit_report':
        return _fetchEsignatureAuditReport(parameters, orgId);
      case 'system_access_log_report':
        return _fetchSystemAccessLogReport(parameters, orgId);
      case 'integrity_verification_report':
        return _fetchIntegrityVerificationReport(parameters, orgId);
      case 'audit_readiness_report':
        return _fetchAuditReadinessReport(parameters, orgId);
      default:
        throw Exception('Unknown template: $templateId');
    }
  }

  // ===== Data Fetchers =====

  Future<Map<String, dynamic>> _fetchEmployeeTrainingDossier(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    final employeeId = params['employee_id'] as String;
    final asOf = params['as_of'] as String? ??
        DateTime.now().toIso8601String().split('T')[0];

    // Fetch employee
    final employee = await _supabase
        .from('employees')
        .select('''
          id, employee_number, first_name, last_name, email,
          job_title, hire_date,
          departments ( id, name, code )
        ''')
        .eq('id', employeeId)
        .single();

    // Fetch training records
    final trainingRecords = await _supabase
        .from('training_records')
        .select('''
          id, status, completed_at, score, training_type,
          courses ( id, title, version ),
          certificates ( id, certificate_number, valid_until, status )
        ''')
        .eq('employee_id', employeeId)
        .lte('created_at', asOf);

    // Fetch competencies
    final competencies = await _supabase
        .from('competencies')
        .select('id, level, verified_at, competency_matrices(name)')
        .eq('employee_id', employeeId);

    // Fetch e-signatures
    final signatures = await _supabase
        .from('esignatures')
        .select('id, signed_at, purpose, hash_value')
        .eq('signer_id', employeeId)
        .order('signed_at', ascending: false)
        .limit(100);

    return {
      'as_of': asOf,
      'employee': employee,
      'training_records': trainingRecords,
      'competencies': competencies,
      'signatures': signatures,
      'summary': {
        'total_trainings': (trainingRecords as List).length,
        'completed_trainings': (trainingRecords)
            .where((r) => r['status'] == 'COMPLETED')
            .length,
        'active_certificates': (trainingRecords)
            .where((r) =>
                r['certificates'] != null &&
                r['certificates']['status'] == 'ACTIVE')
            .length,
      },
    };
  }

  Future<Map<String, dynamic>> _fetchDepartmentComplianceSummary(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    final departmentId = params['department_id'] as String?;
    final dateFrom = params['date_from'] as String?;
    final dateTo = params['date_to'] as String? ??
        DateTime.now().toIso8601String().split('T')[0];

    var query = _supabase
        .from('employees')
        .select('''
          id, employee_number, first_name, last_name, job_title,
          training_records(status, completed_at),
          certificates(status, valid_until)
        ''')
        .eq('organization_id', orgId)
        .eq('is_active', true);

    if (departmentId != null) {
      query = query.eq('department_id', departmentId);
    }

    final employees = await query;

    // Calculate metrics per employee
    final employeeMetrics = (employees as List).map((emp) {
      final trainings = emp['training_records'] as List? ?? [];
      final certs = emp['certificates'] as List? ?? [];
      
      return {
        'employee_id': emp['id'],
        'employee_number': emp['employee_number'],
        'name': '${emp['first_name']} ${emp['last_name']}',
        'total_trainings': trainings.length,
        'completed_trainings': trainings.where((t) => t['status'] == 'COMPLETED').length,
        'active_certificates': certs.where((c) => c['status'] == 'ACTIVE').length,
        'expiring_soon': certs.where((c) {
          if (c['valid_until'] == null) return false;
          final validUntil = DateTime.parse(c['valid_until'] as String);
          return validUntil.difference(DateTime.now()).inDays <= 30;
        }).length,
      };
    }).toList();

    return {
      'period': {'from': dateFrom, 'to': dateTo},
      'department_id': departmentId,
      'employees': employeeMetrics,
      'summary': {
        'total_employees': employeeMetrics.length,
        'fully_compliant': employeeMetrics
            .where((e) => (e['completed_trainings'] as int) == (e['total_trainings'] as int))
            .length,
      },
    };
  }

  Future<Map<String, dynamic>> _fetchOverdueTrainingReport(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    final departmentId = params['department_id'] as String?;

    var query = _supabase
        .from('training_records')
        .select('''
          id, due_date, created_at,
          employees ( id, employee_number, first_name, last_name, department_id,
            departments ( id, name )
          ),
          courses ( id, title, version )
        ''')
        .eq('status', 'OVERDUE')
        .eq('employees.organization_id', orgId);

    if (departmentId != null) {
      query = query.eq('employees.department_id', departmentId);
    }

    final overdueRecords = await query.order('due_date');

    return {
      'as_of': DateTime.now().toIso8601String(),
      'records': overdueRecords,
      'summary': {
        'total_overdue': (overdueRecords as List).length,
      },
    };
  }

  Future<Map<String, dynamic>> _fetchCertificateExpiryReport(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    final daysAhead = params['days_ahead'] as int? ?? 90;

    final cutoff = DateTime.now()
        .add(Duration(days: daysAhead))
        .toIso8601String()
        .split('T')[0];

    final expiring = await _supabase
        .from('certificates')
        .select('''
          id, certificate_number, valid_until, status,
          employees ( id, employee_number, first_name, last_name,
            departments ( id, name )
          ),
          training_records ( courses ( id, title ) )
        ''')
        .eq('status', 'ACTIVE')
        .lte('valid_until', cutoff)
        .gte('valid_until', DateTime.now().toIso8601String().split('T')[0])
        .order('valid_until');

    return {
      'as_of': DateTime.now().toIso8601String(),
      'days_ahead': daysAhead,
      'certificates': expiring,
      'summary': {
        'total_expiring': (expiring as List).length,
      },
    };
  }

  Future<Map<String, dynamic>> _fetchSopAcknowledgmentReport(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    final documentId = params['document_id'] as String?;
    final departmentId = params['department_id'] as String?;

    var query = _supabase
        .from('document_acknowledgments')
        .select('''
          id, acknowledged_at, status,
          employees ( id, employee_number, first_name, last_name, department_id ),
          documents ( id, document_number, title, version )
        ''')
        .eq('documents.organization_id', orgId);

    if (documentId != null) {
      query = query.eq('document_id', documentId);
    }
    if (departmentId != null) {
      query = query.eq('employees.department_id', departmentId);
    }

    final acks = await query.order('acknowledged_at', ascending: false);

    return {
      'as_of': DateTime.now().toIso8601String(),
      'acknowledgments': acks,
      'summary': {
        'total': (acks as List).length,
      },
    };
  }

  Future<Map<String, dynamic>> _fetchAssessmentPerformanceReport(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    final courseId = params['course_id'] as String?;
    final dateFrom = params['date_from'] as String?;
    final dateTo = params['date_to'] as String?;

    var query = _supabase
        .from('assessment_submissions')
        .select('''
          id, score, submitted_at, attempt_number, is_passed,
          assessments ( id, title, passing_score,
            courses ( id, title )
          ),
          employees ( id, employee_number, first_name, last_name )
        ''')
        .eq('assessments.courses.organization_id', orgId);

    if (courseId != null) {
      query = query.eq('assessments.course_id', courseId);
    }
    if (dateFrom != null) {
      query = query.gte('submitted_at', dateFrom);
    }
    if (dateTo != null) {
      query = query.lte('submitted_at', dateTo);
    }

    final submissions = await query.order('submitted_at', ascending: false);

    // Calculate psychometrics
    final scores = (submissions as List)
        .map((s) => (s['score'] as num?)?.toDouble() ?? 0.0)
        .toList();
    
    final avgScore = scores.isEmpty
        ? 0.0
        : scores.reduce((a, b) => a + b) / scores.length;
    final passRate = scores.isEmpty
        ? 0.0
        : (submissions)
                .where((s) => s['is_passed'] == true)
                .length /
            submissions.length *
            100;

    return {
      'period': {'from': dateFrom, 'to': dateTo},
      'submissions': submissions,
      'summary': {
        'total_submissions': submissions.length,
        'average_score': avgScore.toStringAsFixed(1),
        'pass_rate': passRate.toStringAsFixed(1),
      },
    };
  }

  Future<Map<String, dynamic>> _fetchEsignatureAuditReport(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    final dateFrom = params['date_from'] as String?;
    final dateTo = params['date_to'] as String?;

    var query = _supabase
        .from('esignatures')
        .select('''
          id, signed_at, purpose, meaning, hash_value, ip_address,
          signers:signer_id ( id, employee_number, first_name, last_name )
        ''')
        .eq('organization_id', orgId);

    if (dateFrom != null) {
      query = query.gte('signed_at', dateFrom);
    }
    if (dateTo != null) {
      query = query.lte('signed_at', dateTo);
    }

    final signatures = await query.order('signed_at', ascending: false);

    return {
      'period': {'from': dateFrom, 'to': dateTo},
      'signatures': signatures,
      'summary': {
        'total_signatures': (signatures as List).length,
      },
    };
  }

  Future<Map<String, dynamic>> _fetchSystemAccessLogReport(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    final dateFrom = params['date_from'] as String?;
    final dateTo = params['date_to'] as String?;
    final eventCategory = params['event_category'] as String?;

    var query = _supabase
        .from('audit_trails')
        .select('''
          id, action, entity_type, event_category, occurred_at,
          ip_address, user_agent,
          employees ( id, employee_number, first_name, last_name )
        ''')
        .eq('organization_id', orgId);

    if (dateFrom != null) {
      query = query.gte('occurred_at', dateFrom);
    }
    if (dateTo != null) {
      query = query.lte('occurred_at', dateTo);
    }
    if (eventCategory != null) {
      query = query.eq('event_category', eventCategory);
    }

    final logs = await query.order('occurred_at', ascending: false).limit(1000);

    return {
      'period': {'from': dateFrom, 'to': dateTo},
      'logs': logs,
      'summary': {
        'total_events': (logs as List).length,
      },
    };
  }

  Future<Map<String, dynamic>> _fetchIntegrityVerificationReport(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    // Run integrity verification
    final verificationResult = await _supabase.rpc(
      'verify_audit_hash_chain',
      params: {'p_organization_id': orgId},
    );

    // Get recent integrity checks
    final recentChecks = await _supabase
        .from('audit_trails')
        .select()
        .eq('organization_id', orgId)
        .eq('event_category', 'SYSTEM')
        .eq('action', 'INTEGRITY_CHECK')
        .order('occurred_at', ascending: false)
        .limit(10);

    return {
      'verified_at': DateTime.now().toIso8601String(),
      'result': verificationResult,
      'recent_checks': recentChecks,
      'summary': {
        'is_valid': verificationResult['is_valid'] ?? false,
        'records_checked': verificationResult['records_checked'] ?? 0,
      },
    };
  }

  Future<Map<String, dynamic>> _fetchAuditReadinessReport(
    Map<String, dynamic> params,
    String orgId,
  ) async {
    // Compliance metrics
    final complianceMetrics = await _supabase
        .from('compliance_metrics')
        .select()
        .eq('organization_id', orgId)
        .order('calculated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    // Training coverage
    final trainingCoverage = await _supabase.rpc(
      'get_training_coverage',
      params: {'p_organization_id': orgId},
    );

    // Document status
    final documentStatus = await _supabase
        .from('documents')
        .select('status')
        .eq('organization_id', orgId);

    // Certificate status
    final certificateStatus = await _supabase
        .from('certificates')
        .select('status, valid_until')
        .eq('organization_id', orgId);

    // Calculate metrics
    final docs = documentStatus as List;
    final certs = certificateStatus as List;
    
    final activeDocs = docs.where((d) => d['status'] == 'EFFECTIVE').length;
    final activeCerts = certs.where((c) => c['status'] == 'ACTIVE').length;
    final expiringCerts = certs.where((c) {
      if (c['valid_until'] == null || c['status'] != 'ACTIVE') return false;
      final validUntil = DateTime.parse(c['valid_until'] as String);
      return validUntil.difference(DateTime.now()).inDays <= 30;
    }).length;

    return {
      'generated_at': DateTime.now().toIso8601String(),
      'compliance_metrics': complianceMetrics,
      'training_coverage': trainingCoverage,
      'documents': {
        'total': docs.length,
        'effective': activeDocs,
      },
      'certificates': {
        'total': certs.length,
        'active': activeCerts,
        'expiring_30_days': expiringCerts,
      },
      'summary': {
        'overall_compliance_score':
            complianceMetrics?['overall_score']?.toString() ?? 'N/A',
      },
    };
  }

  // ===== PDF Generation =====

  Future<Uint8List> _generatePdf({
    required ReportTemplate template,
    required Map<String, dynamic> data,
    required Map<String, dynamic> organization,
    required String? reportNumber,
    required DateTime generatedAt,
  }) async {
    final pdf = pw.Document();

    // Build letterhead
    final letterhead = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          organization['name'] as String? ?? 'Organization',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        if (organization['address'] != null)
          pw.Text(organization['address'] as String, style: const pw.TextStyle(fontSize: 10)),
        if (organization['phone'] != null || organization['email'] != null)
          pw.Text(
            '${organization['phone'] ?? ''} | ${organization['email'] ?? ''}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        pw.SizedBox(height: 20),
        pw.Divider(),
        pw.SizedBox(height: 10),
      ],
    );

    // Build header
    final header = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              template.name,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (reportNumber != null)
              pw.Text('Report #: $reportNumber', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'Generated: ${generatedAt.toIso8601String().split('T')[0]}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 20),
      ],
    );

    // Build content based on template
    final content = _buildPdfContent(template.id, data);

    // Build footer
    final footer = pw.Column(
      children: [
        pw.Divider(),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'CONFIDENTIAL',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red,
              ),
            ),
            pw.Text(
              '21 CFR Part 11 Compliant',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],
        ),
      ],
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (_) => letterhead,
        footer: (_) => footer,
        build: (context) => [
          header,
          ...content,
        ],
      ),
    );

    return pdf.save();
  }

  List<pw.Widget> _buildPdfContent(String templateId, Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];

    // Add summary section if present
    if (data['summary'] != null) {
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Summary', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            ...((data['summary'] as Map<String, dynamic>).entries.map((e) =>
                pw.Text('${_formatKey(e.key)}: ${e.value}'))),
          ],
        ),
      ));
      widgets.add(pw.SizedBox(height: 20));
    }

    // Add data tables based on template
    switch (templateId) {
      case 'employee_training_dossier':
        widgets.addAll(_buildEmployeeDossierContent(data));
        break;
      case 'department_compliance_summary':
      case 'overdue_training_report':
      case 'certificate_expiry_report':
      case 'assessment_performance_report':
        widgets.addAll(_buildGenericTableContent(data));
        break;
      default:
        widgets.add(pw.Text('Report data available in JSON format.'));
    }

    return widgets;
  }

  List<pw.Widget> _buildEmployeeDossierContent(Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];
    final employee = data['employee'] as Map<String, dynamic>?;
    
    if (employee != null) {
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${employee['first_name']} ${employee['last_name']}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Employee #: ${employee['employee_number']}'),
            pw.Text('Title: ${employee['job_title'] ?? 'N/A'}'),
            pw.Text('Hire Date: ${employee['hire_date'] ?? 'N/A'}'),
          ],
        ),
      ));
      widgets.add(pw.SizedBox(height: 15));
    }

    // Training records table
    final trainings = data['training_records'] as List?;
    if (trainings != null && trainings.isNotEmpty) {
      widgets.add(pw.Text('Training Records', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)));
      widgets.add(pw.SizedBox(height: 5));
      widgets.add(pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headers: ['Course', 'Status', 'Completed', 'Score'],
        data: trainings.map((t) => [
          (t['courses'] as Map?)?['title'] ?? 'N/A',
          t['status'] ?? 'N/A',
          t['completed_at']?.toString().split('T')[0] ?? '-',
          t['score']?.toString() ?? '-',
        ]).toList(),
      ));
    }

    return widgets;
  }

  List<pw.Widget> _buildGenericTableContent(Map<String, dynamic> data) {
    final widgets = <pw.Widget>[];

    // Find the main data array
    for (final entry in data.entries) {
      if (entry.value is List && entry.key != 'summary') {
        final items = entry.value as List;
        if (items.isEmpty) continue;

        // Get headers from first item
        final firstItem = items.first as Map<String, dynamic>;
        final headers = firstItem.keys
            .where((k) => firstItem[k] is! Map && firstItem[k] is! List)
            .take(5)
            .toList();

        widgets.add(pw.Text(
          _formatKey(entry.key),
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ));
        widgets.add(pw.SizedBox(height: 5));
        widgets.add(pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: headers.map(_formatKey).toList(),
          data: items.take(50).map((item) {
            final row = item as Map<String, dynamic>;
            return headers.map((h) => row[h]?.toString() ?? '-').toList();
          }).toList(),
        ));
        widgets.add(pw.SizedBox(height: 15));
      }
    }

    return widgets;
  }

  String _formatKey(String key) {
    return key
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  // ===== CSV Generation =====

  Uint8List _generateCsv({
    required ReportTemplate template,
    required Map<String, dynamic> data,
  }) {
    final rows = <List<String>>[];

    // Find the main data array
    for (final entry in data.entries) {
      if (entry.value is List && entry.key != 'summary') {
        final items = entry.value as List;
        if (items.isEmpty) continue;

        // Get headers from first item (flatten nested objects)
        final firstItem = items.first as Map<String, dynamic>;
        final headers = <String>[];
        _flattenHeaders(firstItem, '', headers);

        // Add header row
        rows.add(headers);

        // Add data rows
        for (final item in items) {
          final row = <String>[];
          _flattenValues(item as Map<String, dynamic>, '', row, headers.length);
          rows.add(row);
        }

        break; // Only export first list
      }
    }

    if (rows.isEmpty) {
      rows.add(['No data available']);
    }

    final csvString = const ListToCsvConverter().convert(rows);
    return Uint8List.fromList(csvString.codeUnits);
  }

  void _flattenHeaders(Map<String, dynamic> obj, String prefix, List<String> headers) {
    for (final entry in obj.entries) {
      final key = prefix.isEmpty ? entry.key : '${prefix}_${entry.key}';
      if (entry.value is Map) {
        _flattenHeaders(entry.value as Map<String, dynamic>, key, headers);
      } else if (entry.value is! List) {
        headers.add(key);
      }
    }
  }

  void _flattenValues(Map<String, dynamic> obj, String prefix, List<String> values, int headerCount) {
    for (final entry in obj.entries) {
      final key = prefix.isEmpty ? entry.key : '${prefix}_${entry.key}';
      if (entry.value is Map) {
        _flattenValues(entry.value as Map<String, dynamic>, key, values, headerCount);
      } else if (entry.value is! List) {
        values.add(entry.value?.toString() ?? '');
      }
    }
    // Pad with empty strings if needed
    while (values.length < headerCount) {
      values.add('');
    }
  }
}
