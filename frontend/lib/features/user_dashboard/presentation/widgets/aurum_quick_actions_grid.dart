import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';

class AurumQuickActionsGrid extends StatelessWidget {
  final VoidCallback onBuyGold;
  final VoidCallback onSchemeTap;
  final VoidCallback onSellGold;
  final VoidCallback onAddFunds;

  const AurumQuickActionsGrid({
    super.key,
    required this.onBuyGold,
    required this.onSchemeTap,
    required this.onSellGold,
    required this.onAddFunds,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Buy Gold',
            icon: Icons.monetization_on_rounded,
            iconGradient: const [Color(0xFFFFDF00), Color(0xFFD4AF37)],
            onTap: onBuyGold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'SIP / Scheme',
            icon: Icons.calendar_month_rounded,
            iconGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
            onTap: onSchemeTap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Sell Gold',
            icon: Icons.arrow_upward_rounded,
            iconGradient: const [Color(0xFFEAB308), Color(0xFFCA8A04)],
            onTap: onSellGold,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Add Funds',
            icon: Icons.account_balance_wallet_rounded,
            iconGradient: const [Color(0xFFD4AF37), Color(0xFF9A7B2F)],
            onTap: onAddFunds,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> iconGradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.iconGradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AurumConsumerTheme.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: AurumConsumerTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AurumConsumerTheme.borderOf(context),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: iconGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconGradient.first.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: const Color(0xFF3B2702),
                size: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1E1A14),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
