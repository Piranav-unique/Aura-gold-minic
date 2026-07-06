import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/logging/app_event_log.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/l10n/app_localizations.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

/// Canonical app navigation destinations with optional RBAC gates.
class AppNavDestination {
  final String routePrefix;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? requiredPermission;

  const AppNavDestination({
    required this.routePrefix,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.requiredPermission,
  });
}

List<AppNavDestination> buildNavDestinations(
  UserProfile? profile, {
  AppAudience? audience,
  required AppLocalizations l10n,
}) {
  bool visible(String? permission) {
    if (permission == null) return true;
    if (profile == null) return false;
    return hasPermission(profile, permission);
  }

  final all = [
    AppNavDestination(
      routePrefix: '/user-dashboard',
      label: l10n.navAurum,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    AppNavDestination(
      routePrefix: '/portfolio',
      label: l10n.navPortfolio,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
    AppNavDestination(
      routePrefix: '/dashboard',
      label: l10n.navOverview,
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      requiredPermission: 'dashboard.view',
    ),
    AppNavDestination(
      routePrefix: '/profile',
      label: l10n.navProfile,
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
    AppNavDestination(
      routePrefix: '/audit-logs',
      label: l10n.navAuditLogs,
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      requiredPermission: 'audit.view',
    ),
    AppNavDestination(
      routePrefix: '/customers',
      label: l10n.navCustomers,
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront,
      requiredPermission: 'customer.view',
    ),
    AppNavDestination(
      routePrefix: '/inventory',
      label: l10n.navInventory,
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      requiredPermission: 'inventory.view',
    ),
    AppNavDestination(
      routePrefix: '/transactions',
      label: l10n.navTransactions,
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      requiredPermission: 'transaction.view',
    ),
    AppNavDestination(
      routePrefix: '/admin/user-wallets',
      label: l10n.navUserWallets,
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      requiredPermission: 'wallet.view',
    ),
    AppNavDestination(
      routePrefix: '/admin/payment-settlements',
      label: l10n.navPaymentSettlements,
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
      requiredPermission: 'transaction.view',
    ),
    AppNavDestination(
      routePrefix: '/admin/sell-inquiries',
      label: l10n.navSellInquiries,
      icon: Icons.sell_outlined,
      selectedIcon: Icons.sell,
      requiredPermission: 'transaction.view',
    ),
    AppNavDestination(
      routePrefix: '/admin/profile',
      label: 'Org profile',
      icon: Icons.business_outlined,
      selectedIcon: Icons.business,
      requiredPermission: 'organization.view',
    ),
    AppNavDestination(
      routePrefix: '/reports',
      label: l10n.navReports,
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      requiredPermission: 'report.view',
    ),
    AppNavDestination(
      routePrefix: '/workflows',
      label: l10n.navWorkflows,
      icon: Icons.approval_outlined,
      selectedIcon: Icons.approval,
      requiredPermission: 'workflow.view',
    ),
    AppNavDestination(
      routePrefix: '/admin/users',
      label: l10n.navUsers,
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      requiredPermission: 'user.view',
    ),
    AppNavDestination(
      routePrefix: '/admin/roles',
      label: l10n.navRoles,
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings,
      requiredPermission: 'role:read',
    ),
    AppNavDestination(
      routePrefix: '/admin/permissions',
      label: l10n.navPermissions,
      icon: Icons.security_outlined,
      selectedIcon: Icons.security,
      requiredPermission: 'role:read',
    ),
    AppNavDestination(
      routePrefix: '/settings',
      label: l10n.navSettings,
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  return all.where((d) {
    if (!visible(d.requiredPermission)) return false;
    if (audience == AppAudience.staffAdmin) {
      const hiddenForStaffAdmin = {
        '/user-dashboard',
        '/portfolio',
        '/customers',
        '/audit-logs',
        '/workflows',
      };
      if (hiddenForStaffAdmin.contains(d.routePrefix)) return false;
    }
    if (audience == AppAudience.endUser) {
      const staffOnlyRoutes = {
        '/dashboard',
        '/audit-logs',
        '/customers',
        '/inventory',
        '/transactions',
        '/admin/payment-settlements',
        '/admin/sell-inquiries',
        '/admin/profile',
        '/admin/user-wallets',
        '/reports',
        '/workflows',
        '/admin/users',
        '/admin/roles',
        '/admin/permissions',
        '/settings',
      };
      if (staffOnlyRoutes.contains(d.routePrefix)) return false;
    }
    return true;
  }).toList();
}

int selectedNavIndex(String path, List<AppNavDestination> destinations) {
  for (var i = 0; i < destinations.length; i++) {
    if (path.startsWith(destinations[i].routePrefix)) {
      return i;
    }
  }
  return 0;
}

void navigateToIndex(
  BuildContext context,
  int index,
  List<AppNavDestination> destinations,
) {
  if (index < 0 || index >= destinations.length) return;
  final dest = destinations[index];
  AppEventLog.action(
    'tab_selected',
    data: {
      'index': index,
      'route': dest.routePrefix,
      'label': dest.label,
    },
  );
  context.go(dest.routePrefix);
}

bool matchesNavRoute(String path, String routePrefix) {
  if (routePrefix == '/inventory') {
    return path == '/inventory' || path.startsWith('/inventory/');
  }
  if (routePrefix == '/admin/user-wallets') {
    return path.startsWith('/admin/user-wallets');
  }
  return path.startsWith(routePrefix);
}

int selectedNavIndexForPath(String path, List<AppNavDestination> destinations) {
  for (var i = 0; i < destinations.length; i++) {
    if (matchesNavRoute(path, destinations[i].routePrefix)) {
      return i;
    }
  }
  return -1;
}
