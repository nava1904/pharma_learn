import 'package:relic/relic.dart';

import 'question_banks_handler.dart';

void mountQuestionBankRoutes(RelicApp app) {
  // Question banks
  app.get('/v1/question-banks', questionBanksListHandler);
  app.get('/v1/question-banks/:id', questionBankGetHandler);
  app.post('/v1/question-banks', questionBankCreateHandler);
  app.patch('/v1/question-banks/:id', questionBankUpdateHandler);
  app.delete('/v1/question-banks/:id', questionBankDeleteHandler);
  
  // Questions within a bank
  app.post('/v1/question-banks/:id/questions', questionCreateHandler);
  
  // Individual question operations
  app.patch('/v1/questions/:id', questionUpdateHandler);
  app.delete('/v1/questions/:id', questionDeleteHandler);
}
