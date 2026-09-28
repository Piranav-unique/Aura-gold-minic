import 'package:flutter/material.dart';
import 'package:ags_gold/core/widgets/aura_dialog_actions.dart';
import 'package:ags_gold/features/app_update/domain/android_app_release.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

Future<bool> showAppUpdatePrompt({
  required BuildContext context,
  required AndroidAppRelease release,
  required String currentVersionName,
}) {
  final l10n = context.l10n;

  return showDialog<bool>(
        context: context,
        barrierDismissible: !release.forceUpdate,
        builder: (dialogContext) {
          return PopScope(
            canPop: !release.forceUpdate,
            child: AlertDialog(
              title: Text(l10n.appUpdateAvailableTitle),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.appUpdateAvailableMessage(
                        release.versionName,
                        currentVersionName,
                      ),
                    ),
                    if (release.releaseNotes.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        l10n.appUpdateReleaseNotes,
                        style: Theme.of(dialogContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(release.releaseNotes.trim()),
                    ],
                  ],
                ),
              ),
              actions: [
                AuraDialogActions.buttons(
                  context: dialogContext,
                  cancelLabel:
                      release.forceUpdate ? null : l10n.appUpdateLater,
                  onCancel: release.forceUpdate
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  confirmLabel: l10n.appUpdateNow,
                  onConfirm: () => Navigator.pop(dialogContext, true),
                ),
              ],
            ),
          );
        },
      )
      .then((value) => value ?? false);
}

Future<void> showAppUpdateProgressSheet({
  required BuildContext context,
  required ValueNotifier<double?> progress,
}) {
  final l10n = context.l10n;

  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (context, value, _) {
              final percent = ((value ?? 0).clamp(0, 100)) / 100;
              final isInstalling = value != null && value >= 100;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isInstalling
                        ? l10n.appUpdateInstalling
                        : l10n.appUpdateDownloading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: isInstalling ? null : percent),
                  if (!isInstalling && value != null) ...[
                    const SizedBox(height: 8),
                    Text('${value.round()}%'),
                  ],
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
