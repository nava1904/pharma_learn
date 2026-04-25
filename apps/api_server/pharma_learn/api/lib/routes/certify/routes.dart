import 'package:relic/relic.dart';

import 'assessments/routes.dart';
import 'certificates/routes.dart';
import 'competencies/routes.dart';
import 'compliance/routes.dart';
import 'reauth/routes.dart';
import 'waivers/routes.dart';

void mountCertifyRoutes(RelicApp app) {
  // Re-authentication for e-signatures
  mountReauthRoutes(app);
  
  // Assessment flow
  mountAssessmentsRoutes(app);
  
  // Certificates
  mountCertificatesRoutes(app);
  
  // Compliance dashboard
  mountComplianceRoutes(app);
  
  // Waiver management
  mountWaiversRoutes(app);
  
  // Competency tracking
  mountCompetenciesRoutes(app);
  
  // TODO: Add these as they are implemented
  // mountEsignaturesRoutes(app);
  // mountRemedialRoutes(app);
  // mountIntegrityRoutes(app);
}
