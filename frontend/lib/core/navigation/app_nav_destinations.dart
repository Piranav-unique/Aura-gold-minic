import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';

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

List<AppNavDestination> buildNavDestinations(UserProfile? profile) {
  bool visible(String? permission) {
    if (permission == null) return true;
    if (profile == null) return false;
    return hasPermission(profile, permission);
  }

  final all = [
    const AppNavDestination(
      routePrefix: '/dashboard',
      label: 'Overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    const AppNavDestination(
      routePrefix: '/profile',
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
    const AppNavDestination(
      routePrefix: '/audit-logs',
      label: 'Audit Logs',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      requiredPermission: 'audit.view',
    ),
    const AppNavDestination(
      routePrefix: '/customers',
      label: 'Customers',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront,
      requiredPermission: 'customer.view',
    ),
    const AppNavDestination(
      routePrefix: '/inventory',
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
      requiredPermission: 'inventory.view',
    ),
    const AppNavDestination(
      routePrefix: '/transactions',
      label: 'Transactions',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
      requiredPermission: 'transaction.view',
    ),
    const AppNavDestination(
      routePrefix: '/reports',
      label: 'Reports',
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
      requiredPermission: 'report.view',
    ),
    const AppNavDestination(
      routePrefix: '/workflows',
      label: 'Workflows',
      icon: Icons.approval_outlined,
      selectedIcon: Icons.approval,
      requiredPermission: 'workflow.view',
    ),
    const AppNavDestination(
      routePrefix: '/admin/users',
      label: 'Users',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      requiredPermission: 'user.view',
    ),
    const AppNavDestination(
      routePrefix: '/admin/roles',
      label: 'Roles',
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings,
      requiredPermission: 'role:read',
    ),
    const AppNavDestination(
      routePrefix: '/admin/permissions',
      label: 'Permissions',
      icon: Icons.security_outlined,
      selectedIcon: Icons.security,
      requiredPermission: 'role:read',
    ),
    const AppNavDestination(
      routePrefix: '/settings',
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  return all.where((d) => visible(d.requiredPermission)).toList();
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
  context.go(destinations[index].routePrefix);
}

bool matchesNavRoute(String path, String routePrefix) {
  if (routePrefix == '/inventory') {
    return path.startsWith('/inventory') || path.startsWith('/suppliers');
  }
  return path.startsWith(routePrefix);
}

int selectedNavIndexForPath(String path, List<AppNavDestination> destinations) {
  for (var i = 0; i < destinations.length; i++) {
    if (matchesNavRoute(path, destinations[i].routePrefix)) {
      return i;
    }
  }
  return 0;
}
