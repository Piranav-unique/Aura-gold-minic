import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class _QuickAction {
  final String labelKey;
  final IconData icon;
  final String route;
  final String? permission;
  final Color color;

  const _QuickAction({
    required this.labelKey,
    required this.icon,
    required this.route,
    this.permission,
    required this.color,
  });
}

const _allActions = [
  _QuickAction(
    labelKey: 'newSale',
    icon: Icons.point_of_sale_outlined,
    route: '/transactions/new',
    permission: 'transaction.create',
    color: AppTheme.primaryGold,
  ),
  _QuickAction(
    labelKey: 'customer',
    icon: Icons.person_add_outlined,
    route: '/customers/new',
    permission: 'customer.create',
    color: AppTheme.sapphireBlue,
  ),
  _QuickAction(
    labelKey: 'workflow',
    icon: Icons.approval_outlined,
    route: '/workflows/new',
    permission: 'workflow.create',
    color: AppTheme.emerald,
  ),
  _QuickAction(
    labelKey: 'inventory',
    icon: Icons.inventory_2_outlined,
    route: '/inventory',
    permission: 'inventory.view',
    color: AppTheme.sapphireBlue,
  ),
  _QuickAction(
    labelKey: 'reports',
    icon: Icons.analytics_outlined,
    route: '/reports',
    permission: 'report.view',
    color: AppTheme.rose,
  ),
  _QuickAction(
    labelKey: 'overview',
    icon: Icons.dashboard_outlined,
    route: '/dashboard',
    permission: 'dashboard.view',
    color: AppTheme.deepNavy,
  ),
  _QuickAction(
    labelKey: 'profile',
    icon: Icons.person_outline,
    route: '/profile',
    color: AppTheme.primaryGold,
  ),
];

String _actionLabel(AppLocalizations l10n, String key) {
  switch (key) {
    case 'newSale':
      return l10n.newSale;
    case 'customer':
      return l10n.customer;
    case 'workflow':
      return l10n.workflow;
    case 'inventory':
      return l10n.navInventory;
    case 'reports':
      return l10n.navReports;
    case 'overview':
      return l10n.navOverview;
    case 'profile':
      return l10n.navProfile;
    default:
      return key;
  }
}

class QuickActionsPanel extends StatelessWidget {
  final UserProfile? profile;

  const QuickActionsPanel({super.key, this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final actions = _allActions.where((action) {
      if (action.permission == null) return true;
      if (profile == null) return false;
      return hasPermission(profile!, action.permission!);
    }).toList();

    if (actions.isEmpty) return const SizedBox.shrink();

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 1200
        ? 4
        : width >= 600
        ? 4
        : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quickActions,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => context.push(action.route),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: action.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(action.icon, color: action.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _actionLabel(l10n, action.labelKey),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
