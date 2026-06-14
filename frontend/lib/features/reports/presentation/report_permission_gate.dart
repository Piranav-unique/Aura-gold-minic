import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/services/service_providers.dart';

class ReportPermissionGate extends ConsumerWidget {
  final Widget child;

  const ReportPermissionGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return profileAsync.when(
      data: (profile) {
        if (!hasPermission(profile, 'report.view')) {
          return EmptyStateWidget(
            icon: Icons.lock_outline,
            title: 'Access denied',
            subtitle: 'You need report.view to access reports and analytics.',
            actionLabel: 'Back to dashboard',
            onAction: () => context.go('/dashboard'),
          );
        }
        return child;
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Unable to verify permissions',
        actionLabel: 'Back to dashboard',
        onAction: () => context.go('/dashboard'),
      ),
    );
  }
}
