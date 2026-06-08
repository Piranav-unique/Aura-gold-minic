import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/settings/presentation/settings_screen.dart';
import 'package:ags_gold/features/profile/presentation/profile_screen.dart';
import 'package:ags_gold/features/settings/presentation/providers/settings_provider.dart';
import 'package:ags_gold/features/settings/domain/user_settings.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

void main() {
  testWidgets('Profile and settings screens load with mocked data',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
      initialLocation: '/settings',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          userSettingsProvider.overrideWithValue(const AsyncValue.data(UserSettings())),
          profileProvider.overrideWithValue(
            AsyncValue.data(
              UserProfile(
                id: '11111111-1111-1111-1111-111111111111',
                email: 'user@example.com',
                firstName: 'Test',
                lastName: 'User',
                isActive: true,
                isSuperuser: false,
                createdAt: DateTime(2026, 1, 1),
                updatedAt: DateTime(2026, 1, 1),
              ),
            ),
          ),
          profileActivityProvider.overrideWithValue(const AsyncValue.data([])),
          unreadNotificationsCountProvider.overrideWithValue(const AsyncValue.data(0)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Theme Settings'), findsOneWidget);

    router.go('/profile');
    await tester.pumpAndSettle();
    expect(find.text('user@example.com'), findsOneWidget);
  });
}
