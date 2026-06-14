import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/features/splash/presentation/splash_screen.dart';
import 'package:ags_gold/features/auth/presentation/login_screen.dart';
import 'package:ags_gold/features/dashboard/presentation/dashboard_screen.dart';
import 'package:ags_gold/features/profile/presentation/profile_screen.dart';
import 'package:ags_gold/features/admin/presentation/users_screen.dart';
import 'package:ags_gold/features/admin/presentation/roles_screen.dart';
import 'package:ags_gold/features/admin/presentation/permissions_screen.dart';
import 'package:ags_gold/features/audit_logs/presentation/audit_logs_screen.dart';
import 'package:ags_gold/features/settings/presentation/settings_screen.dart';
import 'package:ags_gold/features/customers/presentation/customers_screen.dart';
import 'package:ags_gold/features/customers/presentation/customer_detail_screen.dart';
import 'package:ags_gold/features/customers/presentation/customer_form_screen.dart';
import 'package:ags_gold/features/inventory/presentation/inventory_screen.dart';
import 'package:ags_gold/features/inventory/presentation/inventory_detail_screen.dart';
import 'package:ags_gold/features/inventory/presentation/inventory_form_screen.dart';
import 'package:ags_gold/features/inventory/presentation/suppliers_screen.dart';
import 'package:ags_gold/features/inventory/presentation/stock_movements_screen.dart';
import 'package:ags_gold/features/inventory/presentation/inventory_permission_gate.dart';
import 'package:ags_gold/features/transactions/presentation/transactions_screen.dart';
import 'package:ags_gold/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:ags_gold/features/transactions/presentation/transaction_form_screen.dart';
import 'package:ags_gold/features/transactions/presentation/transaction_permission_gate.dart';
import 'package:ags_gold/features/reports/presentation/reports_screen.dart';
import 'package:ags_gold/features/reports/presentation/report_permission_gate.dart';
import 'package:ags_gold/features/workflows/presentation/workflows_screen.dart';
import 'package:ags_gold/features/workflows/presentation/workflow_detail_screen.dart';
import 'package:ags_gold/features/workflows/presentation/workflow_form_screen.dart';
import 'package:ags_gold/features/workflows/presentation/workflow_permission_gate.dart';
import 'package:ags_gold/core/widgets/permission_gate.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  // Use a ValueNotifier to notify GoRouter when authentication status changes
  final listenable = ValueNotifier<AsyncValue<AuthStatus>>(authState);

  ref.listen<AsyncValue<AuthStatus>>(authNotifierProvider, (previous, next) {
    listenable.value = next;
  });

  ref.onDispose(() {
    listenable.dispose();
  });

  return GoRouter(
    initialLocation: '/',
    refreshListenable: listenable,
    redirect: (context, state) {
      final authValue = ref.read(authNotifierProvider);
      final status = authValue.value ?? AuthStatus.initial;

      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/';

      if (authValue.isLoading || status == AuthStatus.initial) {
        return isSplash ? null : '/';
      }

      if (status == AuthStatus.unauthenticated) {
        return isLoggingIn ? null : '/login';
      }

      if (status == AuthStatus.authenticated) {
        if (isLoggingIn || isSplash) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'dashboard.view',
          child: DashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/audit-logs',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'audit.view',
          child: AuditLogsScreen(),
        ),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'customer.view',
          child: CustomersScreen(),
        ),
      ),
      GoRoute(
        path: '/customers/new',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'customer.create',
          deniedSubtitle: 'You need customer.create to add customers.',
          child: CustomerFormScreen(),
        ),
      ),
      GoRoute(
        path: '/customers/:id/edit',
        builder: (context, state) => PermissionGate(
          requiredPermission: 'customer.update',
          deniedSubtitle: 'You need customer.update to edit customers.',
          child: CustomerFormScreen(customerId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/customers/:id',
        builder: (context, state) => PermissionGate(
          requiredPermission: 'customer.view',
          child: CustomerDetailScreen(customerId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryPermissionGate(
          requiredPermission: 'inventory.view',
          child: InventoryScreen(),
        ),
      ),
      GoRoute(
        path: '/inventory/movements',
        builder: (context, state) => const InventoryPermissionGate(
          requiredPermission: 'inventory.view',
          child: StockMovementsScreen(),
        ),
      ),
      GoRoute(
        path: '/inventory/new',
        builder: (context, state) => const InventoryPermissionGate(
          requiredPermission: 'inventory.create',
          deniedSubtitle: 'You need inventory.create to add items.',
          child: InventoryFormScreen(),
        ),
      ),
      GoRoute(
        path: '/inventory/:id/edit',
        builder: (context, state) => InventoryPermissionGate(
          requiredPermission: 'inventory.update',
          deniedSubtitle: 'You need inventory.update to edit items.',
          child: InventoryFormScreen(itemId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/inventory/:id',
        builder: (context, state) => InventoryPermissionGate(
          requiredPermission: 'inventory.view',
          child: InventoryDetailScreen(itemId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const InventoryPermissionGate(
          requiredPermission: 'inventory.view',
          child: SuppliersScreen(),
        ),
      ),
      GoRoute(
        path: '/transactions',
        builder: (context, state) => const TransactionPermissionGate(
          requiredPermission: 'transaction.view',
          child: TransactionsScreen(),
        ),
      ),
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) => const TransactionPermissionGate(
          requiredPermission: 'transaction.create',
          deniedSubtitle: 'You need transaction.create to add transactions.',
          child: TransactionFormScreen(),
        ),
      ),
      GoRoute(
        path: '/transactions/:id/edit',
        builder: (context, state) => TransactionPermissionGate(
          requiredPermission: 'transaction.update',
          deniedSubtitle: 'You need transaction.update to edit transactions.',
          child: TransactionFormScreen(
            transactionId: state.pathParameters['id'],
          ),
        ),
      ),
      GoRoute(
        path: '/transactions/:id',
        builder: (context, state) => TransactionPermissionGate(
          requiredPermission: 'transaction.view',
          child: TransactionDetailScreen(
            transactionId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) =>
            const ReportPermissionGate(child: ReportsScreen()),
      ),
      GoRoute(
        path: '/workflows',
        builder: (context, state) => const WorkflowPermissionGate(
          requiredPermission: 'workflow.view',
          child: WorkflowsScreen(),
        ),
      ),
      GoRoute(
        path: '/workflows/new',
        builder: (context, state) => const WorkflowPermissionGate(
          requiredPermission: 'workflow.create',
          deniedSubtitle: 'You need workflow.create to create requests.',
          child: WorkflowFormScreen(),
        ),
      ),
      GoRoute(
        path: '/workflows/:id/edit',
        builder: (context, state) => WorkflowPermissionGate(
          requiredPermission: 'workflow.create',
          deniedSubtitle: 'You need workflow.create to edit requests.',
          child: WorkflowFormScreen(requestId: state.pathParameters['id']),
        ),
      ),
      GoRoute(
        path: '/workflows/:id',
        builder: (context, state) => WorkflowPermissionGate(
          requiredPermission: 'workflow.view',
          child: WorkflowDetailScreen(requestId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'user.view',
          child: UsersScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/roles',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'role:read',
          child: RolesScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/permissions',
        builder: (context, state) => const PermissionGate(
          requiredPermission: 'role:read',
          child: PermissionsScreen(),
        ),
      ),
    ],
  );
});
