import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/customers/domain/customer.dart';
import 'package:ags_gold/features/customers/presentation/customer_form_fields.dart';
import 'package:ags_gold/features/customers/presentation/providers/customers_provider.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;

  const CustomerFormScreen({super.key, this.customerId});

  bool get isEdit => customerId != null;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();

  String _customerType = 'individual';
  String _status = 'active';
  bool _isLoading = false;
  bool _initialized = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  void _populateForm(Customer customer) {
    if (_initialized) return;
    _fullNameController.text = customer.fullName;
    _mobileController.text = customer.mobileNumber;
    _emailController.text = customer.email;
    _addressController.text = customer.address;
    _gstController.text = customer.gstNumber ?? '';
    _customerType = customer.customerType;
    _status = customer.status;
    _initialized = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.isEdit) {
        final existing = await ref.read(
          customerDetailProvider(widget.customerId!).future,
        );
        final updated = existing.copyWith(
          customerType: _customerType,
          fullName: _fullNameController.text.trim(),
          mobileNumber: _mobileController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          gstNumber: _gstController.text.trim().isEmpty
              ? null
              : _gstController.text.trim(),
          status: _status,
        );
        await ref.read(updateCustomerProvider)(updated);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer updated successfully')),
        );
        context.go('/customers/${widget.customerId}');
      } else {
        final customer = Customer(
          id: '',
          customerType: _customerType,
          fullName: _fullNameController.text.trim(),
          mobileNumber: _mobileController.text.trim(),
          email: _emailController.text.trim(),
          address: _addressController.text.trim(),
          gstNumber: _gstController.text.trim().isEmpty
              ? null
              : _gstController.text.trim(),
          status: _status,
          totalPurchases: 0,
          totalRevenue: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        final created = await ref.read(createCustomerProvider)(customer);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer created successfully')),
        );
        context.go('/customers/${created.id}');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'Edit Customer' : 'New Customer';

    if (widget.isEdit) {
      final customerAsync = ref.watch(
        customerDetailProvider(widget.customerId!),
      );
      return ResponsiveNavigationWrapper(
        title: title,
        child: customerAsync.when(
          data: (customer) {
            _populateForm(customer);
            return _buildForm(context);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load customer: $e')),
        ),
      );
    }

    return ResponsiveNavigationWrapper(
      title: title,
      child: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: MaterialBanner(
                  content: Text(_errorMessage!),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  leading: const Icon(
                    Icons.error_outline,
                    color: Colors.redAccent,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _errorMessage = null),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            CustomerFormFields(
              formKey: _formKey,
              fullNameController: _fullNameController,
              mobileController: _mobileController,
              emailController: _emailController,
              addressController: _addressController,
              gstController: _gstController,
              customerType: _customerType,
              status: _status,
              isLoading: _isLoading,
              onCustomerTypeChanged: (v) => setState(() => _customerType = v),
              onStatusChanged: (v) => setState(() => _status = v),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.go(
                          widget.isEdit
                              ? '/customers/${widget.customerId}'
                              : '/customers',
                        ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.isEdit ? 'Save Changes' : 'Create Customer',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
