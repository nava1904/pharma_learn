import 'package:relic/relic.dart';

import 'trainers_handler.dart';

void mountTrainerRoutes(RelicApp app) {
  app.get('/v1/trainers', trainersListHandler);
  app.get('/v1/trainers/:id', trainerGetHandler);
  app.post('/v1/trainers', trainerCreateHandler);
  app.patch('/v1/trainers/:id', trainerUpdateHandler);
  app.delete('/v1/trainers/:id', trainerDeleteHandler);
  
  // Trainer competencies
  app.post('/v1/trainers/:id/competencies', trainerAddCompetenciesHandler);
  app.delete('/v1/trainers/:id/competencies/:competencyId', trainerRemoveCompetencyHandler);
}
