import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ags_gold/features/app_update/domain/android_app_release.dart';
import 'package:ags_gold/features/app_update/domain/app_update_utils.dart';
import 'package:ags_gold/features/app_update/presentation/providers/app_update_provider.dart';
import 'package:ags_gold/features/app_update/presentation/widgets/app_update_prompt.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class AppUpdateCoordinator {
  AppUpdateCoordinator(this._ref);

  final Ref _ref;
  bool _promptVisible = false;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<void> checkAndPrompt(
    BuildContext context, {
    bool manual = false,
  }) async {
    if (!isSupported || !context.mounted) return;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final release = await _ref
          .read(appUpdateRepositoryProvider)
          .fetchAndroidRelease();

      if (!context.mounted) return;

      if (release == null) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.appUpdateNotConfigured)),
          );
        }
        return;
      }

      final updateAvailable = isAppUpdateAvailable(
        currentVersionCode: currentCode,
        remoteVersionCode: release.versionCode,
      );

      if (!updateAvailable) {
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.appUpdateUpToDate)),
          );
        }
        return;
      }

      if (_promptVisible) return;
      _promptVisible = true;

      final accepted = await showAppUpdatePrompt(
        context: context,
        release: release,
        currentVersionName: packageInfo.version,
      );

      _promptVisible = false;
      if (!accepted || !context.mounted) return;

      await _downloadAndInstall(context, release);
    } catch (_) {
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.appUpdateFailed)),
        );
      }
    }
  }

  Future<void> _downloadAndInstall(
    BuildContext context,
    AndroidAppRelease release,
  ) async {
    final targetUrl = release.apkUrl.trim();
    final uri = (targetUrl.isNotEmpty && targetUrl.startsWith('http'))
        ? Uri.parse(targetUrl)
        : Uri.parse('https://play.google.com/store/apps/details?id=com.agsgold.ags_gold');

    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        final fallback = Uri.parse('https://play.google.com/store/apps/details?id=com.agsgold.ags_gold');
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.appUpdateFailed)),
        );
      }
    }
  }
}

final appUpdateCoordinatorProvider = Provider<AppUpdateCoordinator>((ref) {
  return AppUpdateCoordinator(ref);
});
