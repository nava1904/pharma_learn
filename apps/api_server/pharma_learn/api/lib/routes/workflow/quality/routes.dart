import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'deviation_handler.dart';
import 'capa_handler.dart';
import 'change_control_handler.dart';

/// Mounts /v1/quality/* routes for quality management.
void mountQualityRoutes(RelicApp app) {
  // Deviations
  app.get('/v1/quality/deviations', deviationsListHandler);
  app.post('/v1/quality/deviations', deviationCreateHandler);
  app.get('/v1/quality/deviations/:id', deviationGetHandler);
  app.patch('/v1/quality/deviations/:id', deviationUpdateHandler);
  app.post('/v1/quality/deviations/:id/capa', deviationCapaHandler);
  
  // CAPAs
  app.get('/v1/quality/capas', capasListHandler);
  app.post('/v1/quality/capas', capaCreateHandler);
  app.get('/v1/quality/capas/:id', capaGetHandler);
  app.patch('/v1/quality/capas/:id', capaUpdateHandler);
  app.post('/v1/quality/capas/:id/close', withEsig(capaCloseHandler));
  
  // Change Controls - ICH Q10 §3.2.4
  app.get('/v1/quality/change-controls', changeControlsListHandler);
  app.post('/v1/quality/change-controls', changeControlCreateHandler);
  app.get('/v1/quality/change-controls/:id', changeControlGetHandler);
  app.patch('/v1/quality/change-controls/:id', changeControlUpdateHandler);
  app.post('/v1/quality/change-controls/:id/implement', withEsig(changeControlImplementHandler));
  app.post('/v1/quality/change-controls/:id/close', withEsig(changeControlCloseHandler));
}
