import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/notifications/presentation/notification_drawer.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:ags_gold/features/notifications/domain/notification.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

void main() {
  testWidgets('NotificationDrawer shows notifications and mark all read',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          notificationsListProvider.overrideWithValue(
            AsyncValue.data(
              NotificationListResult(
                items: [
                  AppNotification(
                    id: '11111111-1111-1111-1111-111111111111',
                    userId: '22222222-2222-2222-2222-222222222222',
                    title: 'Security alert',
                    message: 'New login',
                    category: 'security',
                    isRead: false,
                    createdAt: DateTime(2026, 6, 8),
                  ),
                ],
                total: 1,
                unreadCount: 1,
                skip: 0,
                limit: 50,
              ),
            ),
          ),
          markNotificationsReadProvider.overrideWithValue(
            ({List<String>? ids, bool markAll = false}) async {},
          ),
        ],
        child: const MaterialApp(home: Scaffold(endDrawer: NotificationDrawer())),
      ),
    );

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openEndDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Security alert'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });
}
