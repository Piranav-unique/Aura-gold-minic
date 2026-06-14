import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/transactions/domain/transaction.dart';
import 'package:ags_gold/services/service_providers.dart';

class TransactionsSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final transactionsSearchProvider =
    NotifierProvider<TransactionsSearchNotifier, String>(
      TransactionsSearchNotifier.new,
    );

class TransactionsTypeFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final transactionsTypeFilterProvider =
    NotifierProvider<TransactionsTypeFilterNotifier, String?>(
      TransactionsTypeFilterNotifier.new,
    );

class TransactionsPaymentFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final transactionsPaymentFilterProvider =
    NotifierProvider<TransactionsPaymentFilterNotifier, String?>(
      TransactionsPaymentFilterNotifier.new,
    );

class TransactionsStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final transactionsStatusFilterProvider =
    NotifierProvider<TransactionsStatusFilterNotifier, String?>(
      TransactionsStatusFilterNotifier.new,
    );

class TransactionsSortFieldNotifier extends Notifier<String> {
  @override
  String build() => 'created_at';
  void update(String value) => state = value;
}

final transactionsSortFieldProvider =
    NotifierProvider<TransactionsSortFieldNotifier, String>(
      TransactionsSortFieldNotifier.new,
    );

class TransactionsSortAscNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final transactionsSortAscProvider =
    NotifierProvider<TransactionsSortAscNotifier, bool>(
      TransactionsSortAscNotifier.new,
    );

class TransactionsSkipNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void update(int value) => state = value;
}

final transactionsSkipProvider =
    NotifierProvider<TransactionsSkipNotifier, int>(
      TransactionsSkipNotifier.new,
    );

class TransactionsLimitNotifier extends Notifier<int> {
  @override
  int build() => 25;
  void update(int value) => state = value;
}

final transactionsLimitProvider =
    NotifierProvider<TransactionsLimitNotifier, int>(
      TransactionsLimitNotifier.new,
    );

final transactionsListProvider =
    FutureProvider.autoDispose<PaginatedTransactions>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      final search = ref.watch(transactionsSearchProvider);
      final transactionType = ref.watch(transactionsTypeFilterProvider);
      final paymentStatus = ref.watch(transactionsPaymentFilterProvider);
      final status = ref.watch(transactionsStatusFilterProvider);
      final sortBy = ref.watch(transactionsSortFieldProvider);
      final sortOrder = ref.watch(transactionsSortAscProvider) ? 'asc' : 'desc';
      final skip = ref.watch(transactionsSkipProvider);
      final limit = ref.watch(transactionsLimitProvider);

      final params = <String, dynamic>{
        'skip': skip,
        'limit': limit,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      if (search.isNotEmpty) params['search'] = search;
      if (transactionType != null) params['transaction_type'] = transactionType;
      if (paymentStatus != null) params['payment_status'] = paymentStatus;
      if (status != null) params['status'] = status;

      final response = await apiClient.get(
        '/transactions/',
        queryParameters: params,
      );
      return PaginatedTransactions.fromJson(
        response.data as Map<String, dynamic>,
      );
    });

final transactionDetailProvider = FutureProvider.autoDispose
    .family<Transaction, String>((ref, id) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get('/transactions/$id');
      return Transaction.fromJson(response.data as Map<String, dynamic>);
    });

final transactionMetricsProvider =
    FutureProvider.autoDispose<TransactionMetrics>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get('/transactions/metrics');
      return TransactionMetrics.fromJson(response.data as Map<String, dynamic>);
    });

final createTransactionProvider =
    Provider<Future<Transaction> Function(Transaction)>((ref) {
      return (Transaction txn) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.post(
          '/transactions/',
          data: txn.toCreateJson(),
        );
        ref.invalidate(transactionsListProvider);
        ref.invalidate(transactionMetricsProvider);
        return Transaction.fromJson(response.data as Map<String, dynamic>);
      };
    });

final updateTransactionProvider =
    Provider<Future<Transaction> Function(Transaction)>((ref) {
      return (Transaction txn) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.put(
          '/transactions/${txn.id}',
          data: txn.toUpdateJson(),
        );
        ref.invalidate(transactionsListProvider);
        ref.invalidate(transactionDetailProvider(txn.id));
        ref.invalidate(transactionMetricsProvider);
        return Transaction.fromJson(response.data as Map<String, dynamic>);
      };
    });

final cancelTransactionProvider =
    Provider<Future<Transaction> Function(String, String)>((ref) {
      return (String id, String reason) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.post(
          '/transactions/$id/cancel',
          data: {'reason': reason},
        );
        ref.invalidate(transactionsListProvider);
        ref.invalidate(transactionDetailProvider(id));
        ref.invalidate(transactionMetricsProvider);
        return Transaction.fromJson(response.data as Map<String, dynamic>);
      };
    });

final generateInvoiceProvider =
    Provider<Future<TransactionDocument> Function(String)>((ref) {
      return (String id) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.get('/transactions/$id/invoice');
        ref.invalidate(transactionDetailProvider(id));
        return TransactionDocument.fromJson(
          response.data as Map<String, dynamic>,
        );
      };
    });

final generateReceiptProvider =
    Provider<Future<TransactionDocument> Function(String)>((ref) {
      return (String id) async {
        final apiClient = ref.read(apiClientProvider);
        final response = await apiClient.get('/transactions/$id/receipt');
        ref.invalidate(transactionDetailProvider(id));
        return TransactionDocument.fromJson(
          response.data as Map<String, dynamic>,
        );
      };
    });
