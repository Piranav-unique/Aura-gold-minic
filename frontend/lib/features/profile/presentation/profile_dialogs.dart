import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/services/service_providers.dart';

Future<void> showEditProfileDialog(
  BuildContext context,
  WidgetRef ref,
  UserProfile profile,
) async {
  final firstNameController = TextEditingController(text: profile.firstName);
  final lastNameController = TextEditingController(text: profile.lastName);
  final emailController = TextEditingController(text: profile.email);
  final passwordController = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: 'First name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: 'Last name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current password (required to change email)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              final apiClient = ref.read(apiClientProvider);
              final payload = <String, dynamic>{
                'first_name': firstNameController.text.trim(),
                'last_name': lastNameController.text.trim(),
                'email': emailController.text.trim(),
              };
              if (emailController.text.trim() != profile.email) {
                payload['current_password'] = passwordController.text;
              }
              await apiClient.put('/profile/', data: payload);
              ref.invalidate(profileProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text('Update failed: $e')));
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  firstNameController.dispose();
  lastNameController.dispose();
  emailController.dispose();
  passwordController.dispose();
}

Future<void> showChangePasswordDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final currentController = TextEditingController();
  final newController = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Change Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: currentController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              final apiClient = ref.read(apiClientProvider);
              await apiClient.post(
                '/profile/change-password',
                data: {
                  'current_password': currentController.text,
                  'new_password': newController.text,
                },
              );
              if (ctx.mounted) Navigator.pop(ctx);
              await ref.read(authNotifierProvider.notifier).clearSession();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password changed. Please log in again on all devices.',
                    ),
                  ),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Password change failed: $e')),
                );
              }
            }
          },
          child: const Text('Update'),
        ),
      ],
    ),
  );

  currentController.dispose();
  newController.dispose();
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
      ).showSnackBar(const SnackBar(content: Text('Avatar updated')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Avatar upload failed: $e')));
    }
  }
}
