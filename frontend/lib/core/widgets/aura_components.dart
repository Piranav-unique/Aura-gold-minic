import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';

/// Shared Aura Gold cream + gold presentational building blocks.
///
/// These widgets are intentionally "dumb" (data + callbacks in, UI out) so the
/// same visual language can be reused across consumer and admin screens without
/// coupling to providers or business logic.

/// A white surface card with a soft warm shadow and rounded corners.
///
/// The default look matches the reference designs: pure white, ~20px radius,
/// subtle ambient shadow, hairline border. It follows the ambient [Theme] so it
/// also reads correctly in dark mode.
class AuraCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final bool border;
  final List<BoxShadow>? shadow;

  const AuraCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.radius = 20,
    this.onTap,
    this.border = true,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = color ?? theme.cardColor;
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: border
            ? Border.all(color: theme.dividerColor, width: 1)
            : null,
        boxShadow: shadow ?? (isDark ? null : AppTheme.softShadow),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// A hero card filled with the warm gold gradient (or a custom [gradient] /
/// solid [color], e.g. silver or black). Used for the primary "value" cards.
class GoldGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final List<BoxShadow>? shadow;
  final double radius;
  final VoidCallback? onTap;

  const GoldGradientCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.gradient,
    this.color,
    this.shadow,
    this.radius = 22,
    this.onTap,
  });

  /// Neutral silver-metal surface variant.
  const GoldGradientCard.silver({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.onTap,
  })  : gradient = null,
        color = AppTheme.silverSurface,
        shadow = const [];

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: color == null ? (gradient ?? AppTheme.goldGradient) : null,
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ?? AppTheme.goldGlowShadow,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}

/// A small feature/trust badge card (e.g. "100% INSURED", "24K PURITY").
class FeatureBadgeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const FeatureBadgeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return AuraCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      border: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 26),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: muted, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// A labelled progress bar with an optional percent and caption, used for
/// milestone / scheme progress. The fill uses the gold gradient.
class MilestoneProgressBar extends StatelessWidget {
  final String title;
  final double progress; // 0..1
  final String? percentLabel;
  final String? caption;
  final IconData? captionIcon;

  const MilestoneProgressBar({
    super.key,
    required this.title,
    required this.progress,
    this.percentLabel,
    this.caption,
    this.captionIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final clamped = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (percentLabel != null)
              Text(
                percentLabel!,
                style: const TextStyle(
                  color: AppTheme.goldDeep,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(
                height: 10,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              FractionallySizedBox(
                widthFactor: clamped == 0 ? 0.001 : clamped,
                child: Container(
                  height: 10,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.goldGradient,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (captionIcon != null) ...[
                Icon(captionIcon, size: 15, color: muted),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  caption!,
                  style: TextStyle(color: muted, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A compact stat cell: a value with a caption label underneath (or above).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool labelOnTop;
  final CrossAxisAlignment align;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.labelOnTop = false,
    this.align = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final labelWidget = Text(
      label,
      style: TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
    final valueWidget = Text(
      value,
      style: TextStyle(
        color: valueColor ?? theme.colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: labelOnTop
          ? [labelWidget, const SizedBox(height: 4), valueWidget]
          : [valueWidget, const SizedBox(height: 4), labelWidget],
    );
  }
}

/// A section header with a bold title and an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  color: AppTheme.goldDeep,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A list row with a circular gold-tinted leading icon, a title/subtitle, and
/// an optional trailing value + sub-value (e.g. a savings/transaction entry).
class ListRowTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final String? trailingSub;
  final Color? trailingColor;
  final VoidCallback? onTap;

  const ListRowTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.trailingSub,
    this.trailingColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.goldDeep, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trailing!,
                    style: TextStyle(
                      color: trailingColor ?? theme.colorScheme.onSurface,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (trailingSub != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      trailingSub!,
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A live gold/silver price hero card with Buy / Sell actions, matching the
/// home screen reference. Gold uses the gradient; silver uses a neutral surface.
class MetalPriceCard extends StatelessWidget {
  final String label; // e.g. "LIVE GOLD PRICE"
  final bool isGold;
  final String price; // formatted price
  final String unit; // e.g. "/g"
  final String changeText; // e.g. "+₹42 (0.68%)"
  final bool changePositive;
  final String holdingText; // e.g. "Holding: 3.2g"
  final VoidCallback? onBuy;
  final VoidCallback? onSell;
  final VoidCallback? onTap;

  const MetalPriceCard({
    super.key,
    required this.label,
    required this.isGold,
    required this.price,
    required this.changeText,
    required this.changePositive,
    required this.holdingText,
    this.unit = '/g',
    this.onBuy,
    this.onSell,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Foreground palette differs between the gold gradient and the silver card.
    final Color titleColor =
        isGold ? AppTheme.goldDeep : theme.colorScheme.onSurface;
    final Color valueColor =
        isGold ? const Color(0xFF20180A) : theme.colorScheme.onSurface;
    final Color mutedColor = isGold
        ? AppTheme.onGoldMuted
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final Color chipBg = isGold
        ? const Color(0x33FFFFFF)
        : theme.colorScheme.surfaceContainerHighest;
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              changePositive ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: titleColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Icon(Icons.more_horiz, size: 18, color: mutedColor),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              price,
              style: TextStyle(
                color: valueColor,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: TextStyle(
                color: mutedColor,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              changeText,
              style: TextStyle(
                color: isGold
                    ? AppTheme.onGoldMuted
                    : (changePositive ? AppTheme.emerald : AppTheme.rose),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                holdingText,
                style: TextStyle(
                  color: isGold ? AppTheme.goldDeep : mutedColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _MetalActionButton(
                label: 'Buy',
                icon: Icons.add,
                onTap: onBuy,
                filled: true,
                isGold: isGold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetalActionButton(
                label: 'Sell',
                icon: Icons.remove,
                onTap: onSell,
                filled: false,
                isGold: isGold,
              ),
            ),
          ],
        ),
      ],
    );

    if (isGold) {
      return GoldGradientCard(onTap: onTap, child: card);
    }
    return GoldGradientCard.silver(onTap: onTap, child: card);
  }
}

class _MetalActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool isGold;

  const _MetalActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    required this.isGold,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final Color bg;
    late final Color fg;
    if (isGold) {
      // On gold: primary = dark ink pill, secondary = translucent white.
      bg = filled ? const Color(0xFF2A1F08) : const Color(0x33FFFFFF);
      fg = filled ? const Color(0xFFF3E7C4) : AppTheme.goldDeep;
    } else {
      bg = filled
          ? theme.colorScheme.onSurface.withValues(alpha: 0.85)
          : theme.colorScheme.surface;
      fg = filled ? theme.colorScheme.surface : theme.colorScheme.onSurface;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dark "call to action" banner (e.g. "Start SIP in 10 seconds").
class DarkCtaBanner extends StatelessWidget {
  final String label;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const DarkCtaBanner({
    super.key,
    required this.label,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.ctaBlack,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: 8),
                Icon(trailingIcon, color: AppTheme.primaryGold, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
