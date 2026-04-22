import 'package:relic/relic.dart';

import 'departments_handler.dart';

void mountDepartmentRoutes(RelicApp app) {
  // Collection
  app.get('/v1/access/departments', departmentsListHandler);
  app.post('/v1/access/departments', departmentCreateHandler);
  app.get('/v1/access/departments/hierarchy', departmentHierarchyHandler);

  // Individual department
  app.get('/v1/access/departments/:id', departmentGetHandler);
  app.patch('/v1/access/departments/:id', departmentUpdateHandler);
  app.delete('/v1/access/departments/:id', departmentDeleteHandler);

  // Workflow
  app.post('/v1/access/departments/:id/submit', departmentSubmitHandler);
  app.post('/v1/access/departments/:id/approve', departmentApproveHandler);

  // Employees in department
  app.get('/v1/access/departments/:id/employees', departmentEmployeesHandler);
}
