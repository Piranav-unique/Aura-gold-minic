import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/settings/presentation/settings_screen.dart';
import 'package:ags_gold/features/settings/presentation/providers/settings_provider.dart';
import 'package:ags_gold/features/settings/domain/user_settings.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

void main() {
  testWidgets('SettingsScreen renders sections', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          userSettingsProvider.overrideWithValue(
            const AsyncValue.data(UserSettings()),
          ),
          unreadNotificationsCountProvider.overrideWithValue(
            const AsyncValue.data(0),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Theme Settings'), findsOneWidget);
    expect(find.text('Notification Settings'), findsOneWidget);
    expect(find.text('Security Settings'), findsOneWidget);
    expect(find.text('Language Settings'), findsOneWidget);
    expect(find.text('Account Settings'), findsOneWidget);
  });
}
