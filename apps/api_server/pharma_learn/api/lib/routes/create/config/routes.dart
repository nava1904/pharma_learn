import 'package:relic/relic.dart';

import 'config_handler.dart';

void mountConfigRoutes(RelicApp app) {
  // Password policies
  app.get('/v1/config/password-policies', passwordPolicyGetHandler);
  app.patch('/v1/config/password-policies', passwordPolicyUpdateHandler);
  
  // Approval matrices
  app.get('/v1/config/approval-matrices', approvalMatricesListHandler);
  app.get('/v1/config/approval-matrices/:id', approvalMatrixGetHandler);
  app.post('/v1/config/approval-matrices', approvalMatrixCreateHandler);
  app.patch('/v1/config/approval-matrices/:id', approvalMatrixUpdateHandler);
  app.delete('/v1/config/approval-matrices/:id', approvalMatrixDeleteHandler);
  
  // Numbering schemes
  app.get('/v1/config/numbering-schemes', numberingSchemesListHandler);
  app.post('/v1/config/numbering-schemes/:id/next', numberingSchemeNextHandler);
  
  // System settings
  app.get('/v1/config/system-settings', systemSettingsGetHandler);
  app.patch('/v1/config/system-settings', systemSettingsUpdateHandler);
  
  // Feature flags
  app.get('/v1/config/feature-flags', featureFlagsGetHandler);
  app.patch('/v1/config/feature-flags', featureFlagsUpdateHandler);
}
