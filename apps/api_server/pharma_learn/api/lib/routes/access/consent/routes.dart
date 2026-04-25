import 'package:relic/relic.dart';

import 'consent_handler.dart';

void mountConsentRoutes(RelicApp app) {
  // Policy management (admin)
  app.get('/v1/consent/policies', consentPoliciesListHandler);
  app.get('/v1/consent/policies/:id', consentPolicyGetHandler);
  app.post('/v1/consent/policies', createConsentPolicyHandler);
  app.patch('/v1/consent/policies/:id', updateConsentPolicyHandler);
  
  // User consent management
  app.get('/v1/consent/me', myConsentsHandler);
  app.get('/v1/consent/pending', pendingConsentsHandler);
  app.post('/v1/consent/:policyId/accept', acceptConsentHandler);
  app.post('/v1/consent/:policyId/revoke', revokeConsentHandler);
}
