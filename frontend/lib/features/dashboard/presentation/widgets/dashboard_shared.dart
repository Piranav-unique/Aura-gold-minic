import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';

class DashboardHero extends StatelessWidget {
  final String greeting;
  final String subtitle;
  final String roleLabel;
  final DateTime? refreshedAt;

  const DashboardHero({
    super.key,
    required this.greeting,
    required this.subtitle,
    required this.roleLabel,
    this.refreshedAt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Light experience uses the warm gold gradient hero (dark-on-gold text);
    // dark mode keeps the deep slate gradient.
    const onGold = Color(0xFF20180A);
    final textPrimaryColor = isDark ? const Color(0xFFF8FAFC) : onGold;
    final textMutedColor =
        isDark ? const Color(0xFF94A3B8) : AppTheme.onGoldMuted;
    final timeLabel = refreshedAt != null
        ? 'Updated ${DateFormat('HH:mm').format(refreshedAt!.toLocal())}'
        : 'Live';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF141C27), Color(0xFF1A2432)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: const Color(0xFF273244))
            : null,
        boxShadow: isDark ? AppTheme.premiumShadow : AppTheme.goldGlowShadow,
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.primaryGold.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: isDark
                      ? Border.all(
                          color: AppTheme.primaryGold.withValues(alpha: 0.5),
                        )
                      : null,
                ),
                child: Text(
                  roleLabel.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? AppTheme.primaryGold : AppTheme.goldDeep,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.emerald : const Color(0xFF1E5B34),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: textMutedColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            greeting,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: textPrimaryColor,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textMutedColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String trend;
  final IconData icon;
  final Color color;
  final bool positive;

  const DashboardKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    required this.color,
    this.positive = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trend,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: positive ? AppTheme.emerald : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardSection extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  const DashboardSection({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

Widget dashboardKpiGrid(BuildContext context, List<Widget> cards) {
  final width = MediaQuery.sizeOf(context).width;
  final crossAxisCount = width >= 1200
      ? 4
      : width >= 800
      ? 2
      : 1;
  return GridView.count(
    crossAxisCount: crossAxisCount,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 16,
    crossAxisSpacing: 16,
    childAspectRatio: crossAxisCount == 1 ? 2.8 : 2.2,
    children: cards,
  );
}
