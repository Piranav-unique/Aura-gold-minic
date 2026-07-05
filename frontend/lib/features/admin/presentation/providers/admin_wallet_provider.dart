import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/features/admin/domain/wallet_pagination.dart';
import 'package:ags_gold/services/service_providers.dart';

final walletUserSearchQueryProvider =
    NotifierProvider<WalletSearchQueryNotifier, String>(
  WalletSearchQueryNotifier.new,
);

class WalletSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
}

final walletUsersPageProvider = NotifierProvider<WalletUsersPageNotifier, int>(
  WalletUsersPageNotifier.new,
);

class WalletUsersPageNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void update(int value) => state = value;
}

final walletUsersLimitProvider = Provider<int>((ref) => 20);

final walletUsersListProvider =
    FutureProvider.autoDispose<PaginatedWalletUsers>((ref) async {
  final api = ref.read(apiClientProvider);
  final search = ref.watch(walletUserSearchQueryProvider);
  final page = ref.watch(walletUsersPageProvider);
  final limit = ref.watch(walletUsersLimitProvider);

  final response = await api.get(
    '/admin/wallets/users',
    queryParameters: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'page': page,
      'limit': limit,
    },
  );
  return PaginatedWalletUsers.fromJson(response.data as Map<String, dynamic>);
});

final walletUserDetailProvider = FutureProvider.autoDispose
    .family<WalletUserDetail, String>((ref, userId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/admin/wallets/users/$userId');
  return WalletUserDetail.fromJson(response.data as Map<String, dynamic>);
});

final walletUserTransactionsProvider = FutureProvider.autoDispose
    .family<PaginatedWalletTransactions, ({String userId, int page})>(
  (ref, query) async {
    final api = ref.read(apiClientProvider);
    final response = await api.get(
      '/admin/wallets/users/${query.userId}/transactions',
      queryParameters: {'page': query.page, 'limit': 20},
    );
    return PaginatedWalletTransactions.fromJson(
      response.data as Map<String, dynamic>,
    );
  },
);

class WalletTxnFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final walletTxnTypeFilterProvider =
    NotifierProvider<WalletTxnFilterNotifier, String?>(
  WalletTxnFilterNotifier.new,
);

final walletTxnMetalFilterProvider =
    NotifierProvider<WalletTxnFilterNotifier, String?>(
  WalletTxnFilterNotifier.new,
);

final walletTxnStatusFilterProvider =
    NotifierProvider<WalletTxnFilterNotifier, String?>(
  WalletTxnFilterNotifier.new,
);

final recentWalletTxnTypeFilterProvider =
    NotifierProvider<WalletTxnFilterNotifier, String?>(
  WalletTxnFilterNotifier.new,
);

final walletUserTransactionsFilteredProvider = FutureProvider.autoDispose.family<
    PaginatedWalletTransactions,
    ({
      String userId,
      int page,
      String? type,
      String? metal,
      String? status,
    })>((ref, query) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get(
    '/admin/wallets/users/${query.userId}/transactions',
    queryParameters: {
      'page': query.page,
      'limit': 20,
      if (query.type != null) 'type': query.type,
      if (query.metal != null) 'metal': query.metal,
      if (query.status != null) 'status': query.status,
    },
  );
  return PaginatedWalletTransactions.fromJson(
    response.data as Map<String, dynamic>,
  );
});

final recentWalletTransactionsPageProvider =
    NotifierProvider<RecentWalletTxnPageNotifier, int>(
  RecentWalletTxnPageNotifier.new,
);

class RecentWalletTxnPageNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void update(int value) => state = value;
}

final walletActivityUserSearchProvider =
    NotifierProvider<WalletSearchQueryNotifier, String>(
  WalletSearchQueryNotifier.new,
);

final walletActivityTimeRangeProvider =
    NotifierProvider<WalletActivityTimeRangeNotifier, WalletActivityTimeRange>(
  WalletActivityTimeRangeNotifier.new,
);

enum WalletActivityTimeRange { all, today, week, month }

class WalletActivityTimeRangeNotifier extends Notifier<WalletActivityTimeRange> {
  @override
  WalletActivityTimeRange build() => WalletActivityTimeRange.all;

  void update(WalletActivityTimeRange value) => state = value;
}

(DateTime?, DateTime?) walletActivityDateBounds(WalletActivityTimeRange range) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (range) {
    case WalletActivityTimeRange.today:
      return (today, today.add(const Duration(days: 1)));
    case WalletActivityTimeRange.week:
      return (today.subtract(const Duration(days: 6)), today.add(const Duration(days: 1)));
    case WalletActivityTimeRange.month:
      return (today.subtract(const Duration(days: 29)), today.add(const Duration(days: 1)));
    case WalletActivityTimeRange.all:
      return (null, null);
  }
}

String? _formatApiDate(DateTime? dt) {
  if (dt == null) return null;
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

final recentWalletTransactionsProvider =
    FutureProvider.autoDispose<PaginatedWalletTransactions>((ref) async {
  final api = ref.read(apiClientProvider);
  final page = ref.watch(recentWalletTransactionsPageProvider);
  final type = ref.watch(recentWalletTxnTypeFilterProvider);
  final metal = ref.watch(walletTxnMetalFilterProvider);
  final status = ref.watch(walletTxnStatusFilterProvider);
  final search = ref.watch(walletActivityUserSearchProvider);
  final timeRange = ref.watch(walletActivityTimeRangeProvider);
  final (from, toExclusive) = walletActivityDateBounds(timeRange);
  final toDate = toExclusive?.subtract(const Duration(days: 1));

  final response = await api.get(
    '/admin/wallets/transactions/recent',
    queryParameters: {
      'page': page,
      'limit': 20,
      'type': ?type,
      'metal': ?metal,
      'status': ?status,
      if (search.trim().isNotEmpty) 'search': search.trim(),
      if (from != null) 'from_date': _formatApiDate(from),
      if (toDate != null) 'to_date': _formatApiDate(toDate),
    },
  );
  return PaginatedWalletTransactions.fromJson(
    response.data as Map<String, dynamic>,
  );
});

final walletTransactionDetailProvider = FutureProvider.autoDispose
    .family<WalletTransactionDetail, String>((ref, transactionId) async {
  final api = ref.read(apiClientProvider);
  final encoded = Uri.encodeComponent(transactionId);
  final response = await api.get('/admin/wallets/transactions/$encoded');
  return WalletTransactionDetail.fromJson(
    response.data as Map<String, dynamic>,
  );
});
