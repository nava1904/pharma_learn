import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'courses_handler.dart';
import 'course_handler.dart';
import 'course_submit_handler.dart';
import 'course_approve_handler.dart';
import 'course_topics_handler.dart';

void mountCourseRoutes(RelicApp app) {
  app
    ..get('/v1/courses', coursesListHandler)
    ..post('/v1/courses', coursesCreateHandler)
    ..get('/v1/courses/:id', courseGetHandler)
    ..patch('/v1/courses/:id', coursePatchHandler)
    ..post('/v1/courses/:id/submit', courseSubmitHandler)
    ..post('/v1/courses/:id/approve', withEsig(courseApproveHandler))
    ..get('/v1/courses/:id/topics', courseTopicsListHandler)
    ..post('/v1/courses/:id/topics', courseTopicsAddHandler);
}
