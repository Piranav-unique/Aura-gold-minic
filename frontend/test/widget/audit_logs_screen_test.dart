import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/audit_logs/presentation/audit_logs_screen.dart';
import 'package:ags_gold/features/audit_logs/presentation/providers/audit_logs_provider.dart';
import 'package:ags_gold/features/audit_logs/domain/audit_log.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

void main() {
  testWidgets('AuditLogsScreen shows empty state', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/audit-logs',
      routes: [
        GoRoute(
          path: '/audit-logs',
          builder: (context, state) => const AuditLogsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          auditLogsListProvider.overrideWithValue(
            const AsyncValue.data(
              PaginatedAuditLogs(items: [], total: 0, skip: 0, limit: 25),
            ),
          ),
          unreadNotificationsCountProvider.overrideWithValue(const AsyncValue.data(0)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No audit events yet'), findsOneWidget);
  });
}
