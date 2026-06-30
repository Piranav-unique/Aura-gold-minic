import 'package:ags_gold/features/admin/domain/wallet_models.dart';

class PaginatedWalletUsers {
  final List<WalletUserSearchItem> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedWalletUsers({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedWalletUsers.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? [];
    return PaginatedWalletUsers(
      items: raw
          .map((e) => WalletUserSearchItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
    );
  }
}

class PaginatedWalletTransactions {
  final List<WalletTransactionItem> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedWalletTransactions({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedWalletTransactions.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? [];
    return PaginatedWalletTransactions(
      items: raw
          .map(
            (e) => WalletTransactionItem.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      total: json['total'] as int? ?? 0,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
    );
  }
}
