import 'package:relic/relic.dart';
import 'package:supabase/supabase.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

// ---------------------------------------------------------------------------
// Supabase Context Middleware
// ---------------------------------------------------------------------------
// Injects the service-role SupabaseClient into the request context.
// This ensures all handlers have access to the database client.
// ---------------------------------------------------------------------------

/// Middleware that provides [SupabaseClient] access to all routes.
/// 
/// The client is injected into the Zone-based [RequestContext] and can be
/// accessed via `RequestContext.supabase` or the `req.supabase` extension.
/// 
/// Uses service role for admin operations. For user-scoped RLS operations,
/// use [SupabaseUserClientFactory] with the user's JWT.
Middleware supabaseProviderMiddleware() {
  return (handler) {
    return (request) async {
      // Use the singleton service-role client from SupabaseService
      final client = SupabaseService.client;
      
      // Run the handler with the client in the zone
      return await RequestContext.withSupabase(client, () async => handler(request));
    };
  };
}

/// Creates a user-scoped Supabase client with RLS enforcement.
/// 
/// Use this when you need RLS policies to be enforced based on the
/// authenticated user's JWT token.
/// 
/// Example:
/// ```dart
/// final userClient = createUserScopedClient(req);
/// final myData = await userClient.from('my_table').select(); // RLS applied
/// ```
SupabaseClient createUserScopedClient(Request req) {
  // Extract the Authorization header
  final authHeader = req.headers['authorization']?.firstOrNull;
  if (authHeader == null || !authHeader.startsWith('Bearer ')) {
    throw StateError('No Bearer token in Authorization header');
  }
  
  final token = authHeader.substring(7); // Remove 'Bearer ' prefix
  
  // Create a user-scoped client
  final factory = SupabaseUserClientFactory.fromEnvironment();
  return factory.forToken(token).client;
}

/// Helper to check if a request has a valid Supabase context.
bool hasSupabaseContext() {
  try {
    RequestContext.supabase;
    return true;
  } catch (_) {
    return false;
  }
}
