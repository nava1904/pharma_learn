import 'package:relic/relic.dart';

import 'competencies_handler.dart';

/// Mounts /v1/certify/competencies routes
void mountCompetenciesRoutes(RelicApp app) {
  // Employee's own competencies
  app.get('/v1/certify/competencies/my', myCompetenciesHandler);
  
  // Admin competency gap analysis
  app.get('/v1/certify/competencies/gaps', competencyGapsHandler);
  app.get('/v1/certify/competencies/employees/:id', employeeCompetenciesHandler);
}
