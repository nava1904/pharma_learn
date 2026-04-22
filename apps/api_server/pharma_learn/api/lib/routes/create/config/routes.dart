import 'package:relic/relic.dart';

import 'config_handler.dart';
import 'master_data_handler.dart';
import 'retention_policies_handler.dart';
import 'validation_rules_handler.dart';

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
  
  // Retention policies (21 CFR Part 11 / WHO GMP / ICH E6(R2))
  app.get('/v1/config/retention-policies', retentionPoliciesListHandler);
  app.get('/v1/config/retention-policies/:id', retentionPolicyGetHandler);
  app.post('/v1/config/retention-policies', retentionPolicyCreateHandler);
  app.patch('/v1/config/retention-policies/:id', retentionPolicyUpdateHandler);
  app.delete('/v1/config/retention-policies/:id', retentionPolicyDeleteHandler);
  
  // Validation rules (data quality enforcement)
  app.get('/v1/config/validation-rules', validationRulesListHandler);
  app.get('/v1/config/validation-rules/:id', validationRuleGetHandler);
  app.post('/v1/config/validation-rules', validationRuleCreateHandler);
  app.patch('/v1/config/validation-rules/:id', validationRuleUpdateHandler);
  app.delete('/v1/config/validation-rules/:id', validationRuleDeleteHandler);
  app.post('/v1/config/validation-rules/validate', validationRulesValidateHandler);
  
  // Format numbers (Phase 3: Master data)
  app.get('/v1/config/format-numbers', formatNumbersListHandler);
  app.get('/v1/config/format-numbers/:id', formatNumberGetHandler);
  app.post('/v1/config/format-numbers', formatNumberCreateHandler);
  app.put('/v1/config/format-numbers/:id', formatNumberUpdateHandler);
  app.delete('/v1/config/format-numbers/:id', formatNumberDeleteHandler);
  
  // Satisfaction scales (Phase 3: Master data)
  app.get('/v1/config/satisfaction-scales', satisfactionScalesListHandler);
  app.get('/v1/config/satisfaction-scales/:id', satisfactionScaleGetHandler);
  app.post('/v1/config/satisfaction-scales', satisfactionScaleCreateHandler);
  app.put('/v1/config/satisfaction-scales/:id', satisfactionScaleUpdateHandler);
  app.delete('/v1/config/satisfaction-scales/:id', satisfactionScaleDeleteHandler);
}
