import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/utils/email_validator.dart';
import 'package:ags_gold/core/widgets/aura_dialog_actions.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/services/service_providers.dart';

/// Session flag so the Email reminder sheet pops up at most once per app session.
class EmailPromptShownNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markShown() => state = true;
}

final emailPromptShownProvider =
    NotifierProvider<EmailPromptShownNotifier, bool>(EmailPromptShownNotifier.new);

/// Shows the "Verify your Gmail" sheet once per session for customers without a valid @gmail.com.
void maybeShowEmailPrompt(
  BuildContext context,
  WidgetRef ref, {
  String? currentEmail,
}) {
  if (!isPlaceholderEmail(currentEmail)) return;
  if (ref.read(emailPromptShownProvider)) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    if (ref.read(emailPromptShownProvider)) return;
    ref.read(emailPromptShownProvider.notifier).markShown();
    showAddEmailDialog(
      context,
      ref,
      currentEmail: currentEmail,
    );
  });
}

/// Shows a bottom sheet allowing the customer to add or update their personal Gmail
/// address required for receiving tax invoices and vault receipts.
Future<bool?> showAddEmailDialog(
  BuildContext context,
  WidgetRef ref, {
  String? currentEmail,
  VoidCallback? onEmailSaved,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _AddEmailSheet(
        initialEmail: isPlaceholderEmail(currentEmail) ? '' : (currentEmail ?? ''),
        onSaved: onEmailSaved,
      ),
    ),
  );
}

class _AddEmailSheet extends ConsumerStatefulWidget {
  final String initialEmail;
  final VoidCallback? onSaved;

  const _AddEmailSheet({
    required this.initialEmail,
    this.onSaved,
  });

  @override
  ConsumerState<_AddEmailSheet> createState() => _AddEmailSheetState();
}

class _AddEmailSheetState extends ConsumerState<_AddEmailSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _emailController.addListener(_clearError);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put('/profile/', data: {'email': email});

      // Refresh providers across the app
      ref.invalidate(profileProvider);
      await ref.read(personalDashboardProvider.notifier).refresh();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email address saved. Tax invoices will be sent here.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      Navigator.pop(context, true);
      widget.onSaved?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Failed to save email. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AurumConsumerTheme.isDark(context);
    final isNew = widget.initialEmail.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon Header
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFDF00), Color(0xFFD4AF37)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGold.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 30,
                  color: Color(0xFF38290D),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              isNew ? 'Verify Your Gmail Address' : 'Update Gmail Address',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1D24),
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              'Required for delivering official 24K Tax Invoices, payment receipts, and vault custody certificates. Must end with @gmail.com.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 18),

            // Notice Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF262014)
                    : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryGold.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Please enter your personal Gmail (e.g. name@gmail.com). Mobile numbers, academic emails, or non-Gmail addresses cannot be accepted.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark
                            ? const Color(0xFFFDE68A)
                            : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Email input field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A1D24),
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: 'Gmail Address (@gmail.com)',
                hintText: 'name@gmail.com',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                suffixIcon: _emailController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _emailController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1F2430) : const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppTheme.primaryGold,
                    width: 1.8,
                  ),
                ),
              ),
              validator: validateUserEmail,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 18, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Submit Buttons
            AuraDialogActions.buttons(
              context: context,
              cancelLabel: 'Cancel',
              onCancel: _saving ? null : () => Navigator.pop(context),
              confirmLabel: _saving ? 'Saving...' : 'Save Email',
              onConfirm: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
