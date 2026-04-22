import 'package:flutter/foundation.dart';

/// Environment configuration for different build profiles.
enum Environment { dev, staging, prod }

/// Application configuration loaded from environment.
class AppConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String apiBaseUrl;
  final Environment environment;
  
  const AppConfig._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.apiBaseUrl,
    required this.environment,
  });
  
  /// Development configuration
  static const dev = AppConfig._(
    supabaseUrl: 'http://localhost:54321',
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    apiBaseUrl: 'http://localhost:8080',
    environment: Environment.dev,
  );
  
  /// Staging configuration
  static const staging = AppConfig._(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
    environment: Environment.staging,
  );
  
  /// Production configuration
  static const prod = AppConfig._(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
    environment: Environment.prod,
  );
  
  /// Gets configuration for current build profile.
  static AppConfig get current {
    if (kReleaseMode) {
      return prod;
    } else if (const String.fromEnvironment('ENVIRONMENT') == 'staging') {
      return staging;
    }
    return dev;
  }
  
  bool get isDev => environment == Environment.dev;
  bool get isStaging => environment == Environment.staging;
  bool get isProd => environment == Environment.prod;
}
