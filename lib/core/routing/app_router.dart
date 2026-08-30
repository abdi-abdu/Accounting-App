import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/presentation/screens/business_setup_screen.dart';
import '../../features/onboarding/presentation/screens/login_screen.dart';
import '../../features/onboarding/presentation/screens/signup_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/dashboard/presentation/screens/placeholder_home_screen.dart';
import '../auth/session_state.dart';

/// Phase 1 routing: adds sign-up (UC-01 part 1) and business setup
/// (UC-01 part 2) to the Phase 0 auth-only flow. Real role-based routing
/// (Owner vs Staff vs Super Admin landing screens) still comes later,
/// once actual dashboards exist.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final profileAsync = ref.watch(currentProfileProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignUpScreen()),
      GoRoute(path: '/business-setup', builder: (context, state) => const BusinessSetupScreen()),
      GoRoute(path: '/home', builder: (context, state) => const PlaceholderHomeScreen()),
    ],
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull?.session != null;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/signup';
      final isSplash = loc == '/splash';
      final isBusinessSetup = loc == '/business-setup';

      // Still resolving auth state on first load — stay on splash.
      if (authState.isLoading && isSplash) return null;

      if (!isLoggedIn) {
        return isAuthRoute ? null : '/login';
      }

      // Logged in from here — wait for the profile lookup before deciding,
      // to avoid a flash-redirect to business-setup while it's still loading.
      if (profileAsync.isLoading) return null;

      final hasProfile = profileAsync.valueOrNull != null;
      if (!hasProfile) {
        return isBusinessSetup ? null : '/business-setup';
      }

      // Has a profile already — keep them out of auth/setup screens.
      if (isAuthRoute || isBusinessSetup || isSplash) return '/home';

      return null;
    },
  );
});