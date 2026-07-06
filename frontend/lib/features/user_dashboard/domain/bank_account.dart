/// Maximum linked bank accounts per end-user (sell payout).
const int maxUserBankAccounts = 2;

class BankAccount {
  final String id;
  final String accountHolderName;
  final String accountNumberMasked;
  final String ifsc;
  final String bankName;
  final String branchName;
  final String accountType;
  final bool isPrimary;

  const BankAccount({
    required this.id,
    required this.accountHolderName,
    required this.accountNumberMasked,
    required this.ifsc,
    required this.bankName,
    required this.branchName,
    required this.accountType,
    required this.isPrimary,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'] as String,
      accountHolderName: json['account_holder_name'] as String,
      accountNumberMasked: json['account_number_masked'] as String,
      ifsc: json['ifsc'] as String,
      bankName: json['bank_name'] as String,
      branchName: json['branch_name'] as String,
      accountType: json['account_type'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
    );
  }
}

class IfscBranch {
  final String branch;
  final String ifsc;

  const IfscBranch({required this.branch, required this.ifsc});

  factory IfscBranch.fromJson(Map<String, dynamic> json) {
    return IfscBranch(
      branch: json['branch'] as String? ?? '',
      ifsc: json['ifsc'] as String? ?? '',
    );
  }
}
