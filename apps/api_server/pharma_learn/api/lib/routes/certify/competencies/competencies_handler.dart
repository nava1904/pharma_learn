import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/certify/competencies/gaps
///
/// Returns competency gaps for the organization.
/// A gap exists when an employee's job role requires competencies
/// they don't have valid certificates for.
Future<Response> competencyGapsHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final departmentId = req.url.queryParameters['department_id'];
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;

  // Verify user has permission to view compliance
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.viewCompliance,
    jwtPermissions: auth.permissions,
  );

  // Get employees with their required competencies
  var query = supabase
      .from('employees')
      .select('''
        id, first_name, last_name, employee_number,
        departments(id, name),
        job_roles!inner(
          id, name,
          job_role_competencies!inner(
            competencies!inner(id, name, description)
          )
        )
      ''')
      .eq('org_id', auth.orgId)
      .eq('status', 'active');

  if (departmentId != null) {
    query = query.eq('department_id', departmentId);
  }

  final employees = await query
      .range((page - 1) * perPage, page * perPage - 1);

  // For each employee, check which competencies they're missing
  final gaps = <Map<String, dynamic>>[];

  for (final emp in employees) {
    final requiredCompetencies = <Map<String, dynamic>>[];
    final jobRole = emp['job_roles'] as Map<String, dynamic>?;
    
    if (jobRole != null) {
      final roleCompetencies = jobRole['job_role_competencies'] as List? ?? [];
      for (final rc in roleCompetencies) {
        final competency = rc['competencies'] as Map<String, dynamic>;
        requiredCompetencies.add(competency);
      }
    }

    if (requiredCompetencies.isEmpty) continue;

    // Get employee's valid certificates
    final validCerts = await supabase
        .from('certificates')
        .select('id, course_id, courses!inner(competency_id)')
        .eq('employee_id', emp['id'])
        .eq('status', 'active')
        .or('expires_at.is.null,expires_at.gt.${DateTime.now().toIso8601String()}');

    final certifiedCompetencyIds = validCerts
        .map((c) => c['courses']['competency_id'])
        .whereType<String>()
        .toSet();

    // Find missing competencies
    final missingCompetencies = requiredCompetencies
        .where((c) => !certifiedCompetencyIds.contains(c['id']))
        .toList();

    if (missingCompetencies.isNotEmpty) {
      gaps.add({
        'employee': {
          'id': emp['id'],
          'name': '${emp['first_name']} ${emp['last_name']}',
          'employee_number': emp['employee_number'],
          'department': emp['departments']?['name'],
        },
        'job_role': jobRole?['name'],
        'required_competencies': requiredCompetencies.length,
        'certified_competencies': certifiedCompetencyIds.length,
        'missing_competencies': missingCompetencies,
        'gap_percentage': ((missingCompetencies.length / requiredCompetencies.length) * 100).round(),
      });
    }
  }

  // Sort by gap percentage (worst first)
  gaps.sort((a, b) => (b['gap_percentage'] as int).compareTo(a['gap_percentage'] as int));

  return ApiResponse.ok({
    'total_gaps': gaps.length,
    'gaps': gaps,
  }).toResponse();
}

/// GET /v1/certify/competencies/employees/:id
///
/// Returns competency status for a specific employee.
Future<Response> employeeCompetenciesHandler(Request req) async {
  final employeeId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify user has permission to view compliance or is viewing themselves
  if (employeeId != auth.employeeId) {
    await PermissionChecker(supabase).require(
      auth.employeeId,
      Permissions.viewCompliance,
      jwtPermissions: auth.permissions,
    );
  }

  // Get employee with job role competencies
  final employee = await supabase
      .from('employees')
      .select('''
        id, first_name, last_name, employee_number,
        job_roles(
          id, name,
          job_role_competencies(
            competencies(id, name, description)
          )
        )
      ''')
      .eq('id', employeeId)
      .eq('org_id', auth.orgId)
      .maybeSingle();

  if (employee == null) {
    throw NotFoundException('Employee not found');
  }

  // Get employee's certificates with competencies
  final certificates = await supabase
      .from('certificates')
      .select('''
        id, certificate_number, issued_at, expires_at, status,
        courses!inner(id, title, competency_id, competencies(id, name))
      ''')
      .eq('employee_id', employeeId)
      .order('issued_at', ascending: false);

  // Build competency status
  final jobRole = employee['job_roles'] as Map<String, dynamic>?;
  final requiredCompetencies = <String, Map<String, dynamic>>{};
  
  if (jobRole != null) {
    final roleCompetencies = jobRole['job_role_competencies'] as List? ?? [];
    for (final rc in roleCompetencies) {
      final competency = rc['competencies'] as Map<String, dynamic>;
      requiredCompetencies[competency['id'] as String] = {
        ...competency,
        'required': true,
        'status': 'missing',
        'certificate': null,
      };
    }
  }

  // Check which competencies are certified
  for (final cert in certificates) {
    final competencyId = cert['courses']['competency_id'] as String?;
    if (competencyId == null) continue;

    final isActive = cert['status'] == 'active';
    final expiresAt = cert['expires_at'] != null
        ? DateTime.parse(cert['expires_at'] as String)
        : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final expiresWithin30Days = expiresAt != null &&
        expiresAt.isAfter(DateTime.now()) &&
        expiresAt.isBefore(DateTime.now().add(const Duration(days: 30)));

    String status;
    if (!isActive || isExpired) {
      status = 'expired';
    } else if (expiresWithin30Days) {
      status = 'expiring_soon';
    } else {
      status = 'valid';
    }

    if (requiredCompetencies.containsKey(competencyId)) {
      requiredCompetencies[competencyId] = {
        ...requiredCompetencies[competencyId]!,
        'status': status,
        'certificate': {
          'id': cert['id'],
          'certificate_number': cert['certificate_number'],
          'issued_at': cert['issued_at'],
          'expires_at': cert['expires_at'],
        },
      };
    } else {
      // Additional competency (not required by job role)
      requiredCompetencies[competencyId] = {
        'id': competencyId,
        'name': cert['courses']['competencies']?['name'],
        'required': false,
        'status': status,
        'certificate': {
          'id': cert['id'],
          'certificate_number': cert['certificate_number'],
          'issued_at': cert['issued_at'],
          'expires_at': cert['expires_at'],
        },
      };
    }
  }

  return ApiResponse.ok({
    'employee': {
      'id': employee['id'],
      'name': '${employee['first_name']} ${employee['last_name']}',
      'employee_number': employee['employee_number'],
      'job_role': jobRole?['name'],
    },
    'competencies': requiredCompetencies.values.toList(),
    'summary': {
      'required': requiredCompetencies.values.where((c) => c['required'] == true).length,
      'valid': requiredCompetencies.values.where((c) => c['status'] == 'valid').length,
      'expiring_soon': requiredCompetencies.values.where((c) => c['status'] == 'expiring_soon').length,
      'expired': requiredCompetencies.values.where((c) => c['status'] == 'expired').length,
      'missing': requiredCompetencies.values.where((c) => c['status'] == 'missing').length,
    },
  }).toResponse();
}

/// GET /v1/certify/competencies/my
///
/// Returns the current employee's own competency status.
Future<Response> myCompetenciesHandler(Request req) async {
  // Delegate to employee handler with self ID
  req.rawPathParameters[#id] = RequestContext.auth.employeeId;
  return employeeCompetenciesHandler(req);
}
