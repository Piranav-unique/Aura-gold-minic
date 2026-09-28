import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class AurumUsefulGoldInfoCard extends StatelessWidget {
  const AurumUsefulGoldInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = AurumConsumerTheme.isDark(context);

    final insights = [
      _GoldInsight(
        icon: Icons.verified_rounded,
        title: l10n.goldInsight1Title,
        subtitle: l10n.goldInsight1Subtitle,
        content: l10n.goldInsight1Content,
      ),
      _GoldInsight(
        icon: Icons.trending_up_rounded,
        title: l10n.goldInsight2Title,
        subtitle: l10n.goldInsight2Subtitle,
        content: l10n.goldInsight2Content,
      ),
      _GoldInsight(
        icon: Icons.price_check_rounded,
        title: l10n.goldInsight3Title,
        subtitle: l10n.goldInsight3Subtitle,
        content: l10n.goldInsight3Content,
      ),
      _GoldInsight(
        icon: Icons.storefront_rounded,
        title: l10n.goldInsight4Title,
        subtitle: l10n.goldInsight4Subtitle,
        content: l10n.goldInsight4Content,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurumConsumerTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurumConsumerTheme.borderOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppTheme.primaryGold,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.whySaveDigitalGold,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1E1A14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: insights.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: AurumConsumerTheme.borderOf(context).withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final insight = insights[index];

              return Material(
                type: MaterialType.transparency,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: Key('insight_$index'),
                    initiallyExpanded: index == 0,
                    tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                    childrenPadding: const EdgeInsets.fromLTRB(40, 0, 8, 12),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        insight.icon,
                        size: 18,
                        color: AppTheme.primaryGold,
                      ),
                    ),
                    title: Text(
                      insight.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E1A14),
                      ),
                    ),
                    subtitle: Text(
                      insight.subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AurumConsumerTheme.muted(context),
                      ),
                    ),
                    iconColor: AppTheme.primaryGold,
                    collapsedIconColor: AurumConsumerTheme.muted(context),
                    children: [
                      Text(
                        insight.content,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: isDark
                              ? const Color(0xFFCBD5E1)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GoldInsight {
  final IconData icon;
  final String title;
  final String subtitle;
  final String content;

  const _GoldInsight({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.content,
  });
}
