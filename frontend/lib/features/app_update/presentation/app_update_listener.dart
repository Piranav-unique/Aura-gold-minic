import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/app_update/services/app_update_coordinator.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
import 'package:ags_gold/routes/app_routes.dart';

/// Checks for APK updates on Android startup and shows an in-app prompt.
class AppUpdateListener extends ConsumerStatefulWidget {
  const AppUpdateListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateListener> createState() => _AppUpdateListenerState();
}

class _AppUpdateListenerState extends ConsumerState<AppUpdateListener> {
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  void _checkForUpdate() {
    if (_scheduled || !mounted) return;
    _scheduled = true;

    final localizedContext = rootNavigatorKey.currentContext;
    if (localizedContext == null ||
        AppLocalizations.of(localizedContext) == null) {
      return;
    }

    ref.read(appUpdateCoordinatorProvider).checkAndPrompt(localizedContext);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
