import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/schedules/:id/assign
///
/// Bulk assigns employees to a schedule using Training Needs Identification (TNI).
/// Body: {
///   employee_ids?: string[],      // Specific employees
///   department_ids?: string[],    // All employees in departments
///   role_ids?: string[],          // All employees with roles
///   tni_based?: bool,             // Use TNI to auto-identify
///   notify?: bool                 // Send notifications
/// }
Future<Response> scheduleAssignHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to assign employees to schedules');
  }

  final schedule = await supabase
      .from('training_schedules')
      .select('id, status, course_id, max_participants')
      .eq('id', scheduleId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Schedule not found');
  }

  if (schedule['status'] != 'approved') {
    throw ConflictException('Only approved schedules can have employees assigned');
  }

  final employeeIds = <String>{};
  
  // Direct employee IDs
  final directIds = body['employee_ids'] as List<dynamic>?;
  if (directIds != null) {
    employeeIds.addAll(directIds.cast<String>());
  }

  // Employees from departments
  final deptIds = body['department_ids'] as List<dynamic>?;
  if (deptIds != null && deptIds.isNotEmpty) {
    final deptEmployees = await supabase
        .from('employees')
        .select('id')
        .inFilter('department_id', deptIds.cast<String>())
        .eq('is_active', true);
    employeeIds.addAll((deptEmployees as List).map((e) => e['id'] as String));
  }

  // Employees with specific roles
  final roleIds = body['role_ids'] as List<dynamic>?;
  if (roleIds != null && roleIds.isNotEmpty) {
    final roleEmployees = await supabase
        .from('employee_roles')
        .select('employee_id')
        .inFilter('role_id', roleIds.cast<String>())
        .eq('is_active', true);
    employeeIds.addAll((roleEmployees as List).map((e) => e['employee_id'] as String));
  }

  // TNI-based assignment: find employees who need this training
  final tniBased = body['tni_based'] as bool? ?? false;
  if (tniBased && schedule['course_id'] != null) {
    final courseId = schedule['course_id'] as String;
    
    // Get employees who have this course in their obligations but haven't completed it
    final tniEmployees = await supabase.rpc('get_employees_needing_course', params: {
      'p_course_id': courseId,
    });
    
    if (tniEmployees is List) {
      employeeIds.addAll(tniEmployees.map((e) => e['employee_id'] as String));
    }
  }

  if (employeeIds.isEmpty) {
    throw ValidationException({'employees': 'No employees found to assign'});
  }

  // Check capacity
  final maxParticipants = schedule['max_participants'] as int? ?? 0;
  if (maxParticipants > 0) {
    final currentCountResult = await supabase
        .from('schedule_enrollments')
        .select('id')
        .eq('schedule_id', scheduleId);
    
    final currentCount = (currentCountResult as List).length;
    final available = maxParticipants - currentCount;
    if (employeeIds.length > available) {
      throw ValidationException({
        'capacity': 'Schedule can only accept $available more participants'
      });
    }
  }

  final now = DateTime.now().toUtc().toIso8601String();

  // Create enrollments
  final enrollments = employeeIds.map((empId) {
    return {
      'schedule_id': scheduleId,
      'employee_id': empId,
      'status': 'assigned',
      'assigned_by': auth.employeeId,
      'assigned_at': now,
      'created_at': now,
    };
  }).toList();

  await supabase
      .from('schedule_enrollments')
      .upsert(enrollments, onConflict: 'schedule_id,employee_id');

  // Send notifications if requested
  final notify = body['notify'] as bool? ?? true;
  if (notify) {
    final notifications = employeeIds.map((empId) {
      return {
        'employee_id': empId,
        'type': 'training_assignment',
        'title': 'New Training Assignment',
        'message': 'You have been assigned to a training session',
        'entity_type': 'training_schedule',
        'entity_id': scheduleId,
        'created_at': now,
      };
    }).toList();

    await supabase.from('notifications').insert(notifications);
  }

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedule',
    'entity_id': scheduleId,
    'action': 'bulk_assign',
    'employee_id': auth.employeeId,
    'new_values': {
      'assigned_count': employeeIds.length,
      'employee_ids': employeeIds.toList(),
    },
    'created_at': now,
  });

  return ApiResponse.ok({
    'message': 'Employees assigned successfully',
    'assigned_count': employeeIds.length,
  }).toResponse();
}

/// POST /v1/train/schedules/:id/enroll
///
/// Self-enrollment for an employee (if schedule allows self-enrollment).
Future<Response> scheduleEnrollHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  final schedule = await supabase
      .from('training_schedules')
      .select('id, status, allow_self_enrollment, max_participants, scheduled_date')
      .eq('id', scheduleId)
      .maybeSingle();

  if (schedule == null) {
    throw NotFoundException('Schedule not found');
  }

  if (schedule['status'] != 'approved') {
    throw ConflictException('Cannot enroll in unapproved schedules');
  }

  if (schedule['allow_self_enrollment'] != true) {
    throw ConflictException('Self-enrollment is not allowed for this schedule');
  }

  // Check if already enrolled
  final existing = await supabase
      .from('schedule_enrollments')
      .select('id, status')
      .eq('schedule_id', scheduleId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (existing != null) {
    throw ConflictException('You are already enrolled in this schedule');
  }

  // Check capacity
  final maxParticipants = schedule['max_participants'] as int? ?? 0;
  if (maxParticipants > 0) {
    final currentCountResult = await supabase
        .from('schedule_enrollments')
        .select('id')
        .eq('schedule_id', scheduleId);
    
    final currentCount = (currentCountResult as List).length;
    if (currentCount >= maxParticipants) {
      throw ConflictException('Schedule is at full capacity');
    }
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase.from('schedule_enrollments').insert({
    'schedule_id': scheduleId,
    'employee_id': auth.employeeId,
    'status': 'enrolled',
    'enrolled_at': now,
    'created_at': now,
  });

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedule',
    'entity_id': scheduleId,
    'action': 'self_enroll',
    'employee_id': auth.employeeId,
    'new_values': {'enrolled_at': now},
    'created_at': now,
  });

  return ApiResponse.ok({'message': 'Successfully enrolled'}).toResponse();
}

/// DELETE /v1/train/schedules/:id/enroll
///
/// Self-unenrollment (withdrawal) from a schedule.
Future<Response> scheduleUnenrollHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  final enrollment = await supabase
      .from('schedule_enrollments')
      .select('id, status')
      .eq('schedule_id', scheduleId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (enrollment == null) {
    throw NotFoundException('You are not enrolled in this schedule');
  }

  if (enrollment['status'] == 'completed') {
    throw ConflictException('Cannot withdraw from a completed training');
  }

  final now = DateTime.now().toUtc().toIso8601String();

  await supabase
      .from('schedule_enrollments')
      .update({
        'status': 'withdrawn',
        'withdrawn_at': now,
        'updated_at': now,
      })
      .eq('id', enrollment['id']);

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_schedule',
    'entity_id': scheduleId,
    'action': 'withdraw',
    'employee_id': auth.employeeId,
    'old_values': {'status': enrollment['status']},
    'new_values': {'status': 'withdrawn'},
    'created_at': now,
  });

  return ApiResponse.ok({'message': 'Successfully withdrawn'}).toResponse();
}

/// GET /v1/train/schedules/:id/enrollments
///
/// Lists all enrollments for a schedule.
Future<Response> scheduleEnrollmentsListHandler(Request req) async {
  final scheduleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (scheduleId == null || scheduleId.isEmpty) {
    throw ValidationException({'id': 'Schedule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageSchedules)) {
    throw PermissionDeniedException('You do not have permission to view enrollments');
  }

  final enrollments = await supabase
      .from('schedule_enrollments')
      .select('''
        id, status, enrolled_at, assigned_at, withdrawn_at, completed_at,
        employees(id, employee_number, first_name, last_name, email,
          departments(id, name))
      ''')
      .eq('schedule_id', scheduleId)
      .order('created_at', ascending: true);

  return ApiResponse.ok(enrollments).toResponse();
}
