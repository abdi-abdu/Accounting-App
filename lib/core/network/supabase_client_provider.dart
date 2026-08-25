import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the single Supabase client instance to the rest of the app.
/// Supabase.initialize() is called once in main.dart before ProviderScope
/// is built, so this provider simply exposes the already-initialized client.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
