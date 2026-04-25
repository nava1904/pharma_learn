import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import 'documents_handler.dart';
import 'document_handler.dart';
import 'document_submit_handler.dart';
import 'document_approve_handler.dart';
import 'document_reject_handler.dart';
import 'document_versions_handler.dart';
import 'document_readings_handler.dart';
import 'document_reading_ack_handler.dart';
import 'document_integrity_handler.dart';

void mountDocumentRoutes(RelicApp app) {
  // Collection
  app
    ..get('/v1/documents', documentsListHandler)
    ..post('/v1/documents', documentsCreateHandler);

  // Single document
  app
    ..get('/v1/documents/:id', documentGetHandler)
    ..patch('/v1/documents/:id', documentPatchHandler)
    ..delete('/v1/documents/:id', documentDeleteHandler);

  // Workflow transitions
  app.post('/v1/documents/:id/submit', documentSubmitHandler);
  app.post('/v1/documents/:id/approve', withEsig(documentApproveHandler));
  app.post('/v1/documents/:id/reject', withEsig(documentRejectHandler));

  // Versions
  app.get('/v1/documents/:id/versions', documentVersionsHandler);

  // Readings
  app
    ..get('/v1/documents/:id/readings', documentReadingsListHandler)
    ..post('/v1/documents/:id/readings', documentReadingsCreateHandler);
  app.post('/v1/documents/:id/readings/:readingId/acknowledge', withEsig(documentReadingAckHandler));

  // Integrity verification
  app.get('/v1/documents/:id/integrity', documentIntegrityHandler);
}
