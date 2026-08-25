import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared_models/user_role.dart';
import '../network/supabase_client_provider.dart';
import 'auth_repository.dart';

/// Streams raw Supabase auth state (signed in / signed out / token refreshed).
/// The router (core/routing/app_router.dart) watches this to redirect
/// between the login and home flows.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// A minimal read model for "who is logged in and what can they do" —
/// role and business_id come from the `profiles` table, which itself
/// mirrors the JWT claims set by the custom_access_token_hook (Module 7 §9).
class CurrentProfile {
  const CurrentProfile({
    required this.id,
    required this.businessId,
    required this.role,
    required this.fullName,
  });

  final String id;
  final String? businessId; // null only for super_admin
  final UserRole role;
  final String fullName;
}

/// Fetches the current user's profile row. Returns null if signed out.
/// Re-fetches whenever auth state changes.
final currentProfileProvider = FutureProvider<CurrentProfile?>((ref) async {
  ref.watch(authStateProvider);
  final client = ref.watch(supabaseClientProvider);
  final user = client.auth.currentUser;

  if (user == null) return null;

  final row = await client.from('profiles').select().eq('id', user.id).single();

  return CurrentProfile(
    id: row['id'] as String,
    businessId: row['business_id'] as String?,
    role: UserRole.fromString(row['role'] as String),
    fullName: row['full_name'] as String,
  );
});
