import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/train/triggers/process
/// 
/// Process training triggers (SOP updates → re-enrollment).
/// This is typically called by the lifecycle_monitor when a document
/// is updated or when a training_trigger_rules event fires.
Future<Response> triggersProcessHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Permission check - admin or system
  if (!auth.hasPermission('training.triggers.manage') &&
      !auth.hasPermission('system.admin')) {
    throw PermissionDeniedException('Training trigger management access required');
  }

  final triggerType = body['trigger_type'] as String?;
  final entityId = body['entity_id'] as String?;

  if (triggerType == null) {
    throw ValidationException({'trigger_type': 'Trigger type is required'});
  }
  if (entityId == null) {
    throw ValidationException({'entity_id': 'Entity ID is required'});
  }

  // Process based on trigger type
  final results = switch (triggerType) {
    'sop_update' => await _processSopUpdate(supabase, auth.orgId, entityId),
    'role_change' => await _processRoleChange(supabase, auth.orgId, entityId, body),
    'new_hire' => await _processNewHire(supabase, auth.orgId, entityId),
    'matrix_activation' => await _processMatrixActivation(supabase, auth.orgId, entityId),
    'periodic_renewal' => await _processPeriodicRenewal(supabase, auth.orgId, entityId),
    'competency_gap' => await _processCompetencyGap(supabase, auth.orgId, entityId),
    _ => throw ValidationException({'trigger_type': 'Unknown trigger type: $triggerType'}),
  };

  return ApiResponse.ok({
    'trigger_type': triggerType,
    'entity_id': entityId,
    'processed_at': DateTime.now().toUtc().toIso8601String(),
    'results': results,
  }).toResponse();
}

/// Process SOP update trigger - re-enrolls affected employees.
Future<Map<String, dynamic>> _processSopUpdate(
  dynamic supabase,
  String orgId,
  String documentId,
) async {
  // Get the document and its linked courses
  final document = await supabase
      .from('documents')
      .select('id, title, version, effective_date')
      .eq('id', documentId)
      .maybeSingle();

  if (document == null) {
    return {'error': 'Document not found', 'assignments_created': 0};
  }

  // Find courses linked to this document
  final courseLinks = await supabase
      .from('course_documents')
      .select('course_id')
      .eq('document_id', documentId);

  if (courseLinks.isEmpty) {
    return {'message': 'No courses linked to this document', 'assignments_created': 0};
  }

  final courseIds = (courseLinks as List).map((c) => c['course_id']).toList();

  // Get employees who need re-training (have completed this course before)
  final previousTrainees = await supabase
      .from('training_records')
      .select('employee_id')
      .inFilter('course_id', courseIds)
      .eq('overall_status', 'completed');

  if (previousTrainees.isEmpty) {
    return {'message': 'No employees need re-training', 'assignments_created': 0};
  }

  final employeeIds = (previousTrainees as List)
      .map((t) => t['employee_id'])
      .toSet()
      .toList();

  // Create new assignments for re-training
  int assignmentsCreated = 0;
  final dueDate = DateTime.now().toUtc().add(const Duration(days: 30));

  for (final courseId in courseIds) {
    for (final employeeId in employeeIds) {
      // Check if already has pending assignment
      final existing = await supabase
          .from('employee_training_obligations')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('course_id', courseId)
          .inFilter('status', ['pending', 'in_progress', 'overdue'])
          .maybeSingle();

      if (existing == null) {
        await supabase.from('employee_training_obligations').insert({
          'employee_id': employeeId,
          'course_id': courseId,
          'organization_id': orgId,
          'status': 'pending',
          'assignment_type': 'sop_update',
          'due_date': dueDate.toIso8601String(),
          'trigger_document_id': documentId,
        });
        assignmentsCreated++;
      }
    }
  }

  return {
    'document_title': document['title'],
    'document_version': document['version'],
    'courses_affected': courseIds.length,
    'employees_affected': employeeIds.length,
    'assignments_created': assignmentsCreated,
  };
}

/// Process role change trigger - assigns role-specific training.
Future<Map<String, dynamic>> _processRoleChange(
  dynamic supabase,
  String orgId,
  String employeeId,
  Map<String, dynamic> body,
) async {
  final newRoleId = body['new_role_id'] as String?;
  final oldRoleId = body['old_role_id'] as String?;

  if (newRoleId == null) {
    return {'error': 'new_role_id is required', 'assignments_created': 0};
  }

  // Get training requirements for the new role
  final roleCompetencies = await supabase
      .from('role_competencies')
      .select('competency_id, required_level')
      .eq('role_id', newRoleId);

  // Get courses for required competencies
  final competencyIds = (roleCompetencies as List)
      .map((rc) => rc['competency_id'])
      .toList();

  if (competencyIds.isEmpty) {
    return {'message': 'No competency requirements for new role', 'assignments_created': 0};
  }

  final courses = await supabase
      .from('courses')
      .select('id')
      .inFilter('competency_id', competencyIds);

  if (courses.isEmpty) {
    return {'message': 'No courses mapped to role competencies', 'assignments_created': 0};
  }

  // Create assignments
  int assignmentsCreated = 0;
  final dueDate = DateTime.now().toUtc().add(const Duration(days: 30));

  for (final course in courses) {
    final existing = await supabase
        .from('employee_training_obligations')
        .select('id')
        .eq('employee_id', employeeId)
        .eq('course_id', course['id'])
        .inFilter('status', ['pending', 'in_progress', 'overdue', 'completed'])
        .maybeSingle();

    if (existing == null) {
      await supabase.from('employee_training_obligations').insert({
        'employee_id': employeeId,
        'course_id': course['id'],
        'organization_id': orgId,
        'status': 'pending',
        'assignment_type': 'role_change',
        'due_date': dueDate.toIso8601String(),
      });
      assignmentsCreated++;
    }
  }

  return {
    'employee_id': employeeId,
    'new_role_id': newRoleId,
    'old_role_id': oldRoleId,
    'competencies_required': competencyIds.length,
    'assignments_created': assignmentsCreated,
  };
}

/// Process new hire trigger - assigns induction and mandatory training.
Future<Map<String, dynamic>> _processNewHire(
  dynamic supabase,
  String orgId,
  String employeeId,
) async {
  // Get employee's role
  final employee = await supabase
      .from('employees')
      .select('id, role_id, department_id, plant_id')
      .eq('id', employeeId)
      .maybeSingle();

  if (employee == null) {
    return {'error': 'Employee not found', 'assignments_created': 0};
  }

  // Get induction program for the org
  final induction = await supabase
      .from('induction_programs')
      .select('id')
      .eq('organization_id', orgId)
      .eq('status', 'active')
      .maybeSingle();

  // Get mandatory training for all employees
  final mandatoryCourses = await supabase
      .from('training_matrix')
      .select('id, training_matrix_items(course_id)')
      .eq('organization_id', orgId)
      .eq('status', 'active')
      .eq('is_mandatory', true);

  int assignmentsCreated = 0;
  final dueDate = DateTime.now().toUtc().add(const Duration(days: 30));

  // Create induction assignment if exists
  if (induction != null) {
    await supabase.from('employee_induction_progress').insert({
      'employee_id': employeeId,
      'induction_program_id': induction['id'],
      'organization_id': orgId,
      'status': 'not_started',
      'started_at': null,
    }).onConflict('employee_id,induction_program_id').ignore();
  }

  // Create mandatory training assignments
  for (final matrix in mandatoryCourses) {
    final items = matrix['training_matrix_items'] as List? ?? [];
    for (final item in items) {
      final courseId = item['course_id'];
      
      final existing = await supabase
          .from('employee_training_obligations')
          .select('id')
          .eq('employee_id', employeeId)
          .eq('course_id', courseId)
          .maybeSingle();

      if (existing == null) {
        await supabase.from('employee_training_obligations').insert({
          'employee_id': employeeId,
          'course_id': courseId,
          'organization_id': orgId,
          'status': 'pending',
          'assignment_type': 'new_hire',
          'due_date': dueDate.toIso8601String(),
        });
        assignmentsCreated++;
      }
    }
  }

  // Process role-specific training
  if (employee['role_id'] != null) {
    final roleResult = await _processRoleChange(
      supabase,
      orgId,
      employeeId,
      {'new_role_id': employee['role_id']},
    );
    assignmentsCreated += roleResult['assignments_created'] as int? ?? 0;
  }

  return {
    'employee_id': employeeId,
    'induction_assigned': induction != null,
    'assignments_created': assignmentsCreated,
  };
}

/// Process matrix activation trigger - enrolls all applicable employees.
Future<Map<String, dynamic>> _processMatrixActivation(
  dynamic supabase,
  String orgId,
  String matrixId,
) async {
  // Get matrix with items
  final matrix = await supabase
      .from('training_matrix')
      .select('''
        id,
        name,
        scope,
        plant_id,
        department_id,
        role_id,
        training_matrix_items(course_id)
      ''')
      .eq('id', matrixId)
      .maybeSingle();

  if (matrix == null) {
    return {'error': 'Training matrix not found', 'assignments_created': 0};
  }

  // Build employee query based on scope
  var employeeQuery = supabase
      .from('employees')
      .select('id')
      .eq('organization_id', orgId)
      .eq('status', 'active');

  if (matrix['plant_id'] != null) {
    employeeQuery = employeeQuery.eq('plant_id', matrix['plant_id']);
  }
  if (matrix['department_id'] != null) {
    employeeQuery = employeeQuery.eq('department_id', matrix['department_id']);
  }
  if (matrix['role_id'] != null) {
    employeeQuery = employeeQuery.eq('role_id', matrix['role_id']);
  }

  final employees = await employeeQuery;
  final items = matrix['training_matrix_items'] as List? ?? [];

  int assignmentsCreated = 0;
  final dueDate = DateTime.now().toUtc().add(const Duration(days: 30));

  for (final employee in employees) {
    for (final item in items) {
      final existing = await supabase
          .from('employee_training_obligations')
          .select('id')
          .eq('employee_id', employee['id'])
          .eq('course_id', item['course_id'])
          .inFilter('status', ['pending', 'in_progress', 'overdue'])
          .maybeSingle();

      if (existing == null) {
        await supabase.from('employee_training_obligations').insert({
          'employee_id': employee['id'],
          'course_id': item['course_id'],
          'organization_id': orgId,
          'status': 'pending',
          'assignment_type': 'matrix_activation',
          'due_date': dueDate.toIso8601String(),
          'training_matrix_id': matrixId,
        });
        assignmentsCreated++;
      }
    }
  }

  return {
    'matrix_name': matrix['name'],
    'matrix_id': matrixId,
    'employees_in_scope': employees.length,
    'courses_in_matrix': items.length,
    'assignments_created': assignmentsCreated,
  };
}

/// Process periodic renewal trigger - creates next training obligation.
Future<Map<String, dynamic>> _processPeriodicRenewal(
  dynamic supabase,
  String orgId,
  String trainingRecordId,
) async {
  // Get the completed training record
  final record = await supabase
      .from('training_records')
      .select('''
        id,
        employee_id,
        course_id,
        completed_at,
        courses(
          id,
          course_type,
          frequency_type,
          frequency_interval
        )
      ''')
      .eq('id', trainingRecordId)
      .maybeSingle();

  if (record == null) {
    return {'error': 'Training record not found', 'assignments_created': 0};
  }

  final course = record['courses'];
  if (course == null || course['course_type'] != 'periodic') {
    return {'message': 'Not a periodic course', 'assignments_created': 0};
  }

  // Calculate next due date
  final completedAt = DateTime.parse(record['completed_at']);
  final intervalMonths = switch (course['frequency_type']) {
    'monthly' => (course['frequency_interval'] as int?) ?? 1,
    'quarterly' => ((course['frequency_interval'] as int?) ?? 1) * 3,
    'annual' => ((course['frequency_interval'] as int?) ?? 1) * 12,
    _ => 12, // Default to annual
  };

  final nextDueDate = DateTime(
    completedAt.year,
    completedAt.month + intervalMonths,
    completedAt.day,
  );

  // Check if assignment already exists
  final existing = await supabase
      .from('employee_training_obligations')
      .select('id')
      .eq('employee_id', record['employee_id'])
      .eq('course_id', record['course_id'])
      .inFilter('status', ['pending', 'in_progress', 'overdue'])
      .maybeSingle();

  if (existing != null) {
    return {'message': 'Renewal assignment already exists', 'assignments_created': 0};
  }

  // Create renewal assignment
  await supabase.from('employee_training_obligations').insert({
    'employee_id': record['employee_id'],
    'course_id': record['course_id'],
    'organization_id': orgId,
    'status': 'pending',
    'assignment_type': 'periodic_renewal',
    'due_date': nextDueDate.toIso8601String(),
    'previous_training_record_id': trainingRecordId,
  });

  return {
    'employee_id': record['employee_id'],
    'course_id': record['course_id'],
    'previous_completed_at': record['completed_at'],
    'next_due_date': nextDueDate.toIso8601String(),
    'assignments_created': 1,
  };
}

/// Process competency gap trigger - assigns training to close gaps.
Future<Map<String, dynamic>> _processCompetencyGap(
  dynamic supabase,
  String orgId,
  String employeeId,
) async {
  // Get employee's role requirements
  final employee = await supabase
      .from('employees')
      .select('id, role_id')
      .eq('id', employeeId)
      .maybeSingle();

  if (employee == null || employee['role_id'] == null) {
    return {'error': 'Employee or role not found', 'assignments_created': 0};
  }

  // Get role competency requirements
  final requirements = await supabase
      .from('role_competencies')
      .select('competency_id, required_level')
      .eq('role_id', employee['role_id']);

  // Get employee's current competencies
  final currentCompetencies = await supabase
      .from('employee_competencies')
      .select('competency_id, current_level')
      .eq('employee_id', employeeId);

  final currentMap = {
    for (final c in currentCompetencies)
      c['competency_id']: c['current_level']
  };

  // Find gaps
  final gaps = <String>[];
  for (final req in requirements) {
    final current = currentMap[req['competency_id']] ?? 0;
    if (current < req['required_level']) {
      gaps.add(req['competency_id']);
    }
  }

  if (gaps.isEmpty) {
    return {'message': 'No competency gaps found', 'assignments_created': 0};
  }

  // Find courses that address the gaps
  final courses = await supabase
      .from('courses')
      .select('id')
      .inFilter('competency_id', gaps);

  int assignmentsCreated = 0;
  final dueDate = DateTime.now().toUtc().add(const Duration(days: 30));

  for (final course in courses) {
    final existing = await supabase
        .from('employee_training_obligations')
        .select('id')
        .eq('employee_id', employeeId)
        .eq('course_id', course['id'])
        .inFilter('status', ['pending', 'in_progress', 'overdue'])
        .maybeSingle();

    if (existing == null) {
      await supabase.from('employee_training_obligations').insert({
        'employee_id': employeeId,
        'course_id': course['id'],
        'organization_id': orgId,
        'status': 'pending',
        'assignment_type': 'competency_gap',
        'due_date': dueDate.toIso8601String(),
      });
      assignmentsCreated++;
    }
  }

  return {
    'employee_id': employeeId,
    'competency_gaps': gaps.length,
    'assignments_created': assignmentsCreated,
  };
}
