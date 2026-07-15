import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/features/user_dashboard/domain/bank_account.dart';
import 'package:ags_gold/services/service_providers.dart';

final bankAccountsProvider = FutureProvider.autoDispose<List<BankAccount>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/bank-accounts');
  final data = response.data as List<dynamic>;
  return data
      .map((item) => BankAccount.fromJson(item as Map<String, dynamic>))
      .toList();
});

final ifscBanksProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/bank-accounts/ifsc/banks');
  final data = response.data as Map<String, dynamic>;
  return data.map((key, value) => MapEntry(key, value.toString()));
});

final ifscStatesProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, bank) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/bank-accounts/ifsc/banks/${Uri.encodeComponent(bank)}/states');
  return (response.data as List<dynamic>).map((e) => e.toString()).toList();
});

final ifscDistrictsProvider = FutureProvider.autoDispose
    .family<List<String>, ({String bank, String state})>((ref, args) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(
    '/bank-accounts/ifsc/banks/${Uri.encodeComponent(args.bank)}/states/${Uri.encodeComponent(args.state)}/districts',
  );
  return (response.data as List<dynamic>).map((e) => e.toString()).toList();
});

final ifscBranchesProvider = FutureProvider.autoDispose.family<List<IfscBranch>,
    ({String bank, String state, String district})>((ref, args) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get(
    '/bank-accounts/ifsc/banks/${Uri.encodeComponent(args.bank)}/states/${Uri.encodeComponent(args.state)}/districts/${Uri.encodeComponent(args.district)}/branches',
  );
  final data = response.data as List<dynamic>;
  return data
      .map((item) => IfscBranch.fromJson(item as Map<String, dynamic>))
      .toList();
});

final bankLinkProvider = Provider((ref) {
  final api = ref.watch(apiClientProvider);

  return ({
    required String accountHolderName,
    required String accountNumber,
    required String bankRegisteredMobile,
    required String ifsc,
    required String bankName,
    required String branchName,
    required String accountType,
  }) async {
    final response = await api.post(
      '/bank-accounts/link/initiate',
      data: {
        'account_holder_name': accountHolderName,
        'account_number': accountNumber,
        'bank_registered_mobile': bankRegisteredMobile,
        'ifsc': ifsc,
        'bank_name': bankName,
        'branch_name': branchName,
        'account_type': accountType,
      },
    );
    final data = response.data as Map<String, dynamic>;
    return (
      mobileLast4: data['mobile_last4'] as String?,
      message: data['message'] as String? ?? '',
      devOtpHint: data['dev_otp_hint'] as String?,
    );
  };
});

final bankLinkVerifyProvider = Provider((ref) {
  final api = ref.watch(apiClientProvider);

  return ({required String otp}) async {
    final response = await api.post(
      '/bank-accounts/link/verify',
      data: {'otp': otp},
    );
    return BankAccount.fromJson(response.data as Map<String, dynamic>);
  };
});
