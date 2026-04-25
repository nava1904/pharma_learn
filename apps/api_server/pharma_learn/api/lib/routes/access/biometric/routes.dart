import 'package:relic/relic.dart';

import 'biometric_handler.dart';

void mountBiometricRoutes(RelicApp app) {
  // List user's biometric credentials
  app.get('/v1/auth/biometric', biometricListHandler);
  
  // Register new biometric credential
  app.post('/v1/auth/biometric/register', biometricRegisterHandler);
  
  // Login with biometric
  app.post('/v1/auth/biometric/login', biometricLoginHandler);
  
  // Revoke a credential
  app.delete('/v1/auth/biometric/:id', biometricRevokeHandler);
}
