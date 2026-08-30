import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../network/supabase_client_provider.dart';

/// Thin wrapper around Supabase Auth.
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Future<AuthResponse> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// UC-01, part 1: creates the auth user. Supabase sends a confirmation
  /// email automatically (default project setting). No `businesses` or
  /// `profiles` row exists yet — that happens after the person confirms
  /// their email and logs in, via BusinessSetupRepository.
  Future<AuthResponse> signUp({required String email, required String password}) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});