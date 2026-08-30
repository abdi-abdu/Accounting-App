import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/session_state.dart';
import '../../../../core/localization/app_l10n_provider.dart';
import '../../data/business_setup_repository.dart';

/// UC-01, part 2: shown when someone is logged in but has no `profiles`
/// row yet (router sends them here automatically — see app_router.dart).
/// On success, invalidates currentProfileProvider so the router's redirect
/// logic re-evaluates and sends them to /home on its own.
class BusinessSetupScreen extends ConsumerStatefulWidget {
  const BusinessSetupScreen({super.key});

  @override
  ConsumerState<BusinessSetupScreen> createState() => _BusinessSetupScreenState();
}

class _BusinessSetupScreenState extends ConsumerState<BusinessSetupScreen> {
  final _businessNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(businessSetupRepositoryProvider).completeSetup(
            businessName: _businessNameController.text.trim(),
            fullName: _fullNameController.text.trim(),
          );
      ref.invalidate(currentProfileProvider);
      // No manual navigation — the router's redirect logic (app_router.dart)
      // watches currentProfileProvider and will send them to /home once
      // this resolves to a non-null profile.
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(appL10nProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.businessSetupTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _businessNameController,
              decoration: InputDecoration(labelText: l10n.businessNameLabel),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _fullNameController,
              decoration: InputDecoration(labelText: l10n.fullNameLabel),
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[
              Text(l10n.setupFailed(_error!), style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.completeSetupButton),
            ),
          ],
        ),
      ),
    );
  }
}