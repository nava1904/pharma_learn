import 'package:relic/relic.dart';

import 'categories_handler.dart';

void mountCategoryRoutes(RelicApp app) {
  app.get('/v1/categories', categoriesListHandler);
  app.get('/v1/categories/:id', categoryGetHandler);
  app.post('/v1/categories', categoryCreateHandler);
  app.patch('/v1/categories/:id', categoryUpdateHandler);
  app.delete('/v1/categories/:id', categoryDeleteHandler);
}
