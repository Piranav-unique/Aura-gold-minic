import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_history.dart';
import 'package:ags_gold/features/user_dashboard/domain/metal_prices.dart';
import 'package:ags_gold/features/user_dashboard/presentation/providers/metal_price_history_provider.dart';
import 'package:ags_gold/l10n/l10n_extension.dart';

class AurumLiveGoldCard extends ConsumerStatefulWidget {
  final double livePricePerGram;
  final double change24hPct;
  final List<MetalPricePoint> initialTrend;
  final VoidCallback? onChartTap;

  const AurumLiveGoldCard({
    super.key,
    required this.livePricePerGram,
    this.change24hPct = 0.0,
    this.initialTrend = const [],
    this.onChartTap,
  });

  @override
  ConsumerState<AurumLiveGoldCard> createState() => _AurumLiveGoldCardState();
}

class _AurumLiveGoldCardState extends ConsumerState<AurumLiveGoldCard> {
  String _selectedRange = '1D';

  final List<String> _ranges = ['1D', '1W', '1M', '1Y', 'ALL'];

  MetalHistoryRange get _apiRangeForSelection {
    return switch (_selectedRange) {
      '1Y' => MetalHistoryRange.y1,
      'ALL' => MetalHistoryRange.y3,
      _ => MetalHistoryRange.m1,
    };
  }

  List<double> _resolveRealTrendPoints(MetalHistory? history) {
    final live = widget.livePricePerGram > 0 ? widget.livePricePerGram : 15736.0;
    final rawPoints = (history != null && history.points.length >= 2)
        ? history.points.map((p) => p.price).where((p) => p > 0).toList()
        : widget.initialTrend.map((p) => p.price).where((p) => p > 0).toList();

    if (rawPoints.length < 2) {
      return [live, live];
    }

    final points = List<double>.from(rawPoints);
    points[points.length - 1] = live;

    return switch (_selectedRange) {
      '1D' => points.length > 7 ? points.sublist(points.length - 7) : points,
      '1W' => points.length > 8 ? points.sublist(points.length - 8) : points,
      _ => points,
    };
  }

  double _resolveRealChangePercent(MetalHistory? history, List<double> points) {
    if (_selectedRange == '1D') {
      if (widget.change24hPct != 0) {
        return widget.change24hPct;
      }
      if (points.length >= 2 && points[points.length - 2] > 0) {
        final prev = points[points.length - 2];
        final curr = points.last;
        return ((curr - prev) / prev) * 100.0;
      }
      return 0.0;
    }

    if (_selectedRange == '1W') {
      if (points.length >= 2 && points.first > 0) {
        return ((points.last - points.first) / points.first) * 100.0;
      }
      return widget.change24hPct;
    }

    if (history != null && history.points.length >= 2) {
      return history.performancePercent;
    }

    if (points.length >= 2 && points.first > 0) {
      return ((points.last - points.first) / points.first) * 100.0;
    }
    return widget.change24hPct;
  }

  String get _rangeBadgeLabel => _selectedRange == '1D' ? '24h' : _selectedRange;

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final isDark = AurumConsumerTheme.isDark(context);
    final historyAsync = ref.watch(
      metalHistoryProvider((
        metal: MetalType.gold,
        range: _apiRangeForSelection,
      )),
    );
    final history = historyAsync.asData?.value;
    final trendPoints = _resolveRealTrendPoints(history);
    final activeChangePct = _resolveRealChangePercent(history, trendPoints);
    final isPositive = activeChangePct >= 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurumConsumerTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AurumConsumerTheme.borderOf(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Live Gold Price + Live status dot
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        context.l10n.liveGoldPrice,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AurumConsumerTheme.muted(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 3,
                            backgroundColor: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.liveTag,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // View Full Chart Link
              if (widget.onChartTap != null)
                InkWell(
                  onTap: widget.onChartTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.fullChart,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: AppTheme.primaryGold,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Price & range change
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '${currencyFormatter.format(widget.livePricePerGram)}/g',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : const Color(0xFF1E1A14),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 14,
                    color: isPositive ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
                  Text(
                    '${isPositive ? '+' : ''}${activeChangePct.toStringAsFixed(2)}% ($_rangeBadgeLabel)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isPositive ? const Color(0xFF10B981) : Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sparkline Area Chart
          SizedBox(
            height: 70,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklineChartPainter(
                points: trendPoints,
                lineColor: AppTheme.primaryGold,
                fillGradient: LinearGradient(
                  colors: [
                    AppTheme.primaryGold.withValues(alpha: 0.35),
                    AppTheme.primaryGold.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Timeframe Pills: 1D, 1W, 1M, 1Y, ALL
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _ranges.map((range) {
              final isSelected = range == _selectedRange;
              return InkWell(
                onTap: () => setState(() => _selectedRange = range),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF38290D) : const Color(0xFFFBF4DC))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryGold
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    range,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primaryGold
                          : AurumConsumerTheme.muted(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SparklineChartPainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;
  final Gradient fillGradient;

  _SparklineChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillGradient,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minVal = points.reduce((a, b) => a < b ? a : b);
    final maxVal = points.reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final stepX = size.width / (points.length - 1);

    final linePath = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final normalizedY = (points[i] - minVal) / range;
      // Invert Y because canvas origin (0,0) is top-left
      final y = size.height - (normalizedY * (size.height - 12)) - 6;

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        // Smooth bezier curve between points
        final prevX = (i - 1) * stepX;
        final prevNormY = (points[i - 1] - minVal) / range;
        final prevY = size.height - (prevNormY * (size.height - 12)) - 6;
        final midX = (prevX + x) / 2;
        linePath.cubicTo(midX, prevY, midX, y, x, y);
        fillPath.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw Gradient Fill
    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw Line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // Draw pulse dot on the last point
    final lastX = size.width;
    final lastY = size.height - ((points.last - minVal) / range * (size.height - 12)) - 6;
    final dotPaint = Paint()..color = lineColor;
    final dotRingPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
    canvas.drawCircle(Offset(lastX, lastY), 7, dotRingPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
