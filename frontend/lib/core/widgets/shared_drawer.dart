import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/navigation/app_nav_destinations.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/live_price_app_bar_chip.dart';
import 'package:ags_gold/core/widgets/app_exit_guard.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class ResponsiveNavigationWrapper extends ConsumerWidget {
  final Widget child;
  final String title;

  const ResponsiveNavigationWrapper({
    super.key,
    required this.child,
    required this.title,
  });

  Future<void> _handleBack(
    BuildContext context, {
    required bool isHome,
    required String homePath,
    required bool didPop,
  }) async {
    if (didPop) return;
    if (!isHome) {
      context.go(homePath);
      return;
    }
    await requestAppExit(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = GoRouterState.of(context);
    final currentPath = state.matchedLocation;
    final themeMode = ref.watch(themeModeProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final theme = Theme.of(context);
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final profile = ref.watch(profileProvider).value;
    final audience = ref.watch(appAudienceProvider);
    final l10n = context.l10n;
    final destinations = buildNavDestinations(
      profile,
      audience: audience,
      l10n: l10n,
    );
    final selectedIndex = selectedNavIndexForPath(currentPath, destinations);

    // Back button always returns to the home page (user or admin). Only when
    // already on the home page is a pop allowed (which exits the app).
    final homePath =
        audience == AppAudience.endUser ? '/user-dashboard' : '/dashboard';
    final isHome = currentPath == homePath;
    void handleBack(bool didPop, Object? result) {
      _handleBack(
        context,
        isHome: isHome,
        homePath: homePath,
        didPop: didPop,
      );
    }

    if (isDesktop) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: handleBack,
        child: Scaffold(
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
                appBar: AppBar(
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  elevation: 0,
                  actions: [
                    if (audience == AppAudience.endUser || currentPath.startsWith('/inventory'))
                      const LivePriceAppBarChip(),
                  ],
                ),
                body: child,
              ),
            ),
          ],
        ),
        ),
      );
    }

    final isEndUserMobile = audience == AppAudience.endUser;
    final isStaffMobile = !isEndUserMobile;
    final mobileLeading = isHome
        ? null
        : IconButton(
            icon: const BackButtonIcon(),
            onPressed: () => context.go(homePath),
          );

    const endUserTabPrefixes = ['/user-dashboard', '/portfolio', '/profile'];
    final endUserDestinations = isEndUserMobile
        ? endUserTabPrefixes
            .map((prefix) =>
                destinations.where((d) => d.routePrefix == prefix).firstOrNull)
            .whereType<AppNavDestination>()
            .toList()
        : <AppNavDestination>[];

    const staffMobileTabPrefixes = [
      '/dashboard',
      '/inventory',
      '/profile',
    ];
    // Routes that are launched via context.push() from Profile page —
    // keep the bottom nav highlighted on Profile for all of them.
    // NOTE: /inventory is a real tab — do NOT include it here.
    const profileSubRoutes = {
      '/admin/users',
      '/admin/roles',
      '/admin/permissions',
      '/admin/user-wallets',
      '/admin/payment-settlements',
      '/admin/sell-inquiries',
      '/audit-logs',
      '/settings',
      '/bank-accounts',
      '/kyc',
    };
    // Sort destinations to enforce the display order: Overview · Inventory · Profile
    final staffMobileDestinations = isStaffMobile
        ? staffMobileTabPrefixes
            .map((prefix) => destinations.where((d) => d.routePrefix == prefix).firstOrNull)
            .whereType<AppNavDestination>()
            .toList()
        : <AppNavDestination>[];

    final bottomNavDestinations =
        isEndUserMobile ? endUserDestinations : staffMobileDestinations;

    // Determine active tab index. If current path is a sub-route pushed from
    // Profile (e.g. /audit-logs, /admin/users), keep Profile tab highlighted.
    int bottomNavIndex;
    if (profileSubRoutes.any((r) => currentPath.startsWith(r))) {
      bottomNavIndex = bottomNavDestinations.indexWhere(
        (d) => d.routePrefix == '/profile',
      );
      if (bottomNavIndex < 0) bottomNavIndex = 0;
    } else {
      bottomNavIndex = bottomNavDestinations.isNotEmpty
          ? selectedNavIndexForPath(currentPath, bottomNavDestinations)
          : 0;
      if (bottomNavIndex < 0) bottomNavIndex = 0;
    }

    final consumerTheme = AurumConsumerTheme.resolve(
      themeMode,
      platformBrightness,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: handleBack,
      child: Theme(
      data: consumerTheme,
      child: Scaffold(
      backgroundColor: consumerTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: mobileLeading,
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          if (audience == AppAudience.endUser || currentPath.startsWith('/inventory'))
            const LivePriceAppBarChip(),
        ],
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      drawer: null,
      bottomNavigationBar: bottomNavDestinations.length >= 2
          ? _MobileBottomNav(
              destinations: bottomNavDestinations,
              currentIndex: bottomNavIndex < 0 ? 0 : bottomNavIndex,
            )
          : null,
      body: child,
      ),
      ),
    );
  }
}

class _MobileBottomNav extends StatelessWidget {
  final List<AppNavDestination> destinations;
  final int currentIndex;

  const _MobileBottomNav({
    required this.destinations,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: AurumConsumerTheme.borderOf(context))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    label: destinations[i].label,
                    icon: destinations[i].icon,
                    selectedIcon: destinations[i].selectedIcon,
                    selected: currentIndex == i,
                    onTap: () => navigateToIndex(context, i, destinations),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = AppTheme.goldDeep;
    final mutedColor = AurumConsumerTheme.muted(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: selected
                  ? BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppTheme.goldGlowShadow,
                    )
                  : null,
              child: Icon(
                selected ? selectedIcon : icon,
                color: selected ? AppTheme.ink : mutedColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? selectedColor : mutedColor,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

