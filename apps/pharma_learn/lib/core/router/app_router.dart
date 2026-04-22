import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../stores/auth_store.dart';
import '../di/di.dart';

// Screen imports (to be created)
// import '../screens/auth/login_screen.dart';
// import '../screens/auth/mfa_screen.dart';
// import '../screens/induction/induction_screen.dart';
// import '../screens/dashboard/dashboard_screen.dart';
// import '../screens/training/training_screen.dart';
// import '../screens/assessment/assessment_screen.dart';
// import '../screens/compliance/compliance_screen.dart';

/// App router with authentication and induction gates.
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  debugLogDiagnostics: true,
  redirect: _globalRedirect,
  routes: [
    // ---------------------------------------------------------------------------
    // PUBLIC ROUTES
    // ---------------------------------------------------------------------------
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const _PlaceholderScreen(title: 'Splash'),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const _PlaceholderScreen(title: 'Login'),
    ),
    GoRoute(
      path: '/mfa',
      name: 'mfa',
      builder: (context, state) => const _PlaceholderScreen(title: 'MFA'),
    ),
    
    // ---------------------------------------------------------------------------
    // INDUCTION ROUTE (authenticated but not inducted)
    // ---------------------------------------------------------------------------
    GoRoute(
      path: '/induction',
      name: 'induction',
      builder: (context, state) => const _PlaceholderScreen(title: 'Induction'),
    ),
    
    // ---------------------------------------------------------------------------
    // MAIN APP SHELL (authenticated + inducted)
    // ---------------------------------------------------------------------------
    ShellRoute(
      builder: (context, state, child) {
        return _AppShell(child: child);
      },
      routes: [
        // Dashboard
        GoRoute(
          path: '/',
          name: 'dashboard',
          builder: (context, state) => const _PlaceholderScreen(title: 'Dashboard'),
        ),
        
        // Training
        GoRoute(
          path: '/training',
          name: 'training',
          builder: (context, state) => const _PlaceholderScreen(title: 'Training'),
          routes: [
            GoRoute(
              path: 'sessions/:id',
              name: 'session-detail',
              builder: (context, state) => _PlaceholderScreen(
                title: 'Session ${state.pathParameters['id']}',
              ),
            ),
            GoRoute(
              path: 'obligations/:id',
              name: 'obligation-detail',
              builder: (context, state) => _PlaceholderScreen(
                title: 'Obligation ${state.pathParameters['id']}',
              ),
            ),
          ],
        ),
        
        // Assessments
        GoRoute(
          path: '/assessments',
          name: 'assessments',
          builder: (context, state) => const _PlaceholderScreen(title: 'Assessments'),
          routes: [
            GoRoute(
              path: ':id',
              name: 'assessment-detail',
              builder: (context, state) => _PlaceholderScreen(
                title: 'Assessment ${state.pathParameters['id']}',
              ),
            ),
            GoRoute(
              path: ':id/attempt',
              name: 'assessment-attempt',
              builder: (context, state) => _PlaceholderScreen(
                title: 'Taking Assessment',
              ),
            ),
          ],
        ),
        
        // SCORM Player
        GoRoute(
          path: '/scorm/:packageId',
          name: 'scorm-player',
          builder: (context, state) => _PlaceholderScreen(
            title: 'SCORM Player',
          ),
        ),
        
        // Compliance Dashboard
        GoRoute(
          path: '/compliance',
          name: 'compliance',
          builder: (context, state) => const _PlaceholderScreen(title: 'Compliance'),
        ),
        
        // Certificates
        GoRoute(
          path: '/certificates',
          name: 'certificates',
          builder: (context, state) => const _PlaceholderScreen(title: 'Certificates'),
          routes: [
            GoRoute(
              path: ':id',
              name: 'certificate-detail',
              builder: (context, state) => _PlaceholderScreen(
                title: 'Certificate ${state.pathParameters['id']}',
              ),
            ),
          ],
        ),
        
        // Settings
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (context, state) => const _PlaceholderScreen(title: 'Settings'),
        ),
      ],
    ),
    
    // ---------------------------------------------------------------------------
    // CERTIFICATE VERIFICATION (public)
    // ---------------------------------------------------------------------------
    GoRoute(
      path: '/verify/:code',
      name: 'verify-certificate',
      builder: (context, state) => _PlaceholderScreen(
        title: 'Verify Certificate ${state.pathParameters['code']}',
      ),
    ),
  ],
);

/// Global redirect logic for auth and induction gates.
String? _globalRedirect(BuildContext context, GoRouterState state) {
  final authStore = getIt<AuthStore>();
  final isAuthenticated = authStore.isAuthenticated;
  final isInducted = authStore.isInductionCompleted;
  final path = state.matchedLocation;
  
  // Public routes - no redirect needed
  final publicRoutes = ['/splash', '/login', '/mfa', '/verify'];
  if (publicRoutes.any((r) => path.startsWith(r))) {
    // If authenticated, redirect away from login
    if (isAuthenticated && path == '/login') {
      return isInducted ? '/' : '/induction';
    }
    return null;
  }
  
  // Not authenticated - redirect to login
  if (!isAuthenticated) {
    return '/login';
  }
  
  // Authenticated but not inducted - redirect to induction
  // (except for induction page itself)
  if (!isInducted && path != '/induction') {
    return '/induction';
  }
  
  // Inducted user trying to access induction page - redirect to dashboard
  if (isInducted && path == '/induction') {
    return '/';
  }
  
  return null;
}

/// Main app shell with bottom navigation.
class _AppShell extends StatefulWidget {
  final Widget child;
  
  const _AppShell({required this.child});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  int _selectedIndex = 0;
  
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school),
      label: 'Training',
    ),
    NavigationDestination(
      icon: Icon(Icons.quiz_outlined),
      selectedIcon: Icon(Icons.quiz),
      label: 'Assessments',
    ),
    NavigationDestination(
      icon: Icon(Icons.verified_outlined),
      selectedIcon: Icon(Icons.verified),
      label: 'Certificates',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];
  
  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0: context.go('/');
      case 1: context.go('/training');
      case 2: context.go('/assessments');
      case 3: context.go('/certificates');
      case 4: context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: _destinations,
      ),
    );
  }
}

/// Placeholder screen for routes not yet implemented.
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  
  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text('Coming soon...'),
          ],
        ),
      ),
    );
  }
}
