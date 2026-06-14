import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/navigation/app_nav_destinations.dart';
import 'package:ags_gold/features/notifications/presentation/notification_drawer.dart';

class ResponsiveNavigationWrapper extends ConsumerWidget {
  final Widget child;
  final String title;

  const ResponsiveNavigationWrapper({
    super.key,
    required this.child,
    required this.title,
  });

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text(
          'Are you sure you want to end your current session?',
        ),
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
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final profile = ref.watch(profileProvider).value;
    final destinations = buildNavDestinations(profile);
    final selectedIndex = selectedNavIndexForPath(currentPath, destinations);

    if (isDesktop) {
      return Scaffold(
        endDrawer: const NotificationDrawer(),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  navigateToIndex(context, index, destinations),
              labelType: NavigationRailLabelType.selected,
              selectedIconTheme: IconThemeData(
                color: theme.colorScheme.primary,
              ),
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
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Scaffold(
                endDrawer: const NotificationDrawer(),
                appBar: AppBar(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  elevation: 0,
                  actions: [
                    const NotificationBellButton(),
                    Consumer(
                      builder: (context, ref, child) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        return IconButton(
                          icon: Icon(
                            isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                          ),
                          onPressed: () => ref
                              .read(themeModeProvider.notifier)
                              .toggleTheme(context),
                          tooltip: 'Toggle Theme',
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout),
                      onPressed: () => _handleLogout(context, ref),
                      tooltip: 'Log Out',
                    ),
                  ],
                ),
                body: child,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      endDrawer: const NotificationDrawer(),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          const NotificationBellButton(),
          Consumer(
            builder: (context, ref, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              return IconButton(
                icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () =>
                    ref.read(themeModeProvider.notifier).toggleTheme(context),
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
            Consumer(
              builder: (context, ref, _) {
                final profileAsync = ref.watch(profileProvider);
                return profileAsync.when(
                  data: (profile) => UserAccountsDrawerHeader(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                    ),
                    currentAccountPicture: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        profile.initials,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    accountName: Text(
                      profile.displayName,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    accountEmail: Text(
                      profile.email,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.8,
                        ),
                      ),
                    ),
                  ),
                  loading: () => UserAccountsDrawerHeader(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                    ),
                    accountName: const Text('Loading...'),
                    accountEmail: const Text(''),
                  ),
                  error: (_, _) => UserAccountsDrawerHeader(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                    ),
                    accountName: const Text('AGS Gold'),
                    accountEmail: const Text(''),
                  ),
                );
              },
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ...destinations.asMap().entries.map(
                    (entry) => ListTile(
                      leading: Icon(entry.value.selectedIcon),
                      title: Text(entry.value.label),
                      selected: selectedIndex == entry.key,
                      onTap: () {
                        Navigator.pop(context);
                        navigateToIndex(context, entry.key, destinations);
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text(
                      'Log Out',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout(context, ref);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: child,
    );
  }
}
