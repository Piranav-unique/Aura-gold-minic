import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/widgets/premium_timeline.dart';
import 'package:ags_gold/core/widgets/premium_trend_chart.dart';
import 'package:ags_gold/features/dashboard/domain/executive_dashboard.dart';
import 'package:ags_gold/features/dashboard/presentation/widgets/dashboard_shared.dart';

class EmployeeExecutiveView extends StatelessWidget {
  final ExecutiveDashboard data;

  const EmployeeExecutiveView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final pendingCount = data.assignedTasks
        .where((t) => t.state == 'pending')
        .length;
    final draftCount = data.assignedTasks
        .where((t) => t.state == 'draft')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dashboardKpiGrid(context, [
          DashboardKpiCard(
            label: 'Assigned Tasks',
            value: '${data.assignedTasks.length}',
            trend: '$pendingCount pending approval',
            icon: Icons.task_alt_outlined,
            color: AppTheme.sapphireBlue,
          ),
          DashboardKpiCard(
            label: 'Drafts',
            value: '$draftCount',
            trend: 'Requests to submit',
            icon: Icons.edit_note_outlined,
            color: AppTheme.primaryGold,
          ),
          DashboardKpiCard(
            label: 'Activities Today',
            value: '${data.dailyActivities.length}',
            trend: 'Your recent actions',
            icon: Icons.history_outlined,
            color: AppTheme.emerald,
          ),
        ]),
        const SizedBox(height: 24),
        if (data.activityTrend.isNotEmpty)
          DashboardSection(
            title: 'Your Activity',
            child: PremiumTrendChart(
              title: 'Weekly Activity',
              subtitle: 'Your actions over the last 7 days',
              values: data.activityTrend
                  .map((p) => p.count.toDouble())
                  .toList(),
              labels: data.activityTrend.map((p) => p.label).toList(),
              lineColor: AppTheme.sapphireBlue,
            ),
          ),
        if (data.activityTrend.isNotEmpty) const SizedBox(height: 24),
        DashboardSection(
          title: 'Assigned Tasks',
          actionLabel: 'Workflows',
          onAction: () => context.go('/workflows'),
          child: Card(
            child: data.assignedTasks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const Text('No tasks assigned right now.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.push('/workflows/new'),
                          icon: const Icon(Icons.add),
                          label: const Text('Create request'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.assignedTasks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final task = data.assignedTasks[index];
                      return ListTile(
                        onTap: () => context.push('/workflows/${task.id}'),
                        leading: Icon(
                          task.state == 'pending'
                              ? Icons.hourglass_top_outlined
                              : Icons.edit_outlined,
                          color: task.state == 'pending'
                              ? Colors.orange
                              : AppTheme.sapphireBlue,
                        ),
                        title: Text(task.title),
                        subtitle: Text(
                          '${task.requestNumber} • ${task.requestType}',
                        ),
                        trailing: Chip(
                          label: Text(
                            task.state.toUpperCase(),
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 24),
        DashboardSection(
          title: 'Daily Activities',
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: data.dailyActivities.isEmpty
                  ? const Text('No activity recorded yet today.')
                  : PremiumTimeline(
                      entries: data.dailyActivities
                          .map(
                            (a) => TimelineEntry(
                              title: a.description,
                              subtitle: a.action.replaceAll('_', ' '),
                              timestamp: a.timestamp,
                              icon: Icons.circle_outlined,
                              color: AppTheme.emerald,
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
