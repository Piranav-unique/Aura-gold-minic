import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/utils/email_validator.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/services/service_providers.dart';

export 'package:ags_gold/features/profile/presentation/widgets/add_email_dialog.dart';



Future<void> showEditProfileDialog(
  BuildContext context,
  WidgetRef ref,
  UserProfile profile,
) {
  final messenger = ScaffoldMessenger.of(context);
  final successMessage = context.l10n.profileUpdated;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _EditProfileSheet(
        profile: profile,
        onSaved: () {
          ref.invalidate(profileProvider);
          messenger.showSnackBar(SnackBar(content: Text(successMessage)));
        },
      ),
    ),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile profile;
  final VoidCallback onSaved;

  const _EditProfileSheet({required this.profile, required this.onSaved});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.profile.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.profile.lastName ?? '',
    );
    _emailController = TextEditingController(
      text: isPlaceholderEmail(widget.profile.email)
          ? ''
          : (widget.profile.email ?? ''),
    );
    _firstNameController.addListener(_clearError);
    _lastNameController.addListener(_clearError);
    _emailController.addListener(_clearError);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final payload = <String, dynamic>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
      };

      final enteredEmail = _emailController.text.trim().toLowerCase();
      if (enteredEmail.isNotEmpty) {
        payload['email'] = enteredEmail;
      }

      await apiClient.put('/profile/', data: payload);

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } on ApiException catch (e) {

      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = context.l10n.profileUpdateFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.editProfile,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.manageYourProfile,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.profileMuted,
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.rose.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.rose,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.rose,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _firstNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.firstName,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.firstNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.lastName,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.profile.displayContactLine,
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                labelText: l10n.mobileNumber,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.emailAddress,
                hintText: 'name.someone@gmail.com',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                helperText: 'Required for receiving gold tax invoices & receipts',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              validator: validateUserEmail,
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.save),
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

Future<void> showChangePasswordDialog(BuildContext context, WidgetRef ref) {
  final messenger = ScaffoldMessenger.of(context);
  final reloginMessage = context.l10n.passwordChangedRelogin;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _ChangePasswordSheet(
        onChanged: () async {
          await ref.read(authNotifierProvider.notifier).clearSession();
          messenger.showSnackBar(SnackBar(content: Text(reloginMessage)));
        },
      ),
    ),
  );
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  final Future<void> Function() onChanged;

  const _ChangePasswordSheet({required this.onChanged});

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post(
        '/profile/change-password',
        data: {
          'current_password': _currentController.text,
          'new_password': _newController.text,
        },
      );

      if (!mounted) return;
      Navigator.pop(context);
      await widget.onChanged();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = context.l10n.passwordChangeFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.changePassword,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.rose.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.rose,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _currentController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.currentPasswordLabel,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.passwordRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newController,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.newPasswordLabel,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (value == null || value.length < 8) {
                  return l10n.newPasswordMinLength;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.confirmPassword,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              validator: (value) {
                if (value != _newController.text) {
                  return l10n.passwordsDoNotMatch;
                }
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.save),
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

Future<void> pickAndUploadAvatar(BuildContext context, WidgetRef ref) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 256,
    maxHeight: 256,
    imageQuality: 80,
  );
  if (file == null) return;

  final bytes = await file.readAsBytes();
  final base64Str = base64Encode(bytes);
  final contentType = file.mimeType ?? 'image/jpeg';

  try {
    final apiClient = ref.read(apiClientProvider);
    await apiClient.post(
      '/profile/avatar',
      data: {'avatar_base64': base64Str, 'content_type': contentType},
    );
    ref.invalidate(profileProvider);
    ref.invalidate(avatarBytesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.avatarUpdated)));
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.avatarUploadFailed)));
    }
  }
}

Future<void> showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => const _AccountDeletionFlowDialog(),
  );
}

class _AccountDeletionFlowDialog extends ConsumerStatefulWidget {
  const _AccountDeletionFlowDialog();

  @override
  ConsumerState<_AccountDeletionFlowDialog> createState() =>
      _AccountDeletionFlowDialogState();
}

class _AccountDeletionFlowDialogState
    extends ConsumerState<_AccountDeletionFlowDialog> {
  final _reasonController = TextEditingController();
  final _dateFormat = DateFormat('MMM d, yyyy · hh:mm a');

  bool _loading = true;
  bool _submitting = false;
  bool _confirmedDestruction = false;
  String? _errorMessage;

  Map<String, dynamic>? _activeRequest;
  double _goldBalance = 0.0;
  double _silverBalance = 0.0;
  double _liveGoldRate = 0.0;
  double _liveSilverRate = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);

      // 1. Fetch active/latest deletion request
      Map<String, dynamic>? activeReq;
      try {
        final reqResponse =
            await apiClient.get('/profile/account-deletion-request');
        if (reqResponse.data != null &&
            reqResponse.data is Map<String, dynamic>) {
          activeReq = reqResponse.data as Map<String, dynamic>;
        }
      } catch (_) {
        // No active request or 404
      }

      // 2. Fetch live wallet balances
      double gold = 0.0;
      double silver = 0.0;
      try {
        final dashResponse = await apiClient.get('/dashboard/personal');
        if (dashResponse.data != null &&
            dashResponse.data is Map<String, dynamic>) {
          final dashData = dashResponse.data as Map<String, dynamic>;
          gold = (dashData['gold_savings_grams'] as num?)?.toDouble() ?? 0.0;
          silver =
              (dashData['silver_savings_grams'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (_) {
        final cached = ref.read(personalDashboardProvider).value;
        if (cached != null) {
          gold = cached.goldSavingsGrams;
          silver = cached.silverSavingsGrams;
        }
      }

      // 3. Fetch live metal rates
      double goldRate = 0.0;
      double silverRate = 0.0;
      try {
        final priceResponse = await apiClient.get('/dashboard/metal-prices');
        if (priceResponse.data != null &&
            priceResponse.data is Map<String, dynamic>) {
          final priceData = priceResponse.data as Map<String, dynamic>;
          final goldQuote = priceData['gold'] as Map<String, dynamic>?;
          if (goldQuote != null) {
            goldRate = (goldQuote['retail_price'] as num?)?.toDouble() ??
                (goldQuote['spot_price'] as num?)?.toDouble() ??
                0.0;
          }
          final silverQuote = priceData['silver'] as Map<String, dynamic>?;
          if (silverQuote != null) {
            silverRate = (silverQuote['retail_price'] as num?)?.toDouble() ??
                (silverQuote['spot_price'] as num?)?.toDouble() ??
                0.0;
          }
        }
      } catch (_) {
        final cachedPrices = ref.read(metalPricesProvider).value;
        if (cachedPrices != null) {
          goldRate = cachedPrices.gold.displayPrice;
          silverRate = cachedPrices.silver.displayPrice;
        }
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _activeRequest = activeReq;
        _goldBalance = gold;
        _silverBalance = silver;
        _liveGoldRate = goldRate;
        _liveSilverRate = silverRate;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'Could not check account and wallet balance. Please try again.';
      });
    }
  }

  Future<void> _submitDeletionRequest() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final reason = _reasonController.text.trim();

      await apiClient.post(
        '/profile/account-deletion-request',
        data: {
          if (reason.isNotEmpty) 'reason': reason,
        },
      );

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account deletion request submitted. The Administrator will review and decide your request.',
          ),
          backgroundColor: Colors.blueGrey,
          duration: Duration(seconds: 5),
        ),
      );

      ref.invalidate(profileProvider);
      ref.invalidate(personalDashboardProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Failed to submit deletion request. Please try again.';
      });
    }
  }

  Future<void> _cancelDeletionRequest() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('/profile/account-deletion-request');

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deletion request has been cancelled.'),
          backgroundColor: AppTheme.emerald,
        ),
      );

      ref.invalidate(profileProvider);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = 'Failed to cancel request. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return AlertDialog(
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Checking wallet balance and deletion status...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final hasPendingRequest = _activeRequest != null &&
        (_activeRequest!['status']?.toString().toLowerCase() == 'pending');

    // 1. Pending Request Dialog
    if (hasPendingRequest) {
      final createdAtStr = _activeRequest!['created_at']?.toString();
      final createdAt =
          createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;
      final reason = _activeRequest!['reason'] as String?;

      return AlertDialog(
        icon: const Icon(
          Icons.hourglass_top_rounded,
          color: Colors.orange,
          size: 40,
        ),
        title: const Text('Deletion Request Pending'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.rose.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.rose.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Data Destruction Alert: If the Administrator approves your request, your account and all personal KYC, bank, and transaction data will be permanently destroyed.',
                style: TextStyle(
                  color: AppTheme.rose,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Your account deletion request has been submitted and is awaiting Administrator review.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Status: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'Pending Admin Review',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Submitted: ${_dateFormat.format(createdAt.toLocal())}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  if (reason != null && reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Reason: "$reason"',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.rose, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _cancelDeletionRequest,
            child: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Cancel Request',
                    style: TextStyle(color: AppTheme.rose),
                  ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    // 2. Non-empty Wallet Dialog (Block deletion and prompt user to claim/sell gold at live rate)
    final hasGold = _goldBalance > 0.0001;
    final hasSilver = _silverBalance > 0.0001;
    final walletNotEmpty = hasGold || hasSilver;

    if (walletNotEmpty) {
      final estimatedGoldValue = _goldBalance * _liveGoldRate;

      return AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 44,
        ),
        title: const Text(
          'Wallet Balance Detected',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Data destruction warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.rose.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.rose.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.report_problem, color: AppTheme.rose, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Alert: If you delete your account, your data will get permanently destroyed.',
                        style: TextStyle(
                          color: AppTheme.rose,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Wallet not empty message requirement
              const Text(
                'Your wallet is not empty. Account deletion is only applicable if your wallet is completely empty.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please claim or sell your gold according to the current gold rate and then delete your account.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),

              // Balance & Live Rate breakdown card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryGold.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    if (hasGold) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Gold Vault Balance:',
                            style: TextStyle(fontSize: 13),
                          ),
                          Text(
                            '${_goldBalance.toStringAsFixed(4)} g',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (_liveGoldRate > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Gold Rate:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '₹${_liveGoldRate.toStringAsFixed(2)} / gm',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.goldDeep,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Est. Gold Value:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₹${estimatedGoldValue.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.goldDeep,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    if (hasSilver) ...[
                      if (hasGold) const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Silver Vault Balance:',
                            style: TextStyle(fontSize: 13),
                          ),
                          Text(
                            '${_silverBalance.toStringAsFixed(4)} g',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (_liveSilverRate > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Current Silver Rate:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '₹${_liveSilverRate.toStringAsFixed(2)} / gm',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: Colors.black87,
            ),
            onPressed: () {
              Navigator.pop(context);
              context.push('/sell-gold-inquiry');
            },
            icon: const Icon(Icons.monetization_on_outlined, size: 18),
            label: const Text('Claim / Sell Gold'),
          ),
        ],
      );
    }

    // 3. Wallet is Empty: Deletion Request submission to Admin
    return AlertDialog(
      icon: const Icon(
        Icons.delete_forever_rounded,
        color: AppTheme.rose,
        size: 44,
      ),
      title: const Text(
        'Delete Account',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Permanent data destruction alert
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.rose.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.rose.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '⚠️ PERMANENT DATA DESTRUCTION WARNING',
                    style: TextStyle(
                      color: AppTheme.rose,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'If you delete your account, your data will get permanently destroyed. All your personal profile data, KYC verification documents, bank linkage records, and transaction histories will be completely purged and cannot be recovered.',
                    style: TextStyle(
                      color: AppTheme.rose,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Admin Review Notice
            const Text(
              'Your wallet is empty. To proceed, your request will be passed to the Administrator, and the Administrator will review and decide the incoming deletion request.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),

            // Reason field
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for deletion (optional)',
                hintText: 'Tell us why you are deleting your account...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Confirmation checkbox
            InkWell(
              onTap: () {
                setState(() {
                  _confirmedDestruction = !_confirmedDestruction;
                });
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _confirmedDestruction,
                    onChanged: (val) {
                      setState(() {
                        _confirmedDestruction = val ?? false;
                      });
                    },
                    activeColor: AppTheme.rose,
                  ),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'I understand that all my personal data will be permanently destroyed upon Admin approval.',
                        style: TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.rose, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.rose,
            foregroundColor: Colors.white,
          ),
          onPressed: (_confirmedDestruction && !_submitting)
              ? _submitDeletionRequest
              : null,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(
            _submitting ? 'Submitting...' : 'Submit to Admin',
          ),
        ),
      ],
    );
  }
}
