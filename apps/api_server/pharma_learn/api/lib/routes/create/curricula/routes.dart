import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'curricula_handler.dart';

void mountCurriculaRoutes(RelicApp app) {
  app.get('/v1/curricula', curriculaListHandler);
  app.get('/v1/curricula/:id', curriculumGetHandler);
  app.post('/v1/curricula', curriculumCreateHandler);
  app.patch('/v1/curricula/:id', curriculumUpdateHandler);
  
  // Course management within curriculum
  app.post('/v1/curricula/:id/courses', curriculumAddCourseHandler);
  app.delete('/v1/curricula/:id/courses/:courseId', curriculumRemoveCourseHandler);
  
  // Workflow
  app.post('/v1/curricula/:id/submit', curriculumSubmitHandler);
  app.post('/v1/curricula/:id/approve', withEsig(curriculumApproveHandler));
}
