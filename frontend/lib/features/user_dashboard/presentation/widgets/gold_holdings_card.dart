import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/logging/app_event_log.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/core/widgets/aura_components.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme.dart';
import 'package:ags_gold/features/user_dashboard/domain/gold_scheme_utils.dart';
import 'package:ags_gold/features/user_dashboard/domain/kyc_status.dart';
import 'package:ags_gold/features/user_dashboard/domain/market_linked_holdings.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/gold_scheme_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_prices_provider.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/kyc_trading_prompt_dialog.dart';
import 'package:ags_gold/features/user_dashboard/presentation/widgets/scheme_completion_dialog.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';
import 'package:ags_gold/services/api_client.dart';

/// Merged "portfolio" card: gold holdings hero on top with Buy/Sell, and the
/// gold savings plan directly below. Buying is unlocked only after the user
/// completes KYC and joins a savings plan. Once a plan is active it collapses to
/// a compact summary with a "Change plan" action.
class GoldHoldingsCard extends ConsumerStatefulWidget {
  final double goldGrams;
  final double goldInvestedInr;
  final KycStatus kycStatus;
  final GoldScheme? goldScheme;

  const GoldHoldingsCard({
    super.key,
    required this.goldGrams,
    required this.goldInvestedInr,
    required this.kycStatus,
    this.goldScheme,
  });

  @override
  ConsumerState<GoldHoldingsCard> createState() => _GoldHoldingsCardState();
}

class _GoldHoldingsCardState extends ConsumerState<GoldHoldingsCard> {
  bool _joining = false;

  bool get _kycReady => widget.kycStatus.isComplete;

  bool get _schemeJoined {
    final s = widget.goldScheme;
    return s != null && (s.status.isActive || s.status.isCompleted);
  }

  Future<void> _promptKyc({required bool isBuy}) {
    return showKycTradingPrompt(
      context,
      ref,
      isBuy: isBuy,
      metal: MetalType.gold,
    );
  }

  Future<void> _onBuy() async {
    if (!_kycReady) {
      await _promptKyc(isBuy: true);
      return;
    }
    if (!_schemeJoined) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.goldSchemeSelectBeforeBuy)),
      );
      return;
    }
    AppEventLog.action('buy_gold_tap', data: {'kyc_complete': true});
    context.push('/buy-gold?metal=gold');
  }

  Future<void> _onSell() async {
    final l10n = context.l10n;
    final scheme = widget.goldScheme;
    final canSell = scheme?.canSell ?? false;
    if (!canSell) {
      final message = (scheme?.savedGrams ?? 0) <= 0
          ? l10n.sellBuyGoldFirst
          : (scheme?.sellLockedReason ?? l10n.goldSchemeSellLocked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    if (!_kycReady) {
      await _promptKyc(isBuy: false);
      return;
    }
    AppEventLog.action('sell_gold_tap', data: {'kyc_complete': true});
    context.push('/sell-gold-inquiry');
  }

  void _onTierTap(int grams) {
    if (!_kycReady) {
      _promptKyc(isBuy: true);
      return;
    }
    AppEventLog.action('scheme_tier_selected', data: {'grams': grams});
    ref.read(pendingGoldSchemeGramsProvider.notifier).state = grams;
  }

  Future<void> _joinScheme(int grams) async {
    if (_joining) return;
    setState(() => _joining = true);
    AppEventLog.action('scheme_join', data: {'grams': grams});
    try {
      await ref.read(selectGoldSchemeProvider)(grams);
      ref.read(pendingGoldSchemeGramsProvider.notifier).state = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.goldSchemeSelected(grams))),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.goldSchemeSelectFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _showChangePlanSheet(List<int> higherTiers) async {
    final l10n = context.l10n;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  l10n.goldSchemeChangePlanTitle,
                  style: TextStyle(
                    color: AurumConsumerTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final grams in higherTiers)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.savings_outlined,
                      color: AppTheme.goldDeep,
                      size: 20,
                    ),
                  ),
                  title: Text(l10n.goldSchemeActiveBadge('$grams')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    handleSchemeUpgrade(
                      context: context,
                      ref: ref,
                      targetGrams: grams,
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.goldScheme;
    return AuraCard(
      border: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HoldingsHero(
            goldGrams: widget.goldGrams,
            goldInvestedInr: widget.goldInvestedInr,
            kycStatus: widget.kycStatus,
            scheme: scheme,
            liveRate:
                ref.watch(metalPricesProvider).asData?.value.gold.displayPrice ??
                    0,
            onBuy: _onBuy,
            onSell: _onSell,
          ),
          const SizedBox(height: 16),
          if (scheme == null || scheme.status.isNotSelected)
            _buildChooser(context)
          else
            _buildCompact(context, scheme),
        ],
      ),
    );
  }

  Widget _buildChooser(BuildContext context) {
    final l10n = context.l10n;
    final pendingGrams = ref.watch(pendingGoldSchemeGramsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SchemeHeaderRow(
          title: l10n.goldSchemeTitle,
          badge: l10n.goldSchemeChooseBadge,
          badgeColor: AurumConsumerTheme.chipGold,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.goldSchemeChooseSubtitle,
          style: TextStyle(
            color: AurumConsumerTheme.textMuted,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final grams in const [1, 5, 10]) ...[
              Expanded(
                child: _SchemeOption(
                  grams: grams,
                  selected: pendingGrams == grams,
                  onTap: () => _onTierTap(grams),
                ),
              ),
              if (grams != 10) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _joining
                ? null
                : () {
                    if (!_kycReady) {
                      _promptKyc(isBuy: true);
                      return;
                    }
                    if (pendingGrams == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.goldSchemeSelectBeforeBuy),
                        ),
                      );
                      return;
                    }
                    _joinScheme(pendingGrams);
                  },
            icon: _joining
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.savings_outlined, size: 18),
            label: Text(
              pendingGrams != null
                  ? l10n.goldSchemeCompletionUpgrade(pendingGrams)
                  : l10n.goldSchemeChooseBadge,
            ),
          ),
        ),
        if (!_kycReady) ...[
          const SizedBox(height: 10),
          _StatusLine(
            icon: Icons.lock_outline_rounded,
            text: l10n.goldSchemeKycRequired,
            color: AurumConsumerTheme.textMuted,
          ),
        ],
      ],
    );
  }

  Widget _buildCompact(BuildContext context, GoldScheme scheme) {
    final l10n = context.l10n;
    final higherTiers = goldSchemeHigherTiers(scheme);
    final isCompleted = scheme.status.isCompleted;
    final target = scheme.targetGrams ?? 0;
    final progress = (scheme.progressPercent / 100).clamp(0.0, 1.0);

    final String statusText = isCompleted
        ? l10n.goldSchemeSellUnlocked
        : l10n.goldSchemeProgressPercent(
            scheme.progressPercent.toStringAsFixed(0),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.savings_outlined,
                color: AppTheme.goldDeep,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.goldSchemeActiveBadge(target.toStringAsFixed(0)),
                    style: TextStyle(
                      color: AurumConsumerTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCompleted
                          ? AurumConsumerTheme.liveGreen
                          : AurumConsumerTheme.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (higherTiers.isNotEmpty)
              _ChangePlanButton(
                onTap: () {
                  if (!_kycReady) {
                    _promptKyc(isBuy: true);
                    return;
                  }
                  _showChangePlanSheet(higherTiers);
                },
              ),
          ],
        ),
        if (!isCompleted) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AurumConsumerTheme.border,
              color: AppTheme.primaryGold,
            ),
          ),
        ],
      ],
    );
  }
}

/// The gold-gradient holdings hero (numbers + Buy/Sell) shown at the top of the
/// merged portfolio card.
class _HoldingsHero extends StatelessWidget {
  final double goldGrams;
  final double goldInvestedInr;
  final KycStatus kycStatus;
  final GoldScheme? scheme;
  final double liveRate;
  final VoidCallback onBuy;
  final VoidCallback onSell;

  const _HoldingsHero({
    required this.goldGrams,
    required this.goldInvestedInr,
    required this.kycStatus,
    required this.scheme,
    required this.liveRate,
    required this.onBuy,
    required this.onSell,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    );
    final investedText =
        l10n.goldInvestedAmount(currency.format(goldInvestedInr));
    final hasLiveRate = liveRate > 0 && goldGrams > 0;
    final displayGrams = hasLiveRate
        ? MarketLinkedHoldings.marketLinkedGrams(
            storedGrams: goldGrams,
            investedInr: goldInvestedInr,
            liveRatePerGram: liveRate,
          )
        : goldGrams;
    final gramsText = '${displayGrams.toStringAsFixed(4)} g';
    final currentValue = hasLiveRate
        ? MarketLinkedHoldings.currentValueInr(
            storedGrams: goldGrams,
            liveRatePerGram: liveRate,
          )
        : 0.0;
    final gainInr = hasLiveRate ? currentValue - goldInvestedInr : 0.0;
    final gainPct =
        goldInvestedInr > 0 ? (gainInr / goldInvestedInr) * 100 : 0.0;

    final bool schemeJoined = scheme != null &&
        (scheme!.status.isActive || scheme!.status.isCompleted);
    String footerText;
    if (!kycStatus.isComplete) {
      footerText = l10n.completeKycToStartTrading;
    } else if (scheme != null && scheme!.status.isActive) {
      footerText = l10n.goldHoldingsSchemeActiveFooter;
    } else if (scheme != null && scheme!.status.isCompleted) {
      footerText = l10n.goldHoldingsFooterVerified;
    } else {
      footerText = l10n.goldHoldingsChooseSchemeFooter;
    }

    const Color onGold = Color(0xFF20180A);
    final Color gainColor = gainInr >= 0
        ? const Color(0xFF1E5B34)
        : const Color(0xFF7A2018);

    final bool buyLocked = !kycStatus.isComplete || !schemeJoined;
    final bool sellLocked =
        !kycStatus.isComplete || !(scheme?.canSell ?? false);

    return GoldGradientCard(
      padding: const EdgeInsets.all(18),
      shadow: const [],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.monetization_on_outlined,
                  color: onGold,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.goldHoldings,
                  style: const TextStyle(
                    color: AppTheme.goldDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (hasLiveRate)
                Text(
                  l10n.goldLiveAtMarketRate,
                  style: const TextStyle(
                    color: AppTheme.onGoldMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            gramsText,
            style: const TextStyle(
              color: onGold,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          if (hasLiveRate) ...[
            const SizedBox(height: 4),
            Text(
              l10n.goldCurrentValue(currency.format(currentValue)),
              style: const TextStyle(
                color: onGold,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (goldInvestedInr > 0) ...[
            const SizedBox(height: 6),
            Text(
              investedText,
              style: const TextStyle(color: AppTheme.onGoldMuted, fontSize: 14),
            ),
            if (hasLiveRate) ...[
              const SizedBox(height: 4),
              Text(
                '${gainInr >= 0 ? '+' : ''}${currency.format(gainInr)} (${gainPct >= 0 ? '+' : ''}${gainPct.toStringAsFixed(2)}%)',
                style: TextStyle(
                  color: gainColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _HeroActionButton(
                  label: l10n.buyGold,
                  icon: Icons.add_rounded,
                  primary: true,
                  locked: buyLocked,
                  onTap: onBuy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroActionButton(
                  label: l10n.sellGold,
                  icon: Icons.north_east_rounded,
                  primary: false,
                  locked: sellLocked,
                  onTap: onSell,
                ),
              ),
            ],
          ),
          if (footerText.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppTheme.onGoldMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    footerText,
                    style: const TextStyle(
                      color: AppTheme.onGoldMuted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool primary;
  final bool locked;
  final VoidCallback onTap;

  const _HeroActionButton({
    required this.label,
    required this.icon,
    required this.primary,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg =
        primary ? const Color(0xFF2A1F08) : const Color(0x33FFFFFF);
    final Color fg = primary ? const Color(0xFFF3E7C4) : AppTheme.goldDeep;
    return Opacity(
      opacity: locked ? 0.62 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(locked ? Icons.lock_outline_rounded : icon,
                    size: 16, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePlanButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ChangePlanButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.goldDeep,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
      label: Text(
        context.l10n.goldSchemeChangePlan,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatusLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _SchemeHeaderRow extends StatelessWidget {
  final String title;
  final String badge;
  final Color badgeColor;

  const _SchemeHeaderRow({
    required this.title,
    required this.badge,
    required this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.savings_outlined,
            color: AppTheme.primaryGold,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AurumConsumerTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SchemeOption extends StatelessWidget {
  final int grams;
  final bool selected;
  final VoidCallback onTap;

  const _SchemeOption({
    required this.grams,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? AppTheme.primaryGold.withValues(alpha: 0.16)
                : AppTheme.primaryGold.withValues(alpha: 0.06),
            border: selected
                ? Border.all(color: AppTheme.primaryGold, width: 2)
                : null,
          ),
          child: Column(
            children: [
              Text(
                '${grams}g',
                style: const TextStyle(
                  color: AppTheme.goldDeep,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.goldSchemeTierLabel(grams),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AurumConsumerTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
