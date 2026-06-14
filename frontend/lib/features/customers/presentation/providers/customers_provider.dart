import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';
import 'package:ags_gold/services/service_providers.dart';

class CustomersSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String value) => state = value;
}

final customersSearchProvider =
    NotifierProvider<CustomersSearchNotifier, String>(
      CustomersSearchNotifier.new,
    );

class CustomersTypeFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final customersTypeFilterProvider =
    NotifierProvider<CustomersTypeFilterNotifier, String?>(
      CustomersTypeFilterNotifier.new,
    );

class CustomersStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final customersStatusFilterProvider =
    NotifierProvider<CustomersStatusFilterNotifier, String?>(
      CustomersStatusFilterNotifier.new,
    );

class CustomersSortFieldNotifier extends Notifier<String> {
  @override
  String build() => 'created_at';
  void update(String value) => state = value;
}

final customersSortFieldProvider =
    NotifierProvider<CustomersSortFieldNotifier, String>(
      CustomersSortFieldNotifier.new,
    );

class CustomersSortAscNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

final customersSortAscProvider =
    NotifierProvider<CustomersSortAscNotifier, bool>(
      CustomersSortAscNotifier.new,
    );

class CustomersSkipNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void update(int value) => state = value;
}

final customersSkipProvider = NotifierProvider<CustomersSkipNotifier, int>(
  CustomersSkipNotifier.new,
);

class CustomersLimitNotifier extends Notifier<int> {
  @override
  int build() => 25;
  void update(int value) => state = value;
}

final customersLimitProvider = NotifierProvider<CustomersLimitNotifier, int>(
  CustomersLimitNotifier.new,
);

final customersListProvider = FutureProvider.autoDispose<PaginatedCustomers>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final search = ref.watch(customersSearchProvider);
  final customerType = ref.watch(customersTypeFilterProvider);
  final status = ref.watch(customersStatusFilterProvider);
  final sortBy = ref.watch(customersSortFieldProvider);
  final sortOrder = ref.watch(customersSortAscProvider) ? 'asc' : 'desc';
  final skip = ref.watch(customersSkipProvider);
  final limit = ref.watch(customersLimitProvider);

  final params = <String, dynamic>{
    'skip': skip,
    'limit': limit,
    'sort_by': sortBy,
    'sort_order': sortOrder,
  };
  if (search.isNotEmpty) params['search'] = search;
  if (customerType != null) params['customer_type'] = customerType;
  if (status != null) params['status'] = status;

  final response = await apiClient.get('/customers/', queryParameters: params);
  return PaginatedCustomers.fromJson(response.data as Map<String, dynamic>);
});

final customerDetailProvider = FutureProvider.autoDispose
    .family<Customer, String>((ref, id) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.get('/customers/$id');
      return Customer.fromJson(response.data as Map<String, dynamic>);
    });

final createCustomerProvider = Provider<Future<Customer> Function(Customer)>((
  ref,
) {
  return (Customer customer) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post(
      '/customers/',
      data: customer.toCreateJson(),
    );
    ref.invalidate(customersListProvider);
    return Customer.fromJson(response.data as Map<String, dynamic>);
  };
});

final updateCustomerProvider = Provider<Future<Customer> Function(Customer)>((
  ref,
) {
  return (Customer customer) async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.put(
      '/customers/${customer.id}',
      data: customer.toUpdateJson(),
    );
    ref.invalidate(customersListProvider);
    ref.invalidate(customerDetailProvider(customer.id));
    return Customer.fromJson(response.data as Map<String, dynamic>);
  };
});

final deleteCustomerProvider = Provider<Future<void> Function(String)>((ref) {
  return (String id) async {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.delete('/customers/$id');
    ref.invalidate(customersListProvider);
  };
});
