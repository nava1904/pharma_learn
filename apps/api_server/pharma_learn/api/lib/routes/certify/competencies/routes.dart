import 'package:relic/relic.dart';

import 'competencies_handler.dart';
import 'competency_admin_handler.dart';

/// Mounts /v1/certify/competencies routes
void mountCompetenciesRoutes(RelicApp app) {
  // Employee's own competencies
  app.get('/v1/certify/competencies/my', myCompetenciesHandler);
  
  // Admin competency gap analysis
  app.get('/v1/certify/competencies/gaps', competencyGapsHandler);
  app.get('/v1/certify/competencies/employees/:id', employeeCompetenciesHandler);
  
  // Competency definition CRUD (admin)
  app.get('/v1/certify/competency-definitions', competencyDefinitionsListHandler);
  app.get('/v1/certify/competency-definitions/:id', competencyDefinitionGetHandler);
  app.post('/v1/certify/competency-definitions', competencyDefinitionCreateHandler);
  app.patch('/v1/certify/competency-definitions/:id', competencyDefinitionUpdateHandler);
  app.delete('/v1/certify/competency-definitions/:id', competencyDefinitionDeleteHandler);
  
  // Record employee competency attainment
  app.post('/v1/certify/competencies/:id/assess', competencyAssessHandler);
}
