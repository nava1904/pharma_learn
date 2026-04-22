import 'package:relic/relic.dart';

import 'employees_handler.dart';
import 'employee_handler.dart';
import 'employee_bulk_handler.dart';
import 'employee_credentials_handler.dart';
import 'employee_deactivate_handler.dart';
import 'employee_profile_handler.dart';
import 'employee_roles_handler.dart';
import 'employee_task_terminate_handler.dart';

void mountEmployeeRoutes(RelicApp app) {
  app
    ..get('/v1/access/employees', employeesListHandler)
    ..post('/v1/access/employees', employeesCreateHandler)
    ..post('/v1/access/employees/bulk', employeeBulkHandler)
    ..get('/v1/access/employees/:id', employeeGetHandler)
    ..patch('/v1/access/employees/:id', employeePatchHandler)
    ..patch('/v1/access/employees/:id/deactivate', employeeDeactivateHandler)
    // Credential management (admin)
    ..post('/v1/access/employees/:id/credentials', employeeCredentialsResetHandler)
    ..post('/v1/access/employees/:id/unlock', employeeUnlockHandler)
    // Role management
    ..get('/v1/access/employees/:id/roles', employeeRolesListHandler)
    ..post('/v1/access/employees/:id/roles', employeeRolesAssignHandler)
    ..delete('/v1/access/employees/:id/roles/:roleId', employeeRolesRemoveHandler)
    // Profile and permissions management
    ..get('/v1/access/employees/:id/profile', employeeProfileGetHandler)
    ..put('/v1/access/employees/:id/profile', employeeProfileAssignHandler)
    ..get('/v1/access/employees/:id/permissions', employeePermissionsListHandler)
    ..post('/v1/access/employees/:id/permissions/grant', employeePermissionGrantHandler)
    ..post('/v1/access/employees/:id/permissions/revoke', employeePermissionRevokeHandler)
    ..post('/v1/access/employees/:id/permissions/bulk', employeePermissionsBulkHandler)
    ..delete('/v1/access/employees/:id/permissions/:permission', employeePermissionRemoveHandler)
    // GAP-M6: Pending task termination
    ..get('/v1/access/employees/:id/pending-tasks', employeePendingTasksListHandler)
    ..post('/v1/access/employees/:id/pending-tasks/terminate', employeeTaskTerminateHandler);
}
