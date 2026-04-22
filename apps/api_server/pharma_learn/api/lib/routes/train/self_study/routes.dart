import 'package:relic/relic.dart';

import 'self_study_handler.dart';

void mountSelfStudyRoutes(RelicApp app) {
  app
    ..get('/v1/train/self-study-courses', selfStudyCoursesListHandler)
    ..get('/v1/train/self-study-courses/:id', selfStudyCourseGetHandler)
    ..post('/v1/train/self-study-courses/:id/enroll', selfStudyCourseEnrollHandler)
    ..get('/v1/train/self-study-courses/:id/progress', selfStudyCourseProgressHandler)
    ..delete('/v1/train/self-study-courses/:id/enroll', selfStudyCourseUnenrollHandler);
}
