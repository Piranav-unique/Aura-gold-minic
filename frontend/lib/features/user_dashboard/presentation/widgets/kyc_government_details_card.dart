import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

/// Government identity details fetched from UIDAI / Income Tax records.
class KycGovernmentDetailsCard extends StatelessWidget {
  final KycGovernmentProfile profile;
  final bool compact;

  const KycGovernmentDetailsCard({
    super.key,
    required this.profile,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AurumSurfaceCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AurumConsumerTheme.liveGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: AurumConsumerTheme.liveGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.governmentVerifiedIdentity,
                  style: TextStyle(
                    color: AurumConsumerTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile.fullName != null)
            _DetailRow(label: l10n.registeredName, value: profile.fullName!),
          if (profile.dateOfBirth != null)
            _DetailRow(label: l10n.dateOfBirth, value: profile.dateOfBirth!),
          if (profile.gender != null)
            _DetailRow(label: l10n.gender, value: profile.gender!),
          if (profile.fullAddress != null)
            _DetailRow(label: l10n.address, value: profile.fullAddress!),
          if (profile.state != null)
            _DetailRow(label: l10n.state, value: profile.state!),
          if (profile.district != null)
            _DetailRow(label: l10n.district, value: profile.district!),
          if (profile.pincode != null)
            _DetailRow(label: l10n.pincode, value: profile.pincode!),
          if (profile.aadhaarLast4 != null)
            _DetailRow(
              label: l10n.aadhaarNumber,
              value: 'XXXX XXXX ${profile.aadhaarLast4}',
            ),
          if (profile.panNumberMasked != null)
            _DetailRow(label: l10n.panNumber, value: profile.panNumberMasked!),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AurumConsumerTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: AurumConsumerTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
