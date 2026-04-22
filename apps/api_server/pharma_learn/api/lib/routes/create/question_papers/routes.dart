import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'question_papers_handler.dart';

void mountQuestionPaperRoutes(RelicApp app) {
  app.get('/v1/question-papers', questionPapersListHandler);
  app.get('/v1/question-papers/:id', questionPaperGetHandler);
  app.post('/v1/question-papers', questionPaperCreateHandler);
  app.patch('/v1/question-papers/:id', questionPaperUpdateHandler);
  app.delete('/v1/question-papers/:id', questionPaperDeleteHandler);
  
  // Question management within paper
  app.post('/v1/question-papers/:id/questions', questionPaperAddQuestionHandler);
  app.delete('/v1/question-papers/:id/questions/:questionId', questionPaperRemoveQuestionHandler);
  
  // Publishing - requires e-signature per 21 CFR Part 11
  app.post('/v1/question-papers/:id/publish', withEsig(questionPaperPublishHandler));
}
