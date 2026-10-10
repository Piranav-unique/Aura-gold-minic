import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/admin/domain/wallet_models.dart';
import 'package:ags_gold/services/service_providers.dart';

class DeletedUserItem {
  final String id;
  final String fullName;
  final String email;
  final String? mobileNumber;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final String status;
  final double goldBalanceGrams;
  final double silverBalanceGrams;
  final double walletBalanceInr;
  final String kycStatus;

  const DeletedUserItem({
    required this.id,
    required this.fullName,
    required this.email,
    this.mobileNumber,
    required this.createdAt,
    this.deletedAt,
    required this.status,
    required this.goldBalanceGrams,
    required this.silverBalanceGrams,
    required this.walletBalanceInr,
    required this.kycStatus,
  });

  factory DeletedUserItem.fromJson(Map<String, dynamic> json) {
    return DeletedUserItem(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      status: json['status'] as String? ?? 'Deleted',
      goldBalanceGrams: parseWalletDecimal(json['gold_balance_grams']),
      silverBalanceGrams: parseWalletDecimal(json['silver_balance_grams']),
      walletBalanceInr: parseWalletDecimal(json['wallet_balance_inr']),
      kycStatus: json['kyc_status'] as String? ?? 'not_started',
    );
  }
}

class PaginatedDeletedUsers {
  final List<DeletedUserItem> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedDeletedUsers({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedDeletedUsers.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return PaginatedDeletedUsers(
      items: rawItems
          .map((e) => DeletedUserItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? 20,
    );
  }
}

class DeletedUserDetail {
  final String id;
  final String fullName;
  final String email;
  final String? mobileNumber;
  final DateTime createdAt;
  final DateTime? deletedAt;
  final DateTime? lastLoginAt;
  final String status;
  final String kycStatus;
  final String? kycAadhaarLast4;
  final String? kycPanLast4;
  final WalletSummary wallet;
  final List<WalletTransactionItem> transactions;

  const DeletedUserDetail({
    required this.id,
    required this.fullName,
    required this.email,
    this.mobileNumber,
    required this.createdAt,
    this.deletedAt,
    this.lastLoginAt,
    required this.status,
    required this.kycStatus,
    this.kycAadhaarLast4,
    this.kycPanLast4,
    required this.wallet,
    required this.transactions,
  });

  factory DeletedUserDetail.fromJson(Map<String, dynamic> json) {
    final txList = json['transactions'] as List<dynamic>? ?? [];
    return DeletedUserDetail(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'] as String)
          : null,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      status: json['status'] as String? ?? 'Deleted',
      kycStatus: json['kyc_status'] as String? ?? 'not_started',
      kycAadhaarLast4: json['kyc_aadhaar_last4'] as String?,
      kycPanLast4: json['kyc_pan_last4'] as String?,
      wallet: WalletSummary.fromJson(
        json['wallet'] as Map<String, dynamic>? ?? {},
      ),
      transactions: txList
          .map((t) => WalletTransactionItem.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

class DeletedUsersSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final deletedUsersSearchProvider =
    NotifierProvider<DeletedUsersSearchNotifier, String>(
  DeletedUsersSearchNotifier.new,
);

class DeletedUsersSortNotifier extends Notifier<String> {
  @override
  String build() => 'desc'; // 'desc' = Newest Deletion, 'asc' = Oldest Deletion
  void update(String value) => state = value;
}

final deletedUsersSortProvider =
    NotifierProvider<DeletedUsersSortNotifier, String>(
  DeletedUsersSortNotifier.new,
);

final deletedUsersPageProvider =
    NotifierProvider<DeletedUsersPageNotifier, int>(
  DeletedUsersPageNotifier.new,
);

class DeletedUsersPageNotifier extends Notifier<int> {
  @override
  int build() => 1;
  void update(int value) => state = value;
}

final deletedUsersListProvider = FutureProvider.autoDispose<PaginatedDeletedUsers>((ref) async {
  final api = ref.read(apiClientProvider);
  final search = ref.watch(deletedUsersSearchProvider);
  final sortOrder = ref.watch(deletedUsersSortProvider);
  final page = ref.watch(deletedUsersPageProvider);

  final queryParams = <String, dynamic>{
    'page': page,
    'limit': 20,
    'sort_order': sortOrder,
  };
  if (search.trim().isNotEmpty) {
    queryParams['search'] = search.trim();
  }

  final response = await api.get(
    '/admin/wallets/deleted-users',
    queryParameters: queryParams,
  );
  return PaginatedDeletedUsers.fromJson(response.data as Map<String, dynamic>);
});

final deletedUserDetailProvider = FutureProvider.autoDispose
    .family<DeletedUserDetail, String>((ref, userId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/admin/wallets/deleted-users/$userId');
  return DeletedUserDetail.fromJson(response.data as Map<String, dynamic>);
});
