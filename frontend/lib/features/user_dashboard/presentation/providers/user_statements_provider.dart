import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/services/service_providers.dart';

class UserStatementsPage {
  final List<WalletTransactionItem> items;
  final int total;

  const UserStatementsPage({
    required this.items,
    required this.total,
  });
}

final userStatementsProvider =
    FutureProvider.autoDispose<UserStatementsPage>((ref) async {
  final auth = await ref.watch(authNotifierProvider.future);
  if (auth != AuthStatus.authenticated) {
    throw StateError('Not authenticated');
  }
  final apiClient = ref.read(apiClientProvider);
  const pageSize = 100;
  final allItems = <WalletTransactionItem>[];
  var skip = 0;
  var total = 0;

  while (true) {
    final response = await apiClient.get(
      '/profile/statements',
      queryParameters: {'skip': skip, 'limit': pageSize},
    );
    final data = response.data as Map<String, dynamic>;
    final pageItems = (data['items'] as List<dynamic>? ?? [])
        .map(
          (item) => WalletTransactionItem.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
    total = data['total'] as int? ?? (skip + pageItems.length);
    allItems.addAll(pageItems);

    if (pageItems.length < pageSize || allItems.length >= total) {
      break;
    }
    skip += pageSize;
  }

  return UserStatementsPage(
    items: allItems,
    total: total,
  );
});
