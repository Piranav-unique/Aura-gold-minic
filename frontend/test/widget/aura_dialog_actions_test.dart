import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/aura_dialog_actions.dart';
import 'package:ags_gold/l10n/app_localizations.dart';

void main() {
  testWidgets('AuraDialogActions renders cancel and confirm buttons with equal width and height', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: const Text('Confirm Action'),
                    content: const Text('Are you sure you want to proceed?'),
                    actions: [
                      AuraDialogActions.buttons(
                        context: dialogCtx,
                        cancelLabel: 'Cancel',
                        onCancel: () => Navigator.pop(dialogCtx),
                        confirmLabel: 'Confirm',
                        onConfirm: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final cancelFinder = find.widgetWithText(OutlinedButton, 'Cancel');
    final confirmFinder = find.widgetWithText(FilledButton, 'Confirm');

    expect(cancelFinder, findsOneWidget);
    expect(confirmFinder, findsOneWidget);

    final cancelSize = tester.getSize(cancelFinder);
    final confirmSize = tester.getSize(confirmFinder);

    // Both buttons MUST have equal width (length)
    expect(cancelSize.width, equals(confirmSize.width));
    // Both buttons MUST have equal height
    expect(cancelSize.height, equals(confirmSize.height));

    // Confirm buttons are placed side-by-side horizontally
    final cancelTopLeft = tester.getTopLeft(cancelFinder);
    final confirmTopLeft = tester.getTopLeft(confirmFinder);

    expect(cancelTopLeft.dy, equals(confirmTopLeft.dy));
    expect(cancelTopLeft.dx, lessThan(confirmTopLeft.dx));
  });
}
