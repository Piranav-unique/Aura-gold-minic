import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/widgets/permission_gate.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/services/service_providers.dart';

final _viewerProfile = UserProfile(
  id: '2',
  email: 'viewer@example.com',
  isActive: true,
  isSuperuser: false,
  roles: const [
    UserRole(
      id: 'r1',
      name: 'Viewer',
      permissions: [UserPermission(id: 'p1', name: 'user.view')],
    ),
  ],
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

final _customerViewerProfile = UserProfile(
  id: '3',
  email: 'customer@example.com',
  isActive: true,
  isSuperuser: false,
  roles: const [
    UserRole(
      id: 'r2',
      name: 'CustomerViewer',
      permissions: [UserPermission(id: 'p2', name: 'customer.view')],
    ),
  ],
  createdAt: DateTime.utc(2026, 6, 8),
  updatedAt: DateTime.utc(2026, 6, 8),
);

void main() {
  testWidgets('PermissionGate blocks users without required permission', (
    tester,
  ) async {
    const deniedChild = Text('secret-content');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => _viewerProfile),
        ],
        child: const MaterialApp(
          home: PermissionGate(
            requiredPermission: 'customer.view',
            child: deniedChild,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('secret-content'), findsNothing);
    expect(find.byType(EmptyStateWidget), findsOneWidget);
    expect(find.text('Access denied'), findsOneWidget);
  });

  testWidgets('PermissionGate renders child when permission is granted', (
    tester,
  ) async {
    const allowedChild = Text('customer-list');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith((ref) async => _customerViewerProfile),
        ],
        child: const MaterialApp(
          home: PermissionGate(
            requiredPermission: 'customer.view',
            child: allowedChild,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('customer-list'), findsOneWidget);
  });
}
