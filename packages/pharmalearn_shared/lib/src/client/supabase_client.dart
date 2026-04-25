import 'dart:io';

import 'package:supabase/supabase.dart';

/// Singleton accessor for the Supabase service-role client.
///
/// The client is initialised lazily from the environment variables
/// `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.  Both variables must be
/// set before the first access or an assertion will throw.
class SupabaseService {
  SupabaseService._();

  static SupabaseClient? _instance;

  /// Returns the shared [SupabaseClient], creating it on first access.
  static SupabaseClient get client {
    if (_instance == null) {
      final url = Platform.environment['SUPABASE_URL'];
      final key = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

      assert(
        url != null && url.isNotEmpty,
        'SUPABASE_URL environment variable is not set.',
      );
      assert(
        key != null && key.isNotEmpty,
        'SUPABASE_SERVICE_ROLE_KEY environment variable is not set.',
      );

      _instance = SupabaseClient(url!, key!);
    }
    return _instance!;
  }

  /// Replaces the singleton instance — useful in tests.
  // ignore: avoid_setters_without_getters
  static set instance(SupabaseClient client) => _instance = client;

  /// Resets the singleton — useful in tests.
  static void reset() => _instance = null;
}
