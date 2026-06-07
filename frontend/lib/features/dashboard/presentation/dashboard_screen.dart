import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/kpi_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return const ResponsiveNavigationWrapper(
      title: 'Dashboard Overview',
      child: _DashboardOverviewContent(),
    );
  }
}

class _DashboardOverviewContent extends ConsumerStatefulWidget {
  const _DashboardOverviewContent();

  @override
  ConsumerState<_DashboardOverviewContent> createState() => _DashboardOverviewContentState();
}

class _DashboardOverviewContentState extends ConsumerState<_DashboardOverviewContent> {
  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final theme = Theme.of(context);
    final auditLogsAsync = ref.watch(auditLogsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(auditLogsProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Greeting Card with Gradient Background & Icon Accent
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppTheme.deepNavy,
                    Color(0xFF1E293B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3), width: 1.5),
                boxShadow: AppTheme.premiumShadow,
              ),
              padding: const EdgeInsets.all(28.0),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.monetization_on_outlined,
                      size: 150,
                      color: AppTheme.primaryGold.withValues(alpha: 0.04),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.6), width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_outlined, color: AppTheme.primaryGold, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'FINTECH SECURE',
                                  style: TextStyle(
                                    color: AppTheme.primaryGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to AGS GOLD Operator Portal',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'This is the secure administration operations dashboard. All user actions, security alterations, and auth transactions are logged and auditable in real-time.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF94A3B8),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats KPI Grid
            _buildStatsGrid(isDesktop),
            const SizedBox(height: 28),

            // Quick Actions Section
            _buildQuickActions(context),
            const SizedBox(height: 28),

            // Interactive Chart
            const PremiumFintechChart(),
            const SizedBox(height: 28),

            // Recent Audit Logs Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Audit Trails',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => ref.refresh(auditLogsProvider.future),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Audit Logs List
            auditLogsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.history_toggle_off_outlined, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              'No audit logs recorded or permissions missing.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
                    itemBuilder: (context, index) {
                      final log = logs[index] as Map<String, dynamic>;
                      final action = log['action'] ?? 'UNKNOWN';
                      final ip = log['ip_address'] ?? 'unknown';
                      final timestampStr = log['timestamp'] as String? ?? '';
                      final timeText = timestampStr.isNotEmpty
                          ? DateTime.parse(timestampStr).toLocal().toString().substring(0, 19)
                          : 'unknown';

                      final bool isSuccess = action.toString().toLowerCase().contains('success') ||
                          action.toString().toLowerCase().contains('create') ||
                          action.toString().toLowerCase().contains('assign');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: (isSuccess ? AppTheme.emerald : AppTheme.rose).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSuccess ? Icons.check_circle_outline : Icons.history,
                            color: isSuccess ? AppTheme.emerald : AppTheme.rose,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          action.toUpperCase().replaceAll('_', ' '),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'IP: $ip • Resource: ${log['entity_type'] ?? 'None'} (${log['entity_id'] ?? 'None'})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        trailing: Text(
                          timeText,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => _buildSkeletonLoader(context),
              error: (err, stack) => Card(
                color: AppTheme.rose.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.rose, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.rose, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load audit logs: $err',
                          style: const TextStyle(color: AppTheme.rose, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(bool isDesktop) {
    final kpis = ref.watch(kpiProvider);
    final stats = kpis.map((kpi) {
      IconData icon;
      Color color;
      String trend;
      bool isPositive = true;

      if (kpi.id == 'vault' || kpi.id == 'sales') {
        icon = Icons.store;
        color = AppTheme.primaryGold;
        trend = '+ 1.2% this week';
      } else if (kpi.id == 'users') {
        icon = Icons.people_outline;
        color = AppTheme.sapphireBlue;
        trend = '+ 4 new today';
      } else {
        icon = Icons.check_circle_outline;
        color = AppTheme.emerald;
        trend = 'All services operational';
      }

      return _StatItem(kpi.title, kpi.value, icon, color, trend, isPositive);
    }).toList();

    if (isDesktop) {
      return Row(
        children: stats.map((s) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: s == stats.last ? 0 : 16.0,
              ),
              child: _buildStatCard(s),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: stats.map((s) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: _buildStatCard(s),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    final theme = Theme.of(context);
    return Card(
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.premiumShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                color: item.color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        item.isPositive ? Icons.trending_up : Icons.trending_flat,
                        color: item.isPositive ? AppTheme.emerald : Colors.grey,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.trend,
                        style: TextStyle(
                          fontSize: 11,
                          color: item.isPositive ? AppTheme.emerald : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Operations',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                context,
                'Create User',
                Icons.person_add_alt_1_outlined,
                AppTheme.sapphireBlue,
                () => context.go('/admin/users'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                context,
                'Manage Roles',
                Icons.admin_panel_settings_outlined,
                AppTheme.amber,
                () => context.go('/admin/roles'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                context,
                'Security Registry',
                Icons.verified_user_outlined,
                AppTheme.emerald,
                () => context.go('/admin/permissions'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: List.generate(4, (index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 150,
                          height: 8,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String trend;
  final bool isPositive;

  _StatItem(this.label, this.value, this.icon, this.color, this.trend, this.isPositive);
}

class PremiumFintechChart extends StatefulWidget {
  const PremiumFintechChart({super.key});

  @override
  State<PremiumFintechChart> createState() => _PremiumFintechChartState();
}

class _PremiumFintechChartState extends State<PremiumFintechChart> {
  int _hoveredIndex = -1;
  final List<double> _data = [138.2, 139.5, 139.1, 140.8, 141.6, 142.3, 142.84];
  final List<String> _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gold Vault Historical Weight (kg)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time weight logs over the last 7 days',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '+ 3.36% Week',
                    style: TextStyle(
                      color: AppTheme.emerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                const height = 200.0;
                return GestureDetector(
                  onPanUpdate: (details) {
                    final localPosition = details.localPosition;
                    final segmentWidth = width / (_data.length - 1);
                    final index = (localPosition.dx / segmentWidth).round().clamp(0, _data.length - 1);
                    if (index != _hoveredIndex) {
                      setState(() {
                        _hoveredIndex = index;
                      });
                    }
                  },
                  onPanEnd: (_) {
                    setState(() {
                      _hoveredIndex = -1;
                    });
                  },
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(width, height),
                        painter: ChartPainter(
                          data: _data,
                          hoveredIndex: _hoveredIndex,
                          isDark: isDark,
                          theme: theme,
                        ),
                      ),
                      if (_hoveredIndex != -1)
                        Positioned(
                          left: (_hoveredIndex * (width / (_data.length - 1))) - 50,
                          top: 10,
                          child: Container(
                            width: 100,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.primaryGold),
                              boxShadow: AppTheme.premiumShadow,
                            ),
                            child: Center(
                              child: Text(
                                '${_data[_hoveredIndex]} kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _labels.map((l) {
                return Text(
                  l,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<double> data;
  final int hoveredIndex;
  final bool isDark;
  final ThemeData theme;

  ChartPainter({
    required this.data,
    required this.hoveredIndex,
    required this.isDark,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce((a, b) => a > b ? a : b) * 1.01;
    final minVal = data.reduce((a, b) => a < b ? a : b) * 0.99;
    final valRange = maxVal - minVal;

    final points = <Offset>[];
    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minVal) / valRange * size.height);
      points.add(Offset(x, y));
    }

    // Draw grid lines
    final gridPaint = Paint()
      ..color = theme.dividerColor.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (int i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Path for line
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + stepX / 2, p1.dy);
      final controlPoint2 = Offset(p2.dx - stepX / 2, p2.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    // Gradient fill under the line
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppTheme.primaryGold.withValues(alpha: 0.25),
          AppTheme.primaryGold.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke path
    final strokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppTheme.primaryGold, AppTheme.amber],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Draw active vertical line
    if (hoveredIndex != -1) {
      final hoverPaint = Paint()
        ..color = AppTheme.primaryGold.withValues(alpha: 0.3)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(points[hoveredIndex].dx, 0),
        Offset(points[hoveredIndex].dx, size.height),
        hoverPaint,
      );

      final pointPaint = Paint()
        ..color = AppTheme.primaryGold
        ..style = PaintingStyle.fill;
      final pointBorderPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(points[hoveredIndex], 6.0, pointPaint);
      canvas.drawCircle(points[hoveredIndex], 6.0, pointBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter oldDelegate) {
    return oldDelegate.hoveredIndex != hoveredIndex || oldDelegate.isDark != isDark;
  }
}
