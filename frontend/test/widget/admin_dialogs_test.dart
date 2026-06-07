// test/widget/admin_dialogs_test.dart
// Tests for admin form dialogs: UserFormDialog, PermissionFormDialog, RoleFormDialog

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ags_gold/features/admin/presentation/users_screen.dart';
import 'package:ags_gold/features/admin/presentation/permissions_screen.dart';
import 'package:ags_gold/features/admin/presentation/roles_screen.dart';
import 'package:ags_gold/services/service_providers.dart';
import '../mocks/mock_services.dart';

Widget buildWithProviders(Widget child, {List<dynamic> overrides = const []}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
    registerFallbackValue(<String, dynamic>{});
  });

  group('UserFormDialog - Create Mode', () {
    testWidgets('renders create form with required fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWithProviders(
          const UserFormDialog(),
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            rolesListProvider.overrideWithValue(
              const AsyncValue.data([
                {'id': 'r1', 'name': 'Operator', 'description': 'Operator role'}
              ]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create New Operator'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('First Name'), findsOneWidget);
      expect(find.text('Last Name'), findsOneWidget);
      expect(find.text('Assigned Roles'), findsOneWidget);
      expect(find.text('OPERATOR'), findsOneWidget); // role chip
    });

    testWidgets('shows validation errors when form is submitted empty', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWithProviders(
          const UserFormDialog(),
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            rolesListProvider.overrideWithValue(const AsyncValue.data([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the Save button
      final saveBtn = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveBtn);
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('successfully creates user and dismisses dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockResp = MockResponse<dynamic>();
      when(() => mockResp.data).thenReturn({'id': 'new-u1'});
      when(() => mockApi.post('/users/', data: any(named: 'data')))
          .thenAnswer((_) async => mockResp);

      await tester.pumpWidget(
        buildWithProviders(
          const UserFormDialog(),
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            rolesListProvider.overrideWithValue(const AsyncValue.data([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email Address'),
        'new@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      final saveBtn = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      verify(() => mockApi.post('/users/', data: any(named: 'data'))).called(1);
    });
  });

  group('UserFormDialog - Edit Mode', () {
    testWidgets('pre-fills form fields from user data', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const existingUser = {
        'id': 'u1',
        'email': 'existing@example.com',
        'first_name': 'Existing',
        'last_name': 'User',
        'is_active': true,
        'is_superuser': false,
        'roles': <dynamic>[],
      };

      await tester.pumpWidget(
        buildWithProviders(
          const UserFormDialog(user: existingUser),
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            rolesListProvider.overrideWithValue(const AsyncValue.data([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Operator Profile'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'existing@example.com'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Existing'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'User'), findsOneWidget);
    });

    testWidgets('sends PUT request on edit save', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockResp = MockResponse<dynamic>();
      when(() => mockResp.data).thenReturn({'id': 'u1'});
      when(() => mockApi.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResp);

      const existingUser = {
        'id': 'u1',
        'email': 'existing@example.com',
        'first_name': 'Existing',
        'last_name': 'User',
        'is_active': true,
        'is_superuser': false,
        'roles': <dynamic>[],
      };

      await tester.pumpWidget(
        buildWithProviders(
          const UserFormDialog(user: existingUser),
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            rolesListProvider.overrideWithValue(const AsyncValue.data([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final saveBtn = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      verify(() => mockApi.put('/users/u1', data: any(named: 'data'))).called(1);
    });
  });

  group('PermissionFormDialog', () {
    testWidgets('renders form fields', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWithProviders(
          const PermissionFormDialog(),
          overrides: [apiClientProvider.overrideWithValue(mockApi)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Permission Scope'), findsOneWidget);
      expect(find.text('Permission Name'), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitted empty', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWithProviders(
          const PermissionFormDialog(),
          overrides: [apiClientProvider.overrideWithValue(mockApi)],
        ),
      );
      await tester.pumpAndSettle();

      final saveBtn = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveBtn);
      await tester.pump();

      expect(find.text('Permission Name is required'), findsOneWidget);
      expect(find.text('Description is required'), findsOneWidget);
    });

    testWidgets('successfully creates permission and dismisses', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockResp = MockResponse<dynamic>();
      when(() => mockResp.data).thenReturn({'id': 'p1'});
      when(() => mockApi.post('/rbac/permissions', data: any(named: 'data')))
          .thenAnswer((_) async => mockResp);

      await tester.pumpWidget(
        buildWithProviders(
          const PermissionFormDialog(),
          overrides: [apiClientProvider.overrideWithValue(mockApi)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Permission Name'),
        'domain.action',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Test permission description',
      );

      final saveBtn = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      verify(() => mockApi.post('/rbac/permissions', data: any(named: 'data'))).called(1);
    });
  });

  group('RoleFormDialog', () {
    testWidgets('renders create role form', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWithProviders(
          const RoleFormDialog(),
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            permissionsListProvider.overrideWithValue(
              const AsyncValue.data([
                {'id': 'p1', 'name': 'users.read', 'description': 'Read users'}
              ]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Access Role'), findsOneWidget);
      expect(find.text('Role Name'), findsOneWidget);
      expect(find.text('Map Permissions'), findsOneWidget);
    });

    testWidgets('shows validation errors when name is empty', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        buildWithProviders(
          const RoleFormDialog(),
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            permissionsListProvider.overrideWithValue(const AsyncValue.data([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final saveBtn = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveBtn);
      await tester.pump();

      expect(find.text('Role Name is required'), findsOneWidget);
    });

    testWidgets('successfully creates role with permissions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockRoleResp = MockResponse<dynamic>();
      when(() => mockRoleResp.data).thenReturn({'id': 'new-r1', 'name': 'custom_role'});
      when(() => mockApi.post('/rbac/roles', data: any(named: 'data')))
          .thenAnswer((_) async => mockRoleResp);
      when(() => mockApi.post(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => MockResponse<dynamic>());

      await tester.pumpWidget(
        buildWithProviders(
          const RoleFormDialog(),
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            permissionsListProvider.overrideWithValue(
              const AsyncValue.data([
                {'id': 'p1', 'name': 'users.read', 'description': 'Read users'}
              ]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Role Name'),
        'new_test_role',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Description'),
        'Custom description',
      );

      // Select permission checkbox
      final checkbox = find.byType(CheckboxListTile);
      expect(checkbox, findsOneWidget);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      final saveBtn = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      verify(() => mockApi.post('/rbac/roles', data: {
            'name': 'new_test_role',
            'description': 'Custom description',
          })).called(1);

      verify(() => mockApi.post('/rbac/roles/new-r1/permissions', queryParameters: {'permission_id': 'p1'})).called(1);
    });

    testWidgets('successfully edits role and syncs permissions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockResp = MockResponse<dynamic>();
      when(() => mockResp.data).thenReturn({'id': 'r1'});
      when(() => mockApi.put(any(), data: any(named: 'data')))
          .thenAnswer((_) async => mockResp);
      when(() => mockApi.post(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => mockResp);
      when(() => mockApi.delete(any()))
          .thenAnswer((_) async => mockResp);

      const existingRole = {
        'id': 'r1',
        'name': 'operator',
        'description': 'Operator role',
        'permissions': [
          {'id': 'p1', 'name': 'users.read'}
        ],
      };

      await tester.pumpWidget(
        buildWithProviders(
          const RoleFormDialog(role: existingRole),
          overrides: [
            apiClientProvider.overrideWithValue(mockApi),
            permissionsListProvider.overrideWithValue(
              const AsyncValue.data([
                {'id': 'p1', 'name': 'users.read', 'description': 'Read users'},
                {'id': 'p2', 'name': 'users.write', 'description': 'Write users'}
              ]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Role Details'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'operator'), findsOneWidget);

      // We have p1 selected by default. Let's unselect p1 and select p2.
      // p1 CheckboxListTile is the first checkbox
      final checkboxTiles = find.byType(CheckboxListTile);
      expect(checkboxTiles, findsNWidgets(2));

      await tester.tap(checkboxTiles.first); // Unselect p1
      await tester.tap(checkboxTiles.last); // Select p2
      await tester.pumpAndSettle();

      final saveBtn = find.widgetWithText(FilledButton, 'Save');
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      verify(() => mockApi.put('/rbac/roles/r1', data: {
            'name': 'operator',
            'description': 'Operator role',
          })).called(1);

      // Should have posted p2 and deleted p1
      verify(() => mockApi.post('/rbac/roles/r1/permissions', queryParameters: {'permission_id': 'p2'})).called(1);
      verify(() => mockApi.delete('/rbac/roles/r1/permissions/p1')).called(1);
    });
  });
}
