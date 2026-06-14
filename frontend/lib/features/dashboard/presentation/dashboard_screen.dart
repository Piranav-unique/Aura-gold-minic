import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/auth/executive_role.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/dashboard/presentation/providers/executive_dashboard_provider.dart';
import 'package:ags_gold/features/dashboard/presentation/widgets/admin_executive_view.dart';
import 'package:ags_gold/features/dashboard/presentation/widgets/dashboard_shared.dart';
import 'package:ags_gold/features/dashboard/presentation/widgets/employee_executive_view.dart';
import 'package:ags_gold/features/dashboard/presentation/widgets/manager_executive_view.dart';
import 'package:ags_gold/services/service_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting(String name) {
    final hour = DateTime.now().hour;
    final salutation = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return '$salutation, $name';
  }

  String _subtitle(ExecutiveRole role) {
    switch (role) {
      case ExecutiveRole.admin:
        return 'Executive overview across revenue, customers, inventory, and transactions.';
      case ExecutiveRole.manager:
        return 'Monitor team performance, approval queues, and inventory risk.';
      case ExecutiveRole.employee:
        return 'Your assigned tasks and daily activity at a glance.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final executiveAsync = ref.watch(executiveDashboardProvider);
    final profile = ref.watch(profileProvider).value;
    final role = profile != null
        ? resolveExecutiveRole(profile)
        : ExecutiveRole.employee;

    return ResponsiveNavigationWrapper(
      title: 'Executive Dashboard',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(executiveDashboardProvider);
          await ref.read(executiveDashboardProvider.future);
        },
        child: executiveAsync.when(
          data: (data) {
            final resolvedRole = ExecutiveRole.values.firstWhere(
              (r) => r.name == data.role,
              orElse: () => role,
            );
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardHero(
                    greeting: _greeting(data.displayName),
                    subtitle: _subtitle(resolvedRole),
                    roleLabel: executiveRoleLabel(resolvedRole),
                    unreadNotifications: data.unreadNotifications,
                    refreshedAt: data.refreshedAt,
                  ),
                  const SizedBox(height: 24),
                  switch (resolvedRole) {
                    ExecutiveRole.admin => AdminExecutiveView(data: data),
                    ExecutiveRole.manager => ManagerExecutiveView(data: data),
                    ExecutiveRole.employee => EmployeeExecutiveView(data: data),
                  },
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: PremiumSkeletonList(itemCount: 6),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text('Failed to load dashboard: $error'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(executiveDashboardProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
