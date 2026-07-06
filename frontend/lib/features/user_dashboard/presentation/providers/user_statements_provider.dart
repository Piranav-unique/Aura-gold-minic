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
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get(
    '/profile/statements',
    queryParameters: const {'limit': 100},
  );
  final data = response.data as Map<String, dynamic>;
  final items = (data['items'] as List<dynamic>? ?? [])
      .map(
        (item) => WalletTransactionItem.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .toList();
  return UserStatementsPage(
    items: items,
    total: data['total'] as int? ?? items.length,
  );
});
