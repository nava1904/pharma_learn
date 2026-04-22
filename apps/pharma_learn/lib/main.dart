import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/cache/offline_cache_service.dart';
import 'core/cache/offline_sync_service.dart';
import 'core/config/app_config.dart';
import 'core/di/di.dart';
import 'core/router/app_router.dart';
import 'stores/auth_store.dart';

/// PharmaLearn - 21 CFR Part 11 Compliant LMS
/// 
/// Sprint 9: Full MobX client implementation.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Hive for local storage
  await Hive.initFlutter();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.current.supabaseUrl,
    anonKey: AppConfig.current.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  
  // Initialize dependency injection
  await configureDependencies();
  
  // Initialize offline cache
  await getIt<OfflineCacheService>().initialize();
  
  // Start offline sync monitoring
  getIt<OfflineSyncService>().startMonitoring();
  
  // Restore auth session if available
  await getIt<AuthStore>().restoreSession();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  runApp(const PharmaLearnApp());
}

class PharmaLearnApp extends StatelessWidget {
  const PharmaLearnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PharmaLearn',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
  
  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // PharmaLearn brand colors
    const primaryColor = Color(0xFF1565C0); // Blue 800
    const secondaryColor = Color(0xFF00897B); // Teal 600
    
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        systemOverlayStyle: isDark 
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
