import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/workflows/domain/workflow.dart';
import 'package:ags_gold/features/workflows/presentation/providers/workflows_provider.dart';
import 'package:ags_gold/features/workflows/presentation/workflows_screen.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

UserProfile _profileWithPermissions(List<String> permissions) {
  return UserProfile(
    id: 'user-1',
    mobileNumber: '9876543210',
    isActive: true,
    isSuperuser: false,
    roles: [
      UserRole(
        id: 'role-1',
        name: 'Tester',
        permissions: permissions
            .map((p) => UserPermission(id: p, name: p))
            .toList(),
      ),
    ],
    hasAvatar: false,
    createdAt: DateTime.utc(2026, 6, 8),
    updatedAt: DateTime.utc(2026, 6, 8),
  );
}

void main() {
  testWidgets('workflows screen shows list when data loads', (tester) async {
    tester.view.physicalSize = const Size(1280, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final page = PaginatedWorkflowRequests(
      items: [
        WorkflowRequest(
          id: 'req-1',
          requestNumber: 'WR-20260608-0001',
          title: 'Discount approval',
          requestType: 'general',
          state: 'pending',
          requesterId: 'user-1',
          escalationLevel: 0,
          createdAt: DateTime.utc(2026, 6, 8),
          updatedAt: DateTime.utc(2026, 6, 8),
        ),
      ],
      total: 1,
      skip: 0,
      limit: 25,
    );

    final router = GoRouter(
      initialLocation: '/workflows',
      routes: [
        GoRoute(
          path: '/workflows',
          builder: (context, state) => const WorkflowsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
          profileProvider.overrideWithValue(
            AsyncValue.data(
              _profileWithPermissions(['workflow.view', 'workflow.create']),
            ),
          ),
          workflowsListProvider.overrideWithValue(AsyncValue.data(page)),
          myPendingApprovalsProvider.overrideWithValue(
            const AsyncValue.data(
              PaginatedWorkflowRequests(
                items: [],
                total: 0,
                skip: 0,
                limit: 25,
              ),
            ),
          )
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workflows & Approvals'), findsOneWidget);
    expect(find.text('Discount approval'), findsOneWidget);
    expect(find.text('WR-20260608-0001'), findsOneWidget);
  });
}
