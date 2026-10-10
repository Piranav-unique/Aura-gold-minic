import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/widgets/empty_state.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/deleted_users_provider.dart';

class DeletedUsersScreen extends ConsumerStatefulWidget {
  const DeletedUsersScreen({super.key});

  @override
  ConsumerState<DeletedUsersScreen> createState() => _DeletedUsersScreenState();
}

class _DeletedUsersScreenState extends ConsumerState<DeletedUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(deletedUsersSearchProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deletedUsersAsync = ref.watch(deletedUsersListProvider);
    final currentSort = ref.watch(deletedUsersSortProvider);
    final currentPage = ref.watch(deletedUsersPageProvider);
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    return ResponsiveNavigationWrapper(
      title: 'Deleted Users',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(deletedUsersListProvider);
          await ref.read(deletedUsersListProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // Header Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_off_rounded,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Archived Customer Records',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E1B18),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Read-only view of soft-deleted customer accounts, historical balances, and payment records.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(deletedUsersPageProvider.notifier).update(1);
                ref.read(deletedUsersSearchProvider.notifier).update(val);
              },
              decoration: InputDecoration(
                hintText: 'Search by name, email, phone, or ID...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(deletedUsersPageProvider.notifier).update(1);
                          ref.read(deletedUsersSearchProvider.notifier).update('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC59A27), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sort & Filter Controls
            Row(
              children: [
                const Text(
                  'Sort by Deletion:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Newest First'),
                  selected: currentSort == 'desc',
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(deletedUsersPageProvider.notifier).update(1);
                      ref.read(deletedUsersSortProvider.notifier).update('desc');
                    }
                  },
                  selectedColor: const Color(0xFFC59A27),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: currentSort == 'desc' ? Colors.white : const Color(0xFF334155),
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: currentSort == 'desc' ? const Color(0xFFC59A27) : const Color(0xFFE2E8F0),
                  ),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Oldest First'),
                  selected: currentSort == 'asc',
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(deletedUsersPageProvider.notifier).update(1);
                      ref.read(deletedUsersSortProvider.notifier).update('asc');
                    }
                  },
                  selectedColor: const Color(0xFFC59A27),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: currentSort == 'asc' ? Colors.white : const Color(0xFF334155),
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: currentSort == 'asc' ? const Color(0xFFC59A27) : const Color(0xFFE2E8F0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Deleted Users List
            deletedUsersAsync.when(
              loading: () => const _DeletedUsersListSkeleton(),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, size: 40, color: Color(0xFFDC2626)),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load deleted users: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(deletedUsersListProvider),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC59A27),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (paginated) {
                if (paginated.items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: EmptyStateWidget(
                      icon: Icons.person_off_outlined,
                      title: 'No Deleted Users Found',
                      subtitle: _searchController.text.isNotEmpty
                          ? 'No deleted accounts match "${_searchController.text}".'
                          : 'No deleted customer accounts exist in the system.',
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deleted Accounts (${paginated.total})',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...paginated.items.map((user) {
                      final deletionDateStr = user.deletedAt != null
                          ? dateFormat.format(user.deletedAt!.toLocal())
                          : 'Not recorded';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => context.push('/admin/deleted-users/${user.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row: Avatar + Name + "Deleted" Badge
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      child: Text(
                                        user.fullName.isNotEmpty
                                            ? user.fullName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF475569),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.fullName.isNotEmpty
                                                ? user.fullName
                                                : 'Unnamed Customer',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E1B18),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            user.email.isNotEmpty
                                                ? user.email
                                                : (user.mobileNumber ?? '—'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'DELETED',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 10),

                                // Customer ID with copy button
                                Row(
                                  children: [
                                    const Text(
                                      'Customer ID: ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        user.id,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E1B18),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: user.id));
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Customer ID copied to clipboard'),
                                            duration: Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(
                                          Icons.copy_rounded,
                                          size: 14,
                                          color: Color(0xFFC59A27),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Deletion Date
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Deleted on $deletionDateStr',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),

                                // Retained Balances Summary
                                if (user.goldBalanceGrams > 0 ||
                                    user.silverBalanceGrams > 0 ||
                                    user.walletBalanceInr > 0) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFAF7F2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFF1EAD9)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Retained: ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF78716C),
                                          ),
                                        ),
                                        if (user.goldBalanceGrams > 0)
                                          Text(
                                            '${user.goldBalanceGrams.toStringAsFixed(4)} g Gold  ',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFC59A27),
                                            ),
                                          ),
                                        if (user.silverBalanceGrams > 0)
                                          Text(
                                            '${user.silverBalanceGrams.toStringAsFixed(4)} g Silver  ',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        if (user.walletBalanceInr > 0)
                                          Text(
                                            currency.format(user.walletBalanceInr),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                    // Pagination footer if needed
                    if (paginated.total > 20) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: currentPage > 1
                                ? () => ref
                                    .read(deletedUsersPageProvider.notifier)
                                    .update(currentPage - 1)
                                : null,
                            child: const Text('Previous'),
                          ),
                          const SizedBox(width: 16),
                          Text('Page $currentPage'),
                          const SizedBox(width: 16),
                          OutlinedButton(
                            onPressed: (currentPage * 20) < paginated.total
                                ? () => ref
                                    .read(deletedUsersPageProvider.notifier)
                                    .update(currentPage + 1)
                                : null,
                            child: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DeletedUsersListSkeleton extends StatelessWidget {
  const _DeletedUsersListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  PremiumSkeleton(width: 40, height: 40),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        PremiumSkeleton(width: 140, height: 16),
                        SizedBox(height: 6),
                        PremiumSkeleton(width: 100, height: 12),
                      ],
                    ),
                  ),
                  PremiumSkeleton(width: 60, height: 22),
                ],
              ),
              const SizedBox(height: 12),
              const PremiumSkeleton(width: double.infinity, height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
