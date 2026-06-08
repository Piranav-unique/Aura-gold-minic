import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/main.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/dashboard_stats_provider.dart';
import 'package:ags_gold/features/dashboard/domain/dashboard_stats.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import '../mocks/mock_services.dart';

final _mockDashboardStats = DashboardStats(
  recentActivity: const [],
  unreadNotifications: 0,
  securityAlerts: const [],
  recentNotifications: const [],
  loginStatistics: const LoginStatistics(today: 0, week: 0, month: 0),
);

Future<void> pumpE2eApp(
  WidgetTester tester, {
  required MockApiClient mockApi,
  required MockSecureStorage mockStorage,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final mockMapResponse = MockResponse<Map<String, dynamic>>();
  when(() => mockMapResponse.data).thenReturn({
    'items': [],
    'total': 0,
    'skip': 0,
    'limit': 10,
  });

  final mockListResponse = MockResponse<List<dynamic>>();
  when(() => mockListResponse.data).thenReturn([]);

  when(
    () => mockApi.get(
      any(),
      queryParameters: any(named: 'queryParameters'),
      options: any(named: 'options'),
      cancelToken: any(named: 'cancelToken'),
    ),
  ).thenAnswer((invocation) async {
    final path = invocation.positionalArguments[0] as String;
    if (path.contains('audit-logs') || path.contains('dashboard/stats')) {
      if (path.contains('dashboard/stats')) {
        final statsResponse = MockResponse<Map<String, dynamic>>();
        when(() => statsResponse.data).thenReturn({
          'recent_activity': [],
          'unread_notifications': 0,
          'security_alerts': [],
          'recent_notifications': [],
          'login_statistics': {'today': 0, 'week': 0, 'month': 0},
        });
        return statsResponse;
      }
      return mockMapResponse;
    }
    return mockListResponse;
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(mockApi),
        secureStorageProvider.overrideWithValue(mockStorage),
        dashboardStatsProvider.overrideWithValue(AsyncValue.data(_mockDashboardStats)),
        auditLogsProvider.overrideWithValue(const AsyncValue.data([])),
        unreadNotificationsCountProvider.overrideWithValue(const AsyncValue.data(0)),
      ],
      child: const AGSGoldApp(),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

Future<void> completeLogin(
  WidgetTester tester,
  MockApiClient mockApi,
  MockSecureStorage mockStorage, {
  String email = 'admin@e2e.test',
  String password = 'Password123',
}) async {
  final loginCompleter = Completer<MockResponse<Map<String, dynamic>>>();
  final mockLoginResponse = MockResponse<Map<String, dynamic>>();
  when(() => mockLoginResponse.data).thenReturn({
    'access_token': 'e2e-access-token',
    'refresh_token': 'e2e-refresh-token',
  });
  when(() => mockApi.post('/auth/login', data: any(named: 'data')))
      .thenAnswer((_) => loginCompleter.future);
  when(
    () => mockStorage.saveTokens(
      accessToken: any(named: 'accessToken'),
      refreshToken: any(named: 'refreshToken'),
    ),
  ).thenAnswer((_) async {});

  await tester.enterText(find.byKey(const Key('emailField')), email);
  await tester.enterText(find.byKey(const Key('passwordField')), password);
  await tester.tap(find.byKey(const Key('loginButton')));
  loginCompleter.complete(mockLoginResponse);
  await tester.pumpAndSettle();
}
