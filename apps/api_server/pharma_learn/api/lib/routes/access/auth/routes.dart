import 'package:relic/relic.dart';

import 'login_handler.dart';
import 'logout_handler.dart';
import 'refresh_handler.dart';
import 'register_handler.dart';
import 'profile_handler.dart';
import 'mfa_handler.dart';
import 'password_handler.dart';
import 'password_reset_handler.dart';
import 'sessions_handler.dart';
import 'permissions_handler.dart';
import 'esig_cert_handler.dart';

void mountAuthRoutes(RelicApp app) {
  app
    // ── Public (no auth required) ─────────────────────────────────────────
    ..post('/v1/auth/login', loginHandler)
    ..post('/v1/auth/refresh', refreshHandler)
    ..post('/v1/auth/password/reset-request', passwordResetRequestHandler)
    ..post('/v1/auth/password/reset', passwordResetHandler)

    // ── Admin only ────────────────────────────────────────────────────────
    ..post('/v1/auth/register', registerHandler)

    // ── Authenticated ─────────────────────────────────────────────────────
    ..post('/v1/auth/logout', logoutHandler)
    ..get('/v1/auth/profile', profileHandler)

    // MFA
    ..post('/v1/auth/mfa/verify', mfaVerifyHandler)
    ..post('/v1/auth/mfa/enable', mfaEnableHandler)
    ..post('/v1/auth/mfa/verify-setup', mfaVerifySetupHandler)
    ..post('/v1/auth/mfa/disable', mfaDisableHandler)

    // Password
    ..post('/v1/auth/password/change', passwordChangeHandler)

    // Sessions
    ..get('/v1/auth/sessions', sessionsListHandler)
    ..post('/v1/auth/sessions/:id/revoke', sessionRevokeHandler)
    ..post('/v1/auth/sessions/revoke-all', sessionsRevokeAllHandler)

    // Permissions
    ..post('/v1/auth/permissions/check', permissionsCheckHandler)
    
    // E-Signature certificates (21 CFR §11.100)
    ..post('/v1/auth/esig/upload-certificate', esigCertificateUploadHandler)
    ..get('/v1/auth/esig/certificates', esigCertificatesListHandler)
    ..delete('/v1/auth/esig/certificates/:id', esigCertificateRevokeHandler);
}
