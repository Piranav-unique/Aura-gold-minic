class Customer {
  final String id;
  final String customerType;
  final String fullName;
  final String mobileNumber;
  final String email;
  final String address;
  final String? gstNumber;
  final String status;
  final int totalPurchases;
  final double totalRevenue;
  final DateTime? lastTransactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.customerType,
    required this.fullName,
    required this.mobileNumber,
    required this.email,
    required this.address,
    this.gstNumber,
    required this.status,
    required this.totalPurchases,
    required this.totalRevenue,
    this.lastTransactionDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      customerType: json['customer_type'] as String? ?? 'individual',
      fullName: json['full_name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String? ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      gstNumber: json['gst_number'] as String?,
      status: json['status'] as String? ?? 'active',
      totalPurchases: json['total_purchases'] as int? ?? 0,
      totalRevenue: _parseDecimal(json['total_revenue']),
      lastTransactionDate: json['last_transaction_date'] != null
          ? DateTime.parse(json['last_transaction_date'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'customer_type': customerType,
    'full_name': fullName,
    'mobile_number': mobileNumber,
    'email': email,
    'address': address,
    if (gstNumber != null && gstNumber!.isNotEmpty) 'gst_number': gstNumber,
    'status': status,
  };

  Map<String, dynamic> toUpdateJson() {
    final json = <String, dynamic>{
      'customer_type': customerType,
      'full_name': fullName,
      'mobile_number': mobileNumber,
      'email': email,
      'address': address,
      'status': status,
    };
    if (gstNumber != null && gstNumber!.isNotEmpty) {
      json['gst_number'] = gstNumber;
    }
    return json;
  }

  Customer copyWith({
    String? customerType,
    String? fullName,
    String? mobileNumber,
    String? email,
    String? address,
    String? gstNumber,
    String? status,
  }) {
    return Customer(
      id: id,
      customerType: customerType ?? this.customerType,
      fullName: fullName ?? this.fullName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
      status: status ?? this.status,
      totalPurchases: totalPurchases,
      totalRevenue: totalRevenue,
      lastTransactionDate: lastTransactionDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  String get displayType =>
      customerType == 'business' ? 'Business' : 'Individual';

  String get displayStatus {
    switch (status) {
      case 'inactive':
        return 'Inactive';
      case 'blacklisted':
        return 'Blacklisted';
      default:
        return 'Active';
    }
  }

  static double _parseDecimal(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class PaginatedCustomers {
  final List<Customer> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedCustomers({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedCustomers.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedCustomers(
      items: items,
      total: json['total'] as int? ?? items.length,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? items.length,
    );
  }
}

const customerTypeOptions = ['individual', 'business'];
const customerStatusOptions = ['active', 'inactive', 'blacklisted'];

const customerSortFields = [
  'full_name',
  'created_at',
  'total_revenue',
  'total_purchases',
  'last_transaction_date',
  'status',
  'customer_type',
];

/// Maps PremiumDataTable column index to API sort field.
const customerTableSortFields = <int, String>{
  0: 'full_name',
  1: 'customer_type',
  2: 'status',
  4: 'total_revenue',
  5: 'total_purchases',
  6: 'last_transaction_date',
};
