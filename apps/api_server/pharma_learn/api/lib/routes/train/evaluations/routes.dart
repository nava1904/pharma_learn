import 'package:relic/relic.dart';

import 'short_term_evaluation_handler.dart';
import 'long_term_evaluation_handler.dart';

void mountEvaluationRoutes(RelicApp app) {
  // Short-term evaluations (supervisor evaluates trainee ~1 month post-training)
  app
    ..post('/v1/train/batches/:id/short-term-evaluation', shortTermEvaluationCreateHandler)
    ..get('/v1/train/batches/:id/short-term-evaluation', shortTermEvaluationListHandler)
    ..get('/v1/train/batches/:id/short-term-evaluation/:employeeId', shortTermEvaluationDetailHandler);

  // Long-term evaluations (supervisor evaluates 3-6 months post-training)
  app
    ..post('/v1/train/batches/:id/long-term-evaluation', longTermEvaluationCreateHandler)
    ..get('/v1/train/batches/:id/long-term-evaluation', longTermEvaluationListHandler)
    ..get('/v1/train/batches/:id/long-term-evaluation/:employeeId', longTermEvaluationDetailHandler);
}
