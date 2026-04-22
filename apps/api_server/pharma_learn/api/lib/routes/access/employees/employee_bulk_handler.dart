import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/access/employees/bulk
///
/// Bulk import employees from CSV or JSON.
/// Alfa §4.3.6 — CSV/JSON batch import
///
/// Body (JSON array):
/// ```json
/// {
///   "employees": [
///     {
///       "employee_number": "EMP001",
///       "first_name": "John",
///       "last_name": "Doe",
///       "email": "john.doe@org.com",
///       "department_id": "uuid",
///       "job_role_id": "uuid",
///       "manager_id": "uuid",
///       "plant_id": "uuid"
///     }
///   ],
///   "skip_duplicates": true,
///   "send_notifications": false
/// }
/// ```
Future<Response> employeeBulkHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Permission check
  await PermissionChecker(supabase).require(
    auth.employeeId,
    Permissions.manageEmployees,
    jwtPermissions: auth.permissions,
  );

  final employees = body['employees'] as List?;
  final skipDuplicates = body['skip_duplicates'] as bool? ?? true;
  final sendNotifications = body['send_notifications'] as bool? ?? false;

  if (employees == null || employees.isEmpty) {
    throw ValidationException({'employees': 'At least one employee is required'});
  }

  if (employees.length > 500) {
    throw ValidationException({'employees': 'Maximum 500 employees per batch'});
  }

  final results = <Map<String, dynamic>>[];
  final errors = <Map<String, dynamic>>[];
  int created = 0;
  int skipped = 0;

  for (int i = 0; i < employees.length; i++) {
    final emp = employees[i] as Map<String, dynamic>;
    final rowNum = i + 1;

    try {
      // Validate required fields
      final employeeNumber = emp['employee_number'] as String?;
      final firstName = emp['first_name'] as String?;
      final lastName = emp['last_name'] as String?;

      if (employeeNumber == null || employeeNumber.isEmpty) {
        throw ValidationException({'employee_number': 'Required'});
      }
      if (firstName == null || firstName.isEmpty) {
        throw ValidationException({'first_name': 'Required'});
      }
      if (lastName == null || lastName.isEmpty) {
        throw ValidationException({'last_name': 'Required'});
      }

      // Check for duplicate employee number
      final existing = await supabase
          .from('employees')
          .select('id')
          .eq('employee_number', employeeNumber)
          .eq('org_id', auth.orgId)
          .maybeSingle();

      if (existing != null) {
        if (skipDuplicates) {
          skipped++;
          results.add({
            'row': rowNum,
            'employee_number': employeeNumber,
            'status': 'skipped',
            'reason': 'Duplicate employee number',
          });
          continue;
        } else {
          throw ConflictException('Employee number already exists');
        }
      }

      // Create employee
      final newEmployee = await supabase.from('employees').insert({
        'employee_number': employeeNumber,
        'first_name': firstName,
        'last_name': lastName,
        'email': emp['email'],
        'department_id': emp['department_id'],
        'job_role_id': emp['job_role_id'],
        'manager_id': emp['manager_id'],
        'plant_id': emp['plant_id'] ?? auth.plantId,
        'org_id': auth.orgId,
        'status': 'active',
        'induction_completed': false,
        'created_by': auth.employeeId,
      }).select('id, employee_number').single();

      created++;
      results.add({
        'row': rowNum,
        'employee_number': employeeNumber,
        'employee_id': newEmployee['id'],
        'status': 'created',
      });

      // Send notification if requested
      if (sendNotifications && emp['email'] != null) {
        try {
          await supabase.functions.invoke('send-notification', body: {
            'template': 'employee_created',
            'recipient_email': emp['email'],
            'data': {
              'name': '$firstName $lastName',
              'employee_number': employeeNumber,
            },
          });
        } catch (_) {
          // Don't fail import if notification fails
        }
      }
    } catch (e) {
      errors.add({
        'row': rowNum,
        'employee_number': emp['employee_number'],
        'error': e.toString(),
      });
    }
  }

  return ApiResponse.ok({
    'summary': {
      'total': employees.length,
      'created': created,
      'skipped': skipped,
      'failed': errors.length,
    },
    'results': results,
    'errors': errors,
  }).toResponse();
}
