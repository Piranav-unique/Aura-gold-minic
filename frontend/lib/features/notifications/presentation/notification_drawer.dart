import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/filter_chip_bar.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/features/notifications/presentation/providers/notifications_provider.dart';

class NotificationDrawer extends ConsumerWidget {
  const NotificationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsListProvider);
    final category = ref.watch(notificationCategoryFilterProvider);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM d • HH:mm');

    return Drawer(
      width: 400,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notifications',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(markNotificationsReadProvider)(
                        markAll: true,
                      );
                    },
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilterChipBar(
                options: const ['system', 'security'],
                selected: category,
                onSelected: (v) => ref
                    .read(notificationCategoryFilterProvider.notifier)
                    .update(v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: notificationsAsync.when(
                data: (result) {
                  if (result.items.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.notifications_none,
                      title: 'No notifications',
                      subtitle: 'You are all caught up.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.refresh(notificationsListProvider.future),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: result.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final n = result.items[index];
                        return Material(
                          color: n.isRead
                              ? theme.cardColor
                              : theme.colorScheme.primaryContainer.withValues(
                                  alpha: 0.35,
                                ),
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            leading: Icon(
                              n.category == 'security'
                                  ? Icons.shield_outlined
                                  : Icons.info_outline,
                              color: n.category == 'security'
                                  ? Colors.redAccent
                                  : theme.colorScheme.primary,
                            ),
                            title: Text(
                              n.title,
                              style: TextStyle(
                                fontWeight: n.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.message),
                                const SizedBox(height: 4),
                                Text(
                                  dateFormat.format(n.createdAt),
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: n.isRead
                                ? null
                                : const Icon(Icons.circle, size: 10),
                            onTap: () async {
                              if (!n.isRead) {
                                await ref.read(markNotificationsReadProvider)(
                                  ids: [n.id],
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: PremiumSkeletonList(itemCount: 6),
                ),
                error: (e, _) => EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Failed to load',
                  subtitle: e.toString(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(unreadNotificationsCountProvider);

    void openDrawer() {
      final scaffold = Scaffold.maybeOf(context);
      if (scaffold?.hasEndDrawer ?? false) {
        scaffold!.openEndDrawer();
      }
    }

    final count = unreadAsync.value;
    final hasValue = unreadAsync.hasValue;

    return IconButton(
      icon: Badge(
        isLabelVisible: hasValue && count != null && count > 0,
        label: Text('$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: openDrawer,
      tooltip: 'Notifications',
    );
  }
}
