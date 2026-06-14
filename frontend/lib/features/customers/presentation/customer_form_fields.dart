import 'package:flutter/material.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';

class CustomerFormFields extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController mobileController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController gstController;
  final String customerType;
  final String status;
  final bool isLoading;
  final ValueChanged<String> onCustomerTypeChanged;
  final ValueChanged<String> onStatusChanged;

  const CustomerFormFields({
    super.key,
    required this.formKey,
    required this.fullNameController,
    required this.mobileController,
    required this.emailController,
    required this.addressController,
    required this.gstController,
    required this.customerType,
    required this.status,
    required this.isLoading,
    required this.onCustomerTypeChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: customerType,
            decoration: const InputDecoration(
              labelText: 'Customer Type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: customerTypeOptions
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t == 'business' ? 'Business' : 'Individual'),
                  ),
                )
                .toList(),
            onChanged: isLoading ? null : (v) => onCustomerTypeChanged(v!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: fullNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            enabled: !isLoading,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Full name is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: mobileController,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              prefixIcon: Icon(Icons.phone_outlined),
              hintText: '+919876543210',
            ),
            keyboardType: TextInputType.phone,
            enabled: !isLoading,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Mobile number is required';
              }
              final cleaned = v.replaceAll(' ', '').replaceAll('-', '');
              if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(cleaned)) {
                return 'Enter a valid mobile number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            enabled: !isLoading,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(
                r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$',
              ).hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            maxLines: 3,
            enabled: !isLoading,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Address is required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: gstController,
            decoration: const InputDecoration(
              labelText: 'GST Number (Optional)',
              prefixIcon: Icon(Icons.receipt_long_outlined),
              hintText: '22AAAAA0000A1Z5',
            ),
            textCapitalization: TextCapitalization.characters,
            enabled: !isLoading,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              if (!RegExp(
                r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$',
              ).hasMatch(v.trim().toUpperCase())) {
                return 'Enter a valid GST number';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: status,
            decoration: const InputDecoration(
              labelText: 'Status',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: customerStatusOptions
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(s[0].toUpperCase() + s.substring(1)),
                  ),
                )
                .toList(),
            onChanged: isLoading ? null : (v) => onStatusChanged(v!),
          ),
        ],
      ),
    );
  }
}
