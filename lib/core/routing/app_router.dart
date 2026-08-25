import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/placeholder_home_screen.dart';
import '../auth/session_state.dart';

/// Phase 0 routing: proves Supabase auth state drives navigation correctly.
/// Real role-based routing (Owner vs Staff vs Super Admin landing screens)
/// is built out in Phase 1 once actual dashboards exist.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const PlaceholderHomeScreen()),
    ],
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.session != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      // Still resolving auth state on first load — stay on splash.
      if (authState.isLoading && isSplash) return null;

      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && (isLoggingIn || isSplash)) return '/home';

      return null;
    },
  );
});
