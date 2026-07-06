import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/navigation/app_navigation_utils.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

Future<bool> confirmAppExit(BuildContext context) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.exitAppConfirmTitle),
      content: Text(l10n.exitAppConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.no),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.yes),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> requestAppExit(BuildContext context) async {
  if (await confirmAppExit(context) && context.mounted) {
    SystemNavigator.pop();
  }
}

/// Shows an exit confirmation when the user presses back on a root route.
class AppExitGuard extends StatelessWidget {
  final Widget child;

  const AppExitGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final currentPath = GoRouterState.of(context).matchedLocation;

        if (context.canPop()) {
          context.pop();
          return;
        }

        final parent = parentRouteFor(currentPath);
        if (parent != null) {
          context.go(parent);
          return;
        }

        await requestAppExit(context);
      },
      child: child,
    );
  }
}
