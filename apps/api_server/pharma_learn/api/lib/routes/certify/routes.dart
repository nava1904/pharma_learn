import 'package:relic/relic.dart';

import 'analytics/routes.dart';
import 'assessments/routes.dart';
import 'certificates/routes.dart';
import 'competencies/routes.dart';
import 'compliance/routes.dart';
import 'esignatures/routes.dart';
import 'inspection/routes.dart';
import 'integrity/routes.dart';
import 'reauth/routes.dart';
import 'remedial/routes.dart';
import 'training_matrix/routes.dart';
import 'waivers/routes.dart';

void mountCertifyRoutes(RelicApp app) {
  // Re-authentication for e-signatures
  mountReauthRoutes(app);
  
  // E-signatures (21 CFR Part 11)
  mountEsignaturesRoutes(app);
  
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
  
  // Analytics (course stats, question psychometrics)
  mountAnalyticsRoutes(app);
  
  // Integrity verification (21 CFR §11.10(c))
  mountIntegrityRoutes(app);
  
  // Remedial training
  mountRemedialRoutes(app);
  
  // Training matrix for role-based requirements
  mountTrainingMatrixRoutes(app);
  
  // Inspection-readiness dashboard
  mountInspectionRoutes(app);
}
