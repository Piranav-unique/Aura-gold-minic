import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';

/// A standardized dialog actions layout ensuring action and cancel buttons
/// have equal width (length), equal height, and are centered horizontally.
class AuraDialogActions extends StatelessWidget {
  final Widget? cancel;
  final Widget confirm;
  final double spacing;

  const AuraDialogActions({
    super.key,
    this.cancel,
    required this.confirm,
    this.spacing = 12,
  });

  /// Factory helper to build standardized equal-width, equal-height dialog buttons.
  static Widget buttons({
    required BuildContext context,
    String? cancelLabel,
    VoidCallback? onCancel,
    required String confirmLabel,
    VoidCallback? onConfirm,
    bool isDestructive = false,
    bool isLoading = false,
    Color? confirmColor,
    Color? confirmForegroundColor,
    double height = 46,
    double spacing = 12,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final resolvedConfirmBg = confirmColor ??
        (isDestructive ? AppTheme.rose : AppTheme.primaryGold);

    final resolvedConfirmFg = confirmForegroundColor ??
        (isDestructive ? Colors.white : AppTheme.ink);

    final confirmButton = FilledButton(
      onPressed: isLoading ? null : onConfirm,
      style: FilledButton.styleFrom(
        backgroundColor: resolvedConfirmBg,
        foregroundColor: resolvedConfirmFg,
        disabledBackgroundColor: resolvedConfirmBg.withValues(alpha: 0.6),
        disabledForegroundColor: resolvedConfirmFg.withValues(alpha: 0.6),
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: resolvedConfirmFg,
              ),
            )
          : Text(
              confirmLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
    );

    if (cancelLabel == null || onCancel == null) {
      return SizedBox(
        width: double.infinity,
        child: confirmButton,
      );
    }

    final cancelButton = OutlinedButton(
      onPressed: isLoading ? null : onCancel,
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white70 : AppTheme.ink,
        backgroundColor:
            isDark ? const Color(0xFF1E293B) : const Color(0xFFF7F5F0),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : AppTheme.creamBorder,
          width: 1.2,
        ),
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(
        cancelLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );

    return AuraDialogActions(
      cancel: cancelButton,
      confirm: confirmButton,
      spacing: spacing,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cancel == null) {
      return SizedBox(
        width: double.infinity,
        child: confirm,
      );
    }

    return Row(
      children: [
        Expanded(child: cancel!),
        SizedBox(width: spacing),
        Expanded(child: confirm),
      ],
    );
  }
}
