import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/profile/presentation/profile_dialogs.dart';
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
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showEditProfileDialog(
                    context,
                    ProviderScope.containerOf(context),
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

    final textField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    final decoration = textField.decoration as InputDecoration;

    expect(
      decoration.fillColor,
      AppTheme.darkTheme.colorScheme.surfaceContainerHighest,
    );
    expect(decoration.fillColor, isNot(AppTheme.creamElevated));
  });
}
