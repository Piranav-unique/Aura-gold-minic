import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class KycGovernmentProfileCard extends StatelessWidget {
  final KycGovernmentProfile profile;

  const KycGovernmentProfileCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.verified_user,
                    color: AppTheme.primaryGold,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.fullName ?? 'Verified user',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.governmentVerifiedIdentity,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.verified, color: AppTheme.emerald, size: 22),
              ],
            ),
            const SizedBox(height: 16),
            if (profile.dateOfBirth != null)
              _InfoRow(label: l10n.dateOfBirth, value: profile.dateOfBirth!),
            if (profile.gender != null)
              _InfoRow(label: l10n.gender, value: profile.gender!),
            if (profile.fullAddress != null)
              _InfoRow(label: l10n.address, value: profile.fullAddress!),
            if (profile.state != null)
              _InfoRow(label: l10n.stateLabel, value: profile.state!),
            if (profile.aadhaarLast4 != null)
              _InfoRow(
                label: l10n.aadhaarLabel,
                value: 'XXXX XXXX ${profile.aadhaarLast4}',
              ),
            if (profile.panNumberMasked != null)
              _InfoRow(label: l10n.panLabel, value: profile.panNumberMasked!),
            if (profile.panCategory != null)
              _InfoRow(
                label: l10n.panCategory,
                value: profile.panCategory!.replaceAll('_', ' '),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
