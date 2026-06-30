import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/services/service_providers.dart';

class OrganizationContact {
  final String organizationName;
  final String adminName;
  final String supportContactNumber;
  final String? supportEmail;
  final String? officeAddress;
  final String? businessHours;
  final String? emergencyContact;

  const OrganizationContact({
    required this.organizationName,
    required this.adminName,
    required this.supportContactNumber,
    this.supportEmail,
    this.officeAddress,
    this.businessHours,
    this.emergencyContact,
  });

  factory OrganizationContact.fromJson(Map<String, dynamic> json) {
    return OrganizationContact(
      organizationName: json['organization_name'] as String? ?? 'AGS Gold',
      adminName: json['admin_name'] as String? ?? 'Support',
      supportContactNumber: json['support_contact_number'] as String? ?? '',
      supportEmail: json['support_email'] as String?,
      officeAddress: json['office_address'] as String?,
      businessHours: json['business_hours'] as String?,
      emergencyContact: json['emergency_contact'] as String?,
    );
  }
}

class OrganizationProfileFull extends OrganizationContact {
  final String id;
  final String? businessGst;
  final String? businessPan;
  final String? upiId;
  final String? googlePayId;
  final String? phonepeId;
  final String? paytmId;
  final String? bankName;
  final String? accountNumber;
  final String? ifsc;

  const OrganizationProfileFull({
    required this.id,
    required super.organizationName,
    required super.adminName,
    required super.supportContactNumber,
    super.supportEmail,
    super.officeAddress,
    super.businessHours,
    super.emergencyContact,
    this.businessGst,
    this.businessPan,
    this.upiId,
    this.googlePayId,
    this.phonepeId,
    this.paytmId,
    this.bankName,
    this.accountNumber,
    this.ifsc,
  });

  factory OrganizationProfileFull.fromJson(Map<String, dynamic> json) {
    return OrganizationProfileFull(
      id: '${json['id']}',
      organizationName: json['organization_name'] as String? ?? '',
      adminName: json['admin_name'] as String? ?? '',
      supportContactNumber: json['support_contact_number'] as String? ?? '',
      supportEmail: json['support_email'] as String?,
      officeAddress: json['office_address'] as String?,
      businessGst: json['business_gst'] as String?,
      businessPan: json['business_pan'] as String?,
      upiId: json['upi_id'] as String?,
      googlePayId: json['google_pay_id'] as String?,
      phonepeId: json['phonepe_id'] as String?,
      paytmId: json['paytm_id'] as String?,
      bankName: json['bank_name'] as String?,
      accountNumber: json['account_number'] as String?,
      ifsc: json['ifsc'] as String?,
      businessHours: json['business_hours'] as String?,
      emergencyContact: json['emergency_contact'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'organization_name': organizationName,
        'admin_name': adminName,
        'support_contact_number': supportContactNumber,
        'support_email': supportEmail,
        'office_address': officeAddress,
        'business_gst': businessGst,
        'business_pan': businessPan,
        'upi_id': upiId,
        'google_pay_id': googlePayId,
        'phonepe_id': phonepeId,
        'paytm_id': paytmId,
        'bank_name': bankName,
        'account_number': accountNumber,
        'ifsc': ifsc,
        'business_hours': businessHours,
        'emergency_contact': emergencyContact,
      };
}

final organizationContactProvider =
    FutureProvider.autoDispose<OrganizationContact>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/organization-profile');
  return OrganizationContact.fromJson(response.data as Map<String, dynamic>);
});

final organizationProfileAdminProvider =
    FutureProvider.autoDispose<OrganizationProfileFull>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/admin/organization-profile');
  return OrganizationProfileFull.fromJson(response.data as Map<String, dynamic>);
});

final updateOrganizationProfileProvider = Provider((ref) {
  final api = ref.read(apiClientProvider);
  return (OrganizationProfileFull profile) async {
    final response = await api.put(
      '/admin/organization-profile',
      data: profile.toJson(),
    );
    ref.invalidate(organizationProfileAdminProvider);
    ref.invalidate(organizationContactProvider);
    return OrganizationProfileFull.fromJson(response.data as Map<String, dynamic>);
  };
});
