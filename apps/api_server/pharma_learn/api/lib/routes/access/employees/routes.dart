import 'package:relic/relic.dart';

import 'employees_handler.dart';
import 'employee_handler.dart';
import 'employee_roles_handler.dart';

void mountEmployeeRoutes(RelicApp app) {
  app
    ..get('/v1/employees', employeesListHandler)
    ..post('/v1/employees', employeesCreateHandler)
    ..get('/v1/employees/:id', employeeGetHandler)
    ..patch('/v1/employees/:id', employeePatchHandler)
    ..get('/v1/employees/:id/roles', employeeRolesListHandler)
    ..post('/v1/employees/:id/roles', employeeRolesAssignHandler)
    ..delete('/v1/employees/:id/roles/:roleId', employeeRolesRemoveHandler);
}
