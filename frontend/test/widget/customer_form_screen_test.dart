import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/customers/presentation/customer_form_screen.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

void main() {
  testWidgets('CustomerFormScreen shows create form fields', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/customers/new',
      routes: [
        GoRoute(
          path: '/customers/new',
          builder: (context, state) => const CustomerFormScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          unreadNotificationsCountProvider.overrideWithValue(
            const AsyncValue.data(0),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Create Customer'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Mobile Number'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('GST Number (Optional)'), findsOneWidget);
  });
}
