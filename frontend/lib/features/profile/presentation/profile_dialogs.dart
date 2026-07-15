import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/services/api_client.dart';
import 'package:ags_gold/services/service_providers.dart';

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
          messenger.showSnackBar(
            SnackBar(content: Text(successMessage)),
          );
        },
      ),
    ),
  );
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile profile;
  final VoidCallback onSaved;

  const _EditProfileSheet({
    required this.profile,
    required this.onSaved,
  });

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
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
    _firstNameController.addListener(_clearError);
    _lastNameController.addListener(_clearError);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
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
                fillColor: AppTheme.creamElevated,
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
                fillColor: AppTheme.creamElevated,
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
                fillColor: AppTheme.creamElevated,
              ),
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

Future<void> showChangePasswordDialog(
  BuildContext context,
  WidgetRef ref,
) {
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
          messenger.showSnackBar(
            SnackBar(content: Text(reloginMessage)),
          );
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
                fillColor: AppTheme.creamElevated,
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
                fillColor: AppTheme.creamElevated,
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
                fillColor: AppTheme.creamElevated,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.avatarUpdated)),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.avatarUploadFailed)),
      );
    }
  }
}

Future<void> showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _DeleteAccountDialog(
      onDeleted: () async {
        await ref.read(authNotifierProvider.notifier).clearSession();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.deleteAccountSuccess)),
        );
      },
    ),
  );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  final Future<void> Function() onDeleted;

  const _DeleteAccountDialog({required this.onDeleted});

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  bool _deleting = false;
  String? _errorMessage;

  Future<void> _delete() async {
    setState(() {
      _deleting = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('/profile/account');
      if (!mounted) return;
      Navigator.pop(context);
      await widget.onDeleted();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _errorMessage = context.l10n.deleteAccountFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.deleteAccountTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.deleteAccountMessage),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.rose, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _deleting ? null : _delete,
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.rose,
            foregroundColor: Colors.white,
          ),
          child: _deleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.deleteAccountConfirm),
        ),
      ],
    );
  }
}
