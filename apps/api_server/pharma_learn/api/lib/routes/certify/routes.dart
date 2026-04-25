import 'package:relic/relic.dart';

import 'reauth/routes.dart';
// S5 additions:
// import 'assessments/routes.dart';
// import 'certificates/routes.dart';
// import 'esignatures/routes.dart';
// import 'compliance/routes.dart';
// import 'waivers/routes.dart';
// import 'remedial/routes.dart';
// import 'competencies/routes.dart';
// import 'integrity/routes.dart';

void mountCertifyRoutes(RelicApp app) {
  mountReauthRoutes(app);
}
