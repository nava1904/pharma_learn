import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'gtps_handler.dart';
import 'gtp_handler.dart';
import 'gtp_submit_handler.dart';
import 'gtp_approve_handler.dart';
import 'gtp_courses_handler.dart';

void mountGtpRoutes(RelicApp app) {
  app
    ..get('/v1/gtps', gtpsListHandler)
    ..post('/v1/gtps', gtpsCreateHandler)
    ..get('/v1/gtps/:id', gtpGetHandler)
    ..patch('/v1/gtps/:id', gtpPatchHandler)
    ..post('/v1/gtps/:id/submit', gtpSubmitHandler)
    ..post('/v1/gtps/:id/approve', withEsig(gtpApproveHandler))
    ..get('/v1/gtps/:id/courses', gtpCoursesListHandler)
    ..post('/v1/gtps/:id/courses', gtpCoursesAddHandler);
}
