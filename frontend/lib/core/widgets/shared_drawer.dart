import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';

class ResponsiveNavigationWrapper extends ConsumerWidget {
  final Widget child;
  final String title;

  const ResponsiveNavigationWrapper({
    super.key,
    required this.child,
    required this.title,
  });

  int _getSelectedIndex(String path) {
    if (path.startsWith('/dashboard')) return 0;
    if (path.startsWith('/profile')) return 1;
    if (path.startsWith('/admin/users')) return 2;
    if (path.startsWith('/admin/roles')) return 3;
    if (path.startsWith('/admin/permissions')) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/profile');
        break;
      case 2:
        context.go('/admin/users');
        break;
      case 3:
        context.go('/admin/roles');
        break;
      case 4:
        context.go('/admin/permissions');
        break;
    }
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to end your current session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).logout();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = GoRouterState.of(context);
    final currentPath = state.matchedLocation;
    final selectedIndex = _getSelectedIndex(currentPath);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            // Sidebar Navigation Rail for Wide Screens
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onItemTapped(context, index),
              labelType: NavigationRailLabelType.all,
              selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
              selectedLabelTextStyle: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              leading: const Column(
                children: [
                  SizedBox(height: 16),
                  Icon(
                    Icons.monetization_on,
                    size: 40,
                    color: AppTheme.primaryGold,
                  ),
                  SizedBox(height: 32),
                ],
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            return IconButton(
                              icon: Icon(
                                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                              onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(context),
                              tooltip: 'Toggle Theme',
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.redAccent),
                          onPressed: () => _handleLogout(context, ref),
                          tooltip: 'Log Out',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Overview'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Users'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.admin_panel_settings_outlined),
                  selectedIcon: Icon(Icons.admin_panel_settings),
                  label: Text('Roles'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.security_outlined),
                  selectedIcon: Icon(Icons.security),
                  label: Text('Permissions'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            // Main Content Area
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  elevation: 0,
                ),
                body: child,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile & Tablet Layout (App Bar + Navigation Drawer)
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(context),
                tooltip: 'Toggle Theme',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context, ref),
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            // Drawer Header
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.colorScheme.primary,
                child: Icon(Icons.person, color: theme.colorScheme.onPrimary, size: 36),
              ),
              accountName: Text(
                'AGS GOLD Operator',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                'superadmin@agsgold.com',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
            ),
            // Navigation List Items
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Overview'),
              selected: selectedIndex == 0,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(context, 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              selected: selectedIndex == 1,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(context, 1);
              },
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'ADMINISTRATION',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Users'),
              selected: selectedIndex == 2,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(context, 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Roles'),
              selected: selectedIndex == 3,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(context, 3);
              },
            ),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Permissions'),
              selected: selectedIndex == 4,
              onTap: () {
                Navigator.pop(context);
                _onItemTapped(context, 4);
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout(context, ref);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: child,
    );
  }
}
