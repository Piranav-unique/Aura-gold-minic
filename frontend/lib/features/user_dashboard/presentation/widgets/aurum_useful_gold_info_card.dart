import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';

class AurumUsefulGoldInfoCard extends StatelessWidget {
  const AurumUsefulGoldInfoCard({super.key});

  final List<_GoldInsight> _insights = const [
    _GoldInsight(
      icon: Icons.verified_rounded,
      title: '24K 99.9% BIS Hallmarked Purity',
      subtitle: 'Government certified purest 24 Karat gold',
      content:
          'Every gram you save is genuine 24 Karat (99.9% pure) gold meeting official BIS hallmarking standards, with zero compromise on purity.',
    ),
    _GoldInsight(
      icon: Icons.trending_up_rounded,
      title: 'Better Returns Than Bank Savings',
      subtitle: 'Protect your money from price rises',
      content:
          'Gold has historically given strong long-term growth in India. Saving small amounts in gold helps protect your hard-earned money from inflation far better than idle bank deposits.',
    ),
    _GoldInsight(
      icon: Icons.price_check_rounded,
      title: 'Zero Making Charges When Buying',
      subtitle: 'Pay only for pure gold, no wastage',
      content:
          'Traditional jewellery shops charge 10% to 20% in making charges and wastage. Here, 100% of your money buys pure gold at live market prices with clear 3% GST.',
    ),
    _GoldInsight(
      icon: Icons.storefront_rounded,
      title: 'Easy Cashout or Collect from Shop',
      subtitle: 'Transfer money to bank or get real gold coins',
      content:
          'Whenever you need funds, sell your gold instantly for direct bank deposit at live rates, or visit our trusted showroom to take delivery of your physical gold coins.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = AurumConsumerTheme.isDark(context);

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
                  'Why Save in Digital Gold?',
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
            itemCount: _insights.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: AurumConsumerTheme.borderOf(context).withValues(alpha: 0.5),
            ),
            itemBuilder: (context, index) {
              final insight = _insights[index];

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
