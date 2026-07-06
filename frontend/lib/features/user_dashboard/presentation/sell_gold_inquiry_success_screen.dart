import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/shared_drawer.dart';
import 'package:ags_gold/features/admin/presentation/providers/organization_profile_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/aurum_surface_card.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class SellGoldInquirySuccessScreen extends ConsumerWidget {
  const SellGoldInquirySuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final contactAsync = ref.watch(organizationContactProvider);

    return Theme(
      data: AurumConsumerTheme.theme(),
      child: ResponsiveNavigationWrapper(
        title: 'Request submitted',
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AurumConsumerTheme.chipGold,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'Your sell request has been successfully sent to our team.',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AurumConsumerTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.sellGoldSuccessPayoutNote,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AurumConsumerTheme.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              AurumSurfaceCard(
                child: contactAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, _) => Text(
                    'Contact details are temporarily unavailable.',
                    style: TextStyle(color: AurumConsumerTheme.textMuted),
                  ),
                  data: (contact) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support contact',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AurumConsumerTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _contactRow(Icons.person_outline, contact.adminName),
                      _contactRow(
                        Icons.phone_outlined,
                        contact.supportContactNumber,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/user-dashboard'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AurumConsumerTheme.chipGold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Back to dashboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AurumConsumerTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AurumConsumerTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
