import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/widgets/premium_skeleton.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/organization_profile_provider.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/services/service_providers.dart';

class AdminOrganizationProfileScreen extends ConsumerStatefulWidget {
  const AdminOrganizationProfileScreen({super.key});

  @override
  ConsumerState<AdminOrganizationProfileScreen> createState() =>
      _AdminOrganizationProfileScreenState();
}

class _AdminOrganizationProfileScreenState
    extends ConsumerState<AdminOrganizationProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _initialized = false;
  String? _error;

  final _orgName = TextEditingController();
  final _adminName = TextEditingController();
  final _supportPhone = TextEditingController();
  final _supportEmail = TextEditingController();
  final _officeAddress = TextEditingController();
  final _businessGst = TextEditingController();
  final _businessPan = TextEditingController();
  final _upiId = TextEditingController();
  final _googlePayId = TextEditingController();
  final _phonepeId = TextEditingController();
  final _paytmId = TextEditingController();
  final _bankName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifsc = TextEditingController();
  final _businessHours = TextEditingController();
  final _emergencyContact = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _orgName,
      _adminName,
      _supportPhone,
      _supportEmail,
      _officeAddress,
      _businessGst,
      _businessPan,
      _upiId,
      _googlePayId,
      _phonepeId,
      _paytmId,
      _bankName,
      _accountNumber,
      _ifsc,
      _businessHours,
      _emergencyContact,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(OrganizationProfileFull profile) {
    if (_initialized) return;
    _orgName.text = profile.organizationName;
    _adminName.text = profile.adminName;
    _supportPhone.text = profile.supportContactNumber;
    _supportEmail.text = profile.supportEmail ?? '';
    _officeAddress.text = profile.officeAddress ?? '';
    _businessGst.text = profile.businessGst ?? '';
    _businessPan.text = profile.businessPan ?? '';
    _upiId.text = profile.upiId ?? '';
    _googlePayId.text = profile.googlePayId ?? '';
    _phonepeId.text = profile.phonepeId ?? '';
    _paytmId.text = profile.paytmId ?? '';
    _bankName.text = profile.bankName ?? '';
    _accountNumber.text = profile.accountNumber ?? '';
    _ifsc.text = profile.ifsc ?? '';
    _businessHours.text = profile.businessHours ?? '';
    _emergencyContact.text = profile.emergencyContact ?? '';
    _initialized = true;
  }

  Future<void> _save(String profileId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = OrganizationProfileFull(
        id: profileId,
        organizationName: _orgName.text.trim(),
        adminName: _adminName.text.trim(),
        supportContactNumber: _supportPhone.text.trim(),
        supportEmail: _emptyToNull(_supportEmail.text),
        officeAddress: _emptyToNull(_officeAddress.text),
        businessGst: _emptyToNull(_businessGst.text),
        businessPan: _emptyToNull(_businessPan.text),
        upiId: _emptyToNull(_upiId.text),
        googlePayId: _emptyToNull(_googlePayId.text),
        phonepeId: _emptyToNull(_phonepeId.text),
        paytmId: _emptyToNull(_paytmId.text),
        bankName: _emptyToNull(_bankName.text),
        accountNumber: _emptyToNull(_accountNumber.text),
        ifsc: _emptyToNull(_ifsc.text),
        businessHours: _emptyToNull(_businessHours.text),
        emergencyContact: _emptyToNull(_emergencyContact.text),
      );
      await ref.read(updateOrganizationProfileProvider)(profile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Organization profile saved')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(organizationProfileAdminProvider);
    final userProfile = ref.watch(profileProvider).value;
    final canEdit = userProfile?.isSuperuser == true;

    return ResponsiveNavigationWrapper(
      title: 'Organization profile',
      child: profileAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(24),
          child: PremiumSkeleton(height: 400),
        ),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
        data: (profile) {
          _fill(profile);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organization profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canEdit
                        ? 'Update support and business contact details used across the app.'
                        : 'View-only. Only super admin can edit this profile.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 24),
                  _section('Organization', [
                    _field(_orgName, 'Organization name', enabled: canEdit),
                    _field(_adminName, 'Admin name', enabled: canEdit),
                    _field(_supportPhone, 'Support contact number', enabled: canEdit),
                    _field(_supportEmail, 'Support email', enabled: canEdit),
                    _field(
                      _officeAddress,
                      'Office address',
                      enabled: canEdit,
                      maxLines: 3,
                    ),
                  ]),
                  _section('Business', [
                    _field(_businessGst, 'Business GST', enabled: canEdit),
                    _field(_businessPan, 'Business PAN', enabled: canEdit),
                    _field(_businessHours, 'Business hours', enabled: canEdit),
                    _field(_emergencyContact, 'Emergency contact', enabled: canEdit),
                  ]),
                  _section('Payment IDs', [
                    _field(_upiId, 'UPI ID', enabled: canEdit),
                    _field(_googlePayId, 'Google Pay ID', enabled: canEdit),
                    _field(_phonepeId, 'PhonePe ID', enabled: canEdit),
                    _field(_paytmId, 'Paytm ID', enabled: canEdit),
                  ]),
                  _section('Bank account', [
                    _field(_bankName, 'Bank name', enabled: canEdit),
                    _field(_accountNumber, 'Account number', enabled: canEdit),
                    _field(_ifsc, 'IFSC', enabled: canEdit),
                  ]),
                  if (canEdit) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : () => _save(profile.id),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save profile'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
        validator: label.contains('name') || label.contains('number')
            ? (v) {
                if (!enabled) return null;
                if (v == null || v.trim().isEmpty) {
                  return 'Required';
                }
                return null;
              }
            : null,
      ),
    );
  }
}
