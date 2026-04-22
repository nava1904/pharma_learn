import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'trainers_handler.dart';
import 'trainer_approve_handler.dart';

void mountTrainerRoutes(RelicApp app) {
  app.get('/v1/trainers', trainersListHandler);
  app.get('/v1/trainers/:id', trainerGetHandler);
  app.post('/v1/trainers', trainerCreateHandler);
  app.patch('/v1/trainers/:id', trainerUpdateHandler);
  app.delete('/v1/trainers/:id', trainerDeleteHandler);
  
  // Trainer approval workflow
  app.post('/v1/trainers/:id/approve', withEsig(trainerApproveHandler));
  
  // Trainer certifications
  app.get('/v1/trainers/:id/certifications', trainerCertificationsListHandler);
  app.post('/v1/trainers/:id/certifications', trainerCertificationAddHandler);
  
  // Trainer competencies
  app.post('/v1/trainers/:id/competencies', trainerAddCompetenciesHandler);
  app.delete('/v1/trainers/:id/competencies/:competencyId', trainerRemoveCompetencyHandler);
}
