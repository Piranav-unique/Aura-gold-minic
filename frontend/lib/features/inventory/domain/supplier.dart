class Supplier {
  final String id;
  final String name;
  final String? contactPerson;
  final String? mobileNumber;
  final String? email;
  final String? address;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Supplier({
    required this.id,
    required this.name,
    this.contactPerson,
    this.mobileNumber,
    this.email,
    this.address,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      contactPerson: json['contact_person'] as String?,
      mobileNumber: json['mobile_number'] as String?,
      email: json['email'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toCreateJson() => {
    'name': name,
    if (contactPerson != null && contactPerson!.isNotEmpty)
      'contact_person': contactPerson,
    if (mobileNumber != null && mobileNumber!.isNotEmpty)
      'mobile_number': mobileNumber,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (address != null && address!.isNotEmpty) 'address': address,
    'is_active': isActive,
  };

  Map<String, dynamic> toUpdateJson() => toCreateJson();

  Supplier copyWith({
    String? name,
    String? contactPerson,
    String? mobileNumber,
    String? email,
    String? address,
    bool? isActive,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class PaginatedSuppliers {
  final List<Supplier> items;
  final int total;
  final int skip;
  final int limit;

  const PaginatedSuppliers({
    required this.items,
    required this.total,
    required this.skip,
    required this.limit,
  });

  factory PaginatedSuppliers.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List<dynamic>? ?? [])
        .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
        .toList();
    return PaginatedSuppliers(
      items: items,
      total: json['total'] as int? ?? items.length,
      skip: json['skip'] as int? ?? 0,
      limit: json['limit'] as int? ?? items.length,
    );
  }
}
