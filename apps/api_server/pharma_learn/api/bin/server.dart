import 'dart:io';

import 'package:relic/io_adapter.dart'; // RelicAppIOServeEx.serve() extension
import 'package:pharma_learn_api/pharma_learn_api.dart';

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final app = createApp();
  await app.serve(
    address: InternetAddress.anyIPv4,
    port: port,
  );
  print('PharmaLearn API running on http://0.0.0.0:$port');
  print('Health: http://0.0.0.0:$port/health');
}
