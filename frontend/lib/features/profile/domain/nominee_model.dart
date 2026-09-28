class NomineeModel {
  final String fullName;
  final String relationship;
  final String dateOfBirth;
  final String phone;
  final int allocation;
  final bool isVerified;

  const NomineeModel({
    required this.fullName,
    required this.relationship,
    required this.dateOfBirth,
    required this.phone,
    this.allocation = 100,
    this.isVerified = true,
  });

  factory NomineeModel.defaultNominee() {
    return const NomineeModel(
      fullName: 'Kavitha S',
      relationship: 'Spouse',
      dateOfBirth: '14 May 1994',
      phone: '+91 98765 43210',
      allocation: 100,
      isVerified: true,
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'relationship': relationship,
        'dateOfBirth': dateOfBirth,
        'phone': phone,
        'allocation': allocation,
        'isVerified': isVerified,
      };

  factory NomineeModel.fromJson(Map<String, dynamic> json) {
    return NomineeModel(
      fullName: json['fullName'] as String? ?? 'Kavitha S',
      relationship: json['relationship'] as String? ?? 'Spouse',
      dateOfBirth: json['dateOfBirth'] as String? ?? '14 May 1994',
      phone: json['phone'] as String? ?? '+91 98765 43210',
      allocation: (json['allocation'] as num?)?.toInt() ?? 100,
      isVerified: json['isVerified'] as bool? ?? true,
    );
  }

  NomineeModel copyWith({
    String? fullName,
    String? relationship,
    String? dateOfBirth,
    String? phone,
    int? allocation,
    bool? isVerified,
  }) {
    return NomineeModel(
      fullName: fullName ?? this.fullName,
      relationship: relationship ?? this.relationship,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      phone: phone ?? this.phone,
      allocation: allocation ?? this.allocation,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}
