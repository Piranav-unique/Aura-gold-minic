import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/profile/presentation/profile_dialogs.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('profile edit dialog uses dark theme surface colors for inputs', (
    WidgetTester tester,
  ) async {
    final profile = UserProfile(
      id: 'user-1',
      firstName: 'Nathan',
      lastName: 'Gerald',
      mobileNumber: '+1234567890',
      isActive: true,
      isSuperuser: false,
      createdAt: DateTime.utc(2024, 1, 1),
      updatedAt: DateTime.utc(2024, 1, 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () => showEditProfileDialog(
                    context,
                    ref,
                    profile,
                  ),
                  child: const Text('Open dialog'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    final textField = tester.widget<TextField>(
      find.byType(TextField).first,
    );
    final decoration = textField.decoration;

    expect(
      decoration?.fillColor,
      AppTheme.darkTheme.colorScheme.surfaceContainerHighest,
    );
    expect(decoration?.fillColor, isNot(AppTheme.creamElevated));
  });
}
