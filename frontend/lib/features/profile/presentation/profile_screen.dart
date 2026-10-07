import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/responsive/responsive_layout.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/utils/email_validator.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';

import 'package:ags_gold/core/widgets/aura_dialog_actions.dart';
import 'package:ags_gold/features/auth/domain/app_audience.dart';
import 'package:ags_gold/features/auth/presentation/providers/app_audience_provider.dart';
import 'package:ags_gold/features/profile/domain/profile.dart';
import 'package:ags_gold/features/profile/presentation/profile_dialogs.dart';
import 'package:ags_gold/features/profile/presentation/widgets/profile_settings_widgets.dart';
import 'package:ags_gold/features/settings/presentation/providers/settings_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/kyc_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/personal_dashboard_provider.dart';
import 'package:ags_gold/services/service_providers.dart';
import 'package:ags_gold/l10n/app_languages.dart';
import 'package:ags_gold/l10n/locale_preference_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final audience = ref.watch(appAudienceProvider);

    return ResponsiveNavigationWrapper(
      title: context.l10n.myProfile,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileProvider);
          ref.invalidate(profileActivityProvider);
          ref.invalidate(userSettingsProvider);
          ref.invalidate(kycStatusProvider);
          await ref.read(personalDashboardProvider.notifier).refresh();
        },
        child: profileAsync.when(
          data: (user) => audience == AppAudience.staffAdmin
              ? _AdminProfileBody(user: user)
              : _ConsumerProfileBody(user: user),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(64),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.failedToLoadProfile('$err'),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsumerProfileBody extends ConsumerWidget {
  final UserProfile user;

  const _ConsumerProfileBody({required this.user});

  Future<void> _showLanguageSheet(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final settings = await ref.read(userSettingsProvider.future);
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.changeAppLanguage),
                subtitle: Text(l10n.selectPreferredLanguage),
              ),
              for (final option in kAppLanguageOptions)
                ListTile(
                  title: Text(option.nativeLabel),
                  trailing: settings.locale == option.code
                      ? const Icon(Icons.check, color: AppTheme.goldDeep)
                      : null,
                  onTap: () async {
                    await ref
                        .read(localePreferenceProvider.notifier)
                        .setLocale(option.code);
                    await ref.read(updateUserSettingsProvider)(
                      settings.copyWith(locale: option.code),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          AuraDialogActions.buttons(
            context: context,
            cancelLabel: l10n.cancel,
            onCancel: () => Navigator.pop(context),
            confirmLabel: l10n.logout,
            onConfirm: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final kycComplete = ref.watch(effectiveKycCompleteProvider);
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          ProfileHeaderCard(
            displayName: user.displayName,
            contactLine: user.displayContactLine,
            initials: user.initials,
            showVerifiedBadge: user.isActive || kycComplete,
            kycVerified: kycComplete,
            onVerifyTap: kycComplete ? null : () => context.push('/kyc'),
            onAvatarTap: () => pickAndUploadAvatar(context, ref),
          ),
          const SizedBox(height: 16),
          ProfileSectionHeader(title: l10n.accountSection),
          ProfileAccountShortcuts(kycVerified: kycComplete),
          const SizedBox(height: 4),
          ProfileSectionHeader(
            title: kycComplete ? l10n.kycVerifiedHeading : l10n.kycVerification,
          ),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: kycComplete
                    ? Icons.verified_user_rounded
                    : Icons.gpp_maybe_outlined,
                title: kycComplete
                    ? l10n.kycVerifiedHeading
                    : l10n.identityVerification,
                trailing: _KycStatusChip(verified: kycComplete),
                onTap: () => context.push('/kyc'),
              ),
            ],
          ),
          ProfileSectionHeader(title: l10n.profileSettings),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: Icons.badge_outlined,
                title: l10n.accountDetails,
                onTap: () => showEditProfileDialog(context, ref, user),
              ),
              ProfileSettingsTile(
                icon: Icons.mark_email_read_outlined,
                title: l10n.emailAddress,
                subtitle: (user.email != null && !isPlaceholderEmail(user.email))
                    ? user.email
                    : 'Add email for gold invoices',
                trailing: (user.email != null && !isPlaceholderEmail(user.email))
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryGold.withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            color: AppTheme.primaryGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                onTap: () => showAddEmailDialog(
                  context,
                  ref,
                  currentEmail: user.email,
                ),
              ),

              ProfileSettingsTile(
                icon: Icons.description_outlined,
                title: l10n.statements,
                onTap: () => context.push('/user-transactions'),
              ),
            ],
          ),
          ProfileSectionHeader(title: l10n.general),
          ProfileSettingsGroup(
            children: [
              ProfileSettingsTile(
                icon: Icons.palette_outlined,
                title: l10n.themeSettings,
                onTap: () => context.push('/settings'),
              ),
              ProfileSettingsTile(
                icon: Icons.language_outlined,
                title: l10n.changeAppLanguage,
                onTap: () => _showLanguageSheet(context, ref),
              ),
              ProfileSettingsTile(
                icon: Icons.card_giftcard_outlined,
                title: l10n.referAndEarn,
                onTap: () => context.push('/refer-and-earn'),
              ),
              ProfileSettingsTile(
                icon: Icons.gavel_outlined,
                title: l10n.digiGoldTermsTitle,
                onTap: () => context.push('/terms-and-conditions'),
              ),
              ProfileSettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: l10n.privacyPolicy,
                onTap: () => context.push('/privacy-policy'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => showDeleteAccountDialog(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.rose,
                side: BorderSide(color: AppTheme.rose.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.delete_forever_outlined, size: 20),
              label: Text(
                l10n.deleteAccount,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.rose.withValues(alpha: 0.12),
                foregroundColor: AppTheme.rose,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.logout, size: 20),
              label: Text(
                l10n.logout,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.followUsToStayUpdated,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.profileMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _KycStatusChip extends StatelessWidget {
  final bool verified;

  const _KycStatusChip({required this.verified});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Color color = verified ? AppTheme.emerald : AppTheme.goldDeep;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (verified)
          const Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(
              Icons.check_circle_rounded,
              color: AppTheme.emerald,
              size: 18,
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            verified ? l10n.kycVerifiedHeading : l10n.completeKyc,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
        ),
      ],
    );
  }
}

class _AdminProfileBody extends ConsumerWidget {
  final UserProfile user;

  const _AdminProfileBody({required this.user});

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          AuraDialogActions.buttons(
            context: context,
            cancelLabel: l10n.cancel,
            onCancel: () => Navigator.pop(context),
            confirmLabel: l10n.logout,
            onConfirm: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = ResponsiveLayout.isDesktop(context);
    final l10n = context.l10n;

    final bodyContent = ListView(
      shrinkWrap: isDesktop,
      physics: isDesktop ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
      padding: isDesktop ? EdgeInsets.zero : const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        ProfileHeaderCard(
          displayName: user.displayName,
          contactLine: user.displayContactLine,
          initials: user.initials,
          showVerifiedBadge: user.isActive,
          onAvatarTap: () => pickAndUploadAvatar(context, ref),
        ),
        ProfileSectionHeader(title: 'ADMIN PANELS'),
        ProfileSettingsGroup(
          children: [
            ProfileSettingsTile(
              icon: Icons.account_balance_wallet_outlined,
              title: 'User Wallets & Balances',
              subtitle: 'Gold & silver holdings, balances, & KYC',
              onTap: () => context.push('/admin/user-wallets'),
            ),
            ProfileSettingsTile(
              icon: Icons.inventory_2_outlined,
              title: 'Inventory',
              subtitle: 'Track physical gold & silver stock',
              onTap: () => context.push('/inventory'),
            ),
            ProfileSettingsTile(
              icon: Icons.sell_outlined,
              title: 'Sell Inquiries',
              subtitle: 'Customer gold buyback requests & payouts',
              onTap: () => context.push('/admin/sell-inquiries'),
            ),
          ],
        ),
        ProfileSectionHeader(title: 'PREFERENCES & SYSTEM'),
        ProfileSettingsGroup(
          children: [
            ProfileSettingsTile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'Language, themes, and biometric security',
              onTap: () => context.push('/settings'),
            ),
            ProfileSettingsTile(
              icon: Icons.history_toggle_off_outlined,
              title: 'System Audit Logs',
              subtitle: 'Audit logs for admin actions & activity summary',
              onTap: () => context.push('/audit-logs'),
            ),
          ],
        ),
        ProfileSectionHeader(title: 'ACCOUNT DETAILS'),
        ProfileSettingsGroup(
          children: [
            ProfileSettingsTile(
              icon: Icons.badge_outlined,
              title: 'Edit Profile Info',
              onTap: () => showEditProfileDialog(context, ref, user),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () => _confirmLogout(context, ref),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.rose.withValues(alpha: 0.12),
              foregroundColor: AppTheme.rose,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.logout, size: 20),
            label: Text(
              l10n.logout,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );

    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: bodyContent,
          ),
        ),
      );
    }

    return bodyContent;
  }
}

