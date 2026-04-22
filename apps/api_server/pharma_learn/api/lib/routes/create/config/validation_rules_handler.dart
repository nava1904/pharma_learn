import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/config/validation-rules
///
/// Lists all validation rules for form fields and data entry.
/// These rules enforce data quality and regulatory compliance.
Future<Response> validationRulesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view validation rules');
  }

  final params = req.url.queryParameters;
  final entityType = params['entity_type'];
  final fieldName = params['field_name'];

  var query = supabase
      .from('validation_rules')
      .select('''
        id, entity_type, field_name, rule_type, rule_value,
        error_message, severity, is_active, created_at, updated_at
      ''');

  if (entityType != null) query = query.eq('entity_type', entityType);
  if (fieldName != null) query = query.eq('field_name', fieldName);

  final rules = await query.order('entity_type', ascending: true)
      .order('field_name', ascending: true);

  return ApiResponse.ok(rules).toResponse();
}

/// GET /v1/config/validation-rules/:id
///
/// Gets a specific validation rule.
Future<Response> validationRuleGetHandler(Request req) async {
  final ruleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (ruleId == null || ruleId.isEmpty) {
    throw ValidationException({'id': 'Rule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to view validation rules');
  }

  final rule = await supabase
      .from('validation_rules')
      .select('*')
      .eq('id', ruleId)
      .maybeSingle();

  if (rule == null) {
    throw NotFoundException('Validation rule not found');
  }

  return ApiResponse.ok(rule).toResponse();
}

/// POST /v1/config/validation-rules
///
/// Creates a new validation rule.
/// Body: {
///   entity_type: 'training_records' | 'employees' | 'documents' | ...,
///   field_name: string,  // e.g., 'completion_date', 'employee_id'
///   rule_type: 'required' | 'regex' | 'min_length' | 'max_length' | 'range' | 'date_range' | 'lookup',
///   rule_value: string,  // depends on rule_type (e.g., regex pattern, min value)
///   error_message: string,
///   severity: 'error' | 'warning',  // error blocks save, warning allows
/// }
Future<Response> validationRuleCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to create validation rules');
  }

  final entityType = requireString(body, 'entity_type');
  final fieldName = requireString(body, 'field_name');
  final ruleType = requireString(body, 'rule_type');
  final errorMessage = requireString(body, 'error_message');

  // Validate rule_type
  final validTypes = ['required', 'regex', 'min_length', 'max_length', 'range', 'date_range', 'lookup'];
  if (!validTypes.contains(ruleType)) {
    throw ValidationException({
      'rule_type': 'Invalid rule_type. Must be one of: ${validTypes.join(', ')}'
    });
  }

  // Validate rule_value for certain types
  if (ruleType == 'regex') {
    final pattern = body['rule_value'] as String?;
    if (pattern == null || pattern.isEmpty) {
      throw ValidationException({'rule_value': 'Regex pattern is required for regex rule_type'});
    }
    // Try to compile the regex to validate it
    try {
      RegExp(pattern);
    } catch (e) {
      throw ValidationException({'rule_value': 'Invalid regex pattern: $e'});
    }
  }

  final now = DateTime.now().toUtc().toIso8601String();

  final rule = await supabase
      .from('validation_rules')
      .insert({
        'entity_type': entityType,
        'field_name': fieldName,
        'rule_type': ruleType,
        'rule_value': body['rule_value'],
        'error_message': errorMessage,
        'severity': body['severity'] ?? 'error',
        'is_active': true,
        'created_by': auth.employeeId,
        'created_at': now,
      })
      .select()
      .single();

  // Audit log
  await supabase.from('audit_logs').insert({
    'employee_id': auth.employeeId,
    'event_type': 'config.validation_rule_created',
    'entity_type': 'validation_rules',
    'entity_id': rule['id'],
    'details': {
      'entity_type': entityType,
      'field_name': fieldName,
      'rule_type': ruleType,
    },
    'created_at': now,
  });

  return ApiResponse.created(rule).toResponse();
}

/// PATCH /v1/config/validation-rules/:id
///
/// Updates a validation rule.
Future<Response> validationRuleUpdateHandler(Request req) async {
  final ruleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  if (ruleId == null || ruleId.isEmpty) {
    throw ValidationException({'id': 'Rule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to update validation rules');
  }

  final existing = await supabase
      .from('validation_rules')
      .select('id')
      .eq('id', ruleId)
      .maybeSingle();

  if (existing == null) {
    throw NotFoundException('Validation rule not found');
  }

  final updateData = <String, dynamic>{
    'updated_by': auth.employeeId,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  // Validate regex if being updated
  if (body.containsKey('rule_value') && body.containsKey('rule_type') && body['rule_type'] == 'regex') {
    try {
      RegExp(body['rule_value'] as String);
    } catch (e) {
      throw ValidationException({'rule_value': 'Invalid regex pattern: $e'});
    }
  }

  final allowedFields = ['rule_type', 'rule_value', 'error_message', 'severity', 'is_active'];
  for (final field in allowedFields) {
    if (body.containsKey(field)) {
      updateData[field] = body[field];
    }
  }

  final updated = await supabase
      .from('validation_rules')
      .update(updateData)
      .eq('id', ruleId)
      .select()
      .single();

  return ApiResponse.ok(updated).toResponse();
}

/// DELETE /v1/config/validation-rules/:id
///
/// Deletes a validation rule.
Future<Response> validationRuleDeleteHandler(Request req) async {
  final ruleId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (ruleId == null || ruleId.isEmpty) {
    throw ValidationException({'id': 'Rule ID is required'});
  }

  if (!auth.hasPermission(Permissions.manageRoles)) {
    throw PermissionDeniedException('You do not have permission to delete validation rules');
  }

  // Soft delete - set is_active to false
  await supabase
      .from('validation_rules')
      .update({
        'is_active': false,
        'updated_by': auth.employeeId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', ruleId);

  return ApiResponse.noContent().toResponse();
}

/// POST /v1/config/validation-rules/validate
///
/// Validates data against configured rules.
/// Body: {
///   entity_type: string,
///   data: { field_name: value, ... }
/// }
/// Returns: { valid: bool, errors: [...], warnings: [...] }
Future<Response> validationRulesValidateHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final entityType = requireString(body, 'entity_type');
  final data = body['data'] as Map<String, dynamic>? ?? {};

  // Get active rules for this entity type
  final rules = await supabase
      .from('validation_rules')
      .select('field_name, rule_type, rule_value, error_message, severity')
      .eq('entity_type', entityType)
      .eq('is_active', true);

  final errors = <Map<String, dynamic>>[];
  final warnings = <Map<String, dynamic>>[];

  for (final rule in rules) {
    final fieldName = rule['field_name'] as String;
    final ruleType = rule['rule_type'] as String;
    final ruleValue = rule['rule_value'];
    final errorMessage = rule['error_message'] as String;
    final severity = rule['severity'] as String;
    final value = data[fieldName];

    String? violation;

    switch (ruleType) {
      case 'required':
        if (value == null || (value is String && value.isEmpty)) {
          violation = errorMessage;
        }
        break;
      case 'regex':
        if (value != null && value is String) {
          final regex = RegExp(ruleValue as String);
          if (!regex.hasMatch(value)) {
            violation = errorMessage;
          }
        }
        break;
      case 'min_length':
        if (value != null && value is String) {
          final minLen = int.parse(ruleValue.toString());
          if (value.length < minLen) {
            violation = errorMessage;
          }
        }
        break;
      case 'max_length':
        if (value != null && value is String) {
          final maxLen = int.parse(ruleValue.toString());
          if (value.length > maxLen) {
            violation = errorMessage;
          }
        }
        break;
      case 'range':
        if (value != null && value is num) {
          final parts = ruleValue.toString().split(',');
          final min = double.parse(parts[0]);
          final max = double.parse(parts[1]);
          if (value < min || value > max) {
            violation = errorMessage;
          }
        }
        break;
    }

    if (violation != null) {
      final errorEntry = {
        'field': fieldName,
        'message': violation,
        'rule_type': ruleType,
      };
      if (severity == 'warning') {
        warnings.add(errorEntry);
      } else {
        errors.add(errorEntry);
      }
    }
  }

  return ApiResponse.ok({
    'valid': errors.isEmpty,
    'errors': errors,
    'warnings': warnings,
  }).toResponse();
}
