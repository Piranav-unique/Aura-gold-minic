import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/transactions/domain/transaction.dart';
import 'package:ags_gold/features/transactions/presentation/providers/transactions_provider.dart';
import 'package:ags_gold/features/transactions/presentation/transactions_screen.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

final _adminProfile = UserProfile(
  id: '11111111-1111-1111-1111-111111111111',
  mobileNumber: '9876543210',
  firstName: 'Admin',
  lastName: 'User',
  isActive: true,
  isSuperuser: true,
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

void main() {
  final sample = Transaction(
    id: '11111111-1111-1111-1111-111111111111',
    transactionNumber: 'TXN-20260608-0001',
    transactionType: 'sale',
    status: 'active',
    paymentStatus: 'paid',
    subtotal: 1000,
    taxAmount: 0,
    totalAmount: 1000,
    stockApplied: true,
    createdAt: DateTime.parse('2026-06-08T10:00:00Z'),
    updatedAt: DateTime.parse('2026-06-08T10:00:00Z'),
  );

  testWidgets('TransactionsScreen shows list data', (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(
      initialLocation: '/transactions',
      routes: [
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          transactionsListProvider.overrideWithValue(
            AsyncValue.data(
              PaginatedTransactions(
                items: [sample],
                total: 1,
                skip: 0,
                limit: 25,
              ),
            ),
          )
          profileProvider.overrideWithValue(AsyncValue.data(_adminProfile)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TXN-20260608-0001'), findsOneWidget);
    expect(find.text('Sale'), findsOneWidget);
    expect(find.text('New Transaction'), findsOneWidget);
  });
}
