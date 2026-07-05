import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/app_theme.dart';

/// Session flag so the KYC reminder pops up at most once per app run.
class KycPromptShownNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markShown() => state = true;
}

final kycPromptShownProvider =
    NotifierProvider<KycPromptShownNotifier, bool>(KycPromptShownNotifier.new);

/// Shows the "complete your KYC" popup once per session for unverified users.
///
/// Call from the home screen after the dashboard has loaded. Does nothing when
/// the user is already verified or the popup has already been shown this session.
void maybeShowKycPrompt(
  BuildContext context,
  WidgetRef ref, {
  required bool verified,
}) {
  if (verified) return;
  if (ref.read(kycPromptShownProvider)) return;

  // Defer state mutation and dialog to after the current build/frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    if (ref.read(kycPromptShownProvider)) return;
    ref.read(kycPromptShownProvider.notifier).markShown();
    showDialog<void>(
      context: context,
      builder: (_) => const _KycPromptDialog(),
    );
  });
}

class _KycPromptDialog extends StatelessWidget {
  const _KycPromptDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: AppTheme.goldGradient,
          shape: BoxShape.circle,
          boxShadow: AppTheme.goldGlowShadow,
        ),
        child: const Icon(
          Icons.verified_user_outlined,
          color: AppTheme.ink,
          size: 30,
        ),
      ),
      title: const Text(
        'Verify your identity',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: const Text(
        'Complete your KYC to unlock buying and selling gold & silver. '
        'It only takes a couple of minutes.',
        textAlign: TextAlign.center,
        style: TextStyle(height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/kyc');
          },
          child: const Text('Verify now'),
        ),
      ],
    );
  }
}
