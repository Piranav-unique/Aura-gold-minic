class TransactionLine {
  final String id;
  final String inventoryItemId;
  final String itemName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String stockDirection;

  const TransactionLine({
    required this.id,
    required this.inventoryItemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.stockDirection,
  });

  factory TransactionLine.fromJson(Map<String, dynamic> json) {
    return TransactionLine(
      id: json['id'] as String,
      inventoryItemId: json['inventory_item_id'] as String,
      itemName: json['item_name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: _parseDecimal(json['unit_price']),
      lineTotal: _parseDecimal(json['line_total']),
      stockDirection: json['stock_direction'] as String? ?? 'out',
    );
  }

  Map<String, dynamic> toCreateJson({String? stockDirection}) {
    final payload = <String, dynamic>{
      'inventory_item_id': inventoryItemId,
      'quantity': quantity,
      'unit_price': unitPrice.toStringAsFixed(2),
    };
    if (stockDirection != null) {
      payload['stock_direction'] = stockDirection;
    }
    return payload;
  }
}

class TransactionCustomerSummary {
  final String id;
  final String fullName;
  final String mobileNumber;
  final String? email;

  const TransactionCustomerSummary({
    required this.id,
    required this.fullName,
    required this.mobileNumber,
    this.email,
  });

  factory TransactionCustomerSummary.fromJson(Map<String, dynamic> json) {
    return TransactionCustomerSummary(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

class Transaction {
  final String id;
  final String transactionNumber;
  final String transactionType;
  final String? customerId;
  final TransactionCustomerSummary? customer;
  final String status;
  final String paymentStatus;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final String? invoiceNumber;
  final String? receiptNumber;
  final bool stockApplied;
  final String? notes;
  final String? performedBy;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final List<TransactionLine> lines;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transaction({
    required this.id,
    required this.transactionNumber,
    required this.transactionType,
    this.customerId,
    this.customer,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    this.invoiceNumber,
    this.receiptNumber,
    required this.stockApplied,
    this.notes,
    this.performedBy,
    this.cancelledAt,
    this.cancellationReason,
    this.lines = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCancelled => status == 'cancelled';
  bool get isPaid => paymentStatus == 'paid';

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      transactionNumber: json['transaction_number'] as String? ?? '',
      transactionType: json['transaction_type'] as String? ?? 'sale',
      customerId: json['customer_id'] as String?,
      customer: json['customer'] != null
          ? TransactionCustomerSummary.fromJson(
              json['customer'] as Map<String, dynamic>,
            )
          : null,
      status: json['status'] as String? ?? 'active',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      subtotal: _parseDecimal(json['subtotal']),
      taxAmount: _parseDecimal(json['tax_amount']),
      totalAmount: _parseDecimal(json['total_amount']),
      invoiceNumber: json['invoice_number'] as String?,
      receiptNumber: json['receipt_number'] as String?,
      stockApplied: json['stock_applied'] as bool? ?? false,
      notes: json['notes'] as String?,
      performedBy: json['performed_by'] as String?,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancellationReason: json['cancellation_reason'] as String?,
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map((e) => TransactionLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'transaction_type': transactionType,
    if (customerId != null && customerId!.isNotEmpty) 'customer_id': customerId,
    'payment_status': paymentStatus,
    'tax_amount': taxAmount.toStringAsFixed(2),
    if (notes != null && notes!.isNotEmpty) 'notes': notes,
    'lines': lines
        .map(
          (line) => line.toCreateJson(
            stockDirection: transactionType == 'exchange'
                ? line.stockDirection
                : null,
          ),
        )
        .toList(),
  };

  Map<String, dynamic> toUpdateJson() => {
    if (customerId != null) 'customer_id': customerId,
    'payment_status': paymentStatus,
    'tax_amount': taxAmount.toStringAsFixed(2),
    if (notes != null) 'notes': notes,
    'lines': lines
        .map(
          (line) => line.toCreateJson(
            stockDirection: transactionType == 'exchange'
                ? line.stockDirection
                : null,
          ),
        )
        .toList(),
  };
}

class PaginatedTransactions {
  final List<Transaction> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedTransactions({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedTransactions.fromJson(Map<String, dynamic> json) {
    return PaginatedTransactions(
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? 0,
    );
  }
}

class TransactionDocument {
  final String documentType;
  final String documentNumber;
  final String transactionId;
  final String transactionNumber;
  final String transactionType;
  final String? customerName;
  final String? customerMobile;
  final String paymentStatus;
  final double subtotal;
  final double taxAmount;
  final double totalAmount;
  final DateTime issuedAt;
  final List<TransactionLine> lines;

  const TransactionDocument({
    required this.documentType,
    required this.documentNumber,
    required this.transactionId,
    required this.transactionNumber,
    required this.transactionType,
    this.customerName,
    this.customerMobile,
    required this.paymentStatus,
    required this.subtotal,
    required this.taxAmount,
    required this.totalAmount,
    required this.issuedAt,
    this.lines = const [],
  });

  factory TransactionDocument.fromJson(Map<String, dynamic> json) {
    return TransactionDocument(
      documentType: json['document_type'] as String? ?? 'invoice',
      documentNumber: json['document_number'] as String? ?? '',
      transactionId: json['transaction_id'] as String,
      transactionNumber: json['transaction_number'] as String? ?? '',
      transactionType: json['transaction_type'] as String? ?? '',
      customerName: json['customer_name'] as String?,
      customerMobile: json['customer_mobile'] as String?,
      paymentStatus: json['payment_status'] as String? ?? '',
      subtotal: _parseDecimal(json['subtotal']),
      taxAmount: _parseDecimal(json['tax_amount']),
      totalAmount: _parseDecimal(json['total_amount']),
      issuedAt: DateTime.parse(json['issued_at'] as String),
      lines: (json['lines'] as List<dynamic>? ?? [])
          .map(
            (e) => TransactionLine.fromJson({
              ...e as Map<String, dynamic>,
              'id': e['id'] ?? '',
              'inventory_item_id': e['inventory_item_id'] ?? '',
            }),
          )
          .toList(),
    );
  }
}

class TopCustomerMetric {
  final String customerId;
  final String fullName;
  final double revenue;
  final int transactionCount;

  const TopCustomerMetric({
    required this.customerId,
    required this.fullName,
    required this.revenue,
    required this.transactionCount,
  });

  factory TopCustomerMetric.fromJson(Map<String, dynamic> json) {
    return TopCustomerMetric(
      customerId: json['customer_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      revenue: _parseDecimal(json['revenue']),
      transactionCount: json['transaction_count'] as int? ?? 0,
    );
  }
}

class TransactionMetrics {
  final double dailyRevenue;
  final double monthlyRevenue;
  final List<TopCustomerMetric> topCustomers;

  const TransactionMetrics({
    required this.dailyRevenue,
    required this.monthlyRevenue,
    this.topCustomers = const [],
  });

  factory TransactionMetrics.fromJson(Map<String, dynamic> json) {
    return TransactionMetrics(
      dailyRevenue: _parseDecimal(json['daily_revenue']),
      monthlyRevenue: _parseDecimal(json['monthly_revenue']),
      topCustomers: (json['top_customers'] as List<dynamic>? ?? [])
          .map((e) => TopCustomerMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

double _parseDecimal(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

const transactionTypes = ['purchase', 'sale', 'return', 'exchange'];
const paymentStatuses = ['pending', 'paid', 'failed', 'refunded'];
const transactionStatuses = ['active', 'cancelled'];

const transactionTableSortFields = {
  0: 'transaction_number',
  1: 'transaction_type',
  2: 'total_amount',
  3: 'payment_status',
  4: 'status',
  5: 'created_at',
};

String transactionTypeLabel(String type) {
  switch (type) {
    case 'purchase':
      return 'Purchase';
    case 'sale':
      return 'Sale';
    case 'return':
      return 'Return';
    case 'exchange':
      return 'Exchange';
    default:
      return type;
  }
}

String paymentStatusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'paid':
      return 'Paid';
    case 'failed':
      return 'Failed';
    case 'refunded':
      return 'Refunded';
    default:
      return status;
  }
}
