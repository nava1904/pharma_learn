import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'di.config.dart';

/// Global service locator instance.
final GetIt getIt = GetIt.instance;

/// Initializes dependency injection.
/// Call from main() before runApp().
@InjectableInit(preferRelativeImports: true)
Future<void> configureDependencies() async {
  getIt.init();
}

/// Module for registering Supabase client.
@module
abstract class SupabaseModule {
  @singleton
  SupabaseClient get supabase => Supabase.instance.client;
}

/// Module for registering external dependencies.
@module
abstract class ExternalModule {
  @singleton
  Connectivity get connectivity => Connectivity();

  @singleton
  FlutterSecureStorage get secureStorage => const FlutterSecureStorage();
}
