import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client_provider.dart';

/// UC-01, part 2: called once the user has confirmed their email and
/// logged in, but has no `profiles` row yet. Calls the
/// `handle_new_business_signup` Postgres function (Module 7 companion),
/// which atomically creates the business, owner profile, and 30-day
/// trial subscription — all scoped to `auth.uid()` server-side, so the
/// client can never create a business on someone else's behalf.
class BusinessSetupRepository {
  BusinessSetupRepository(this._client);
  final SupabaseClient _client;

  Future<void> completeSetup({
    required String businessName,
    required String fullName,
  }) async {
    await _client.rpc('handle_new_business_signup', params: {
      'business_name': businessName,
      'owner_full_name': fullName,
    });
  }
}

final businessSetupRepositoryProvider = Provider<BusinessSetupRepository>((ref) {
  return BusinessSetupRepository(ref.watch(supabaseClientProvider));
});