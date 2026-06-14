import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/auth/permission_utils.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/services/service_providers.dart';

class WorkflowPermissionGate extends ConsumerWidget {
  final String requiredPermission;
  final Widget child;
  final String deniedTitle;
  final String deniedSubtitle;

  const WorkflowPermissionGate({
    super.key,
    required this.requiredPermission,
    required this.child,
    this.deniedTitle = 'Access denied',
    this.deniedSubtitle = 'You do not have permission to view this page.',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) {
        if (!hasPermission(profile, requiredPermission)) {
          return EmptyStateWidget(
            icon: Icons.lock_outline,
            title: deniedTitle,
            subtitle: deniedSubtitle,
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
