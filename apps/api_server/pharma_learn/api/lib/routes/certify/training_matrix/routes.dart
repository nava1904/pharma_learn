import 'package:relic/relic.dart';

import 'training_matrix_handler.dart';

/// Mounts /v1/certify/training-matrix routes
void mountTrainingMatrixRoutes(RelicApp app) {
  // Matrix CRUD
  app.get('/v1/certify/training-matrix', trainingMatrixListHandler);
  app.get('/v1/certify/training-matrix/:id', trainingMatrixGetHandler);
  app.post('/v1/certify/training-matrix', trainingMatrixCreateHandler);
  app.put('/v1/certify/training-matrix/:id', trainingMatrixUpdateHandler);
  // Matrix items
  app.post('/v1/certify/training-matrix/:id/items', trainingMatrixAddItemHandler);
  app.delete('/v1/certify/training-matrix/:id/items/:itemId', trainingMatrixRemoveItemHandler);
  // Workflow
  app.post('/v1/certify/training-matrix/:id/submit', trainingMatrixSubmitHandler);
  app.post('/v1/certify/training-matrix/:id/approve', trainingMatrixApproveHandler);
  // Analytics
  app.get('/v1/certify/training-matrix/:id/coverage', trainingMatrixCoverageHandler);
  app.get('/v1/certify/training-matrix/:id/gap-analysis', trainingMatrixGapAnalysisHandler);
}
