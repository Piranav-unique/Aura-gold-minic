import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ags_gold/core/theme/app_theme.dart';
import 'package:ags_gold/core/theme/aurum_consumer_theme.dart';

class AurumLiveGoldCard extends StatefulWidget {
  final double livePricePerGram;
  final double change24hPct;
  final VoidCallback? onChartTap;

  const AurumLiveGoldCard({
    super.key,
    required this.livePricePerGram,
    this.change24hPct = 0.2,
    this.onChartTap,
  });

  @override
  State<AurumLiveGoldCard> createState() => _AurumLiveGoldCardState();
}

class _AurumLiveGoldCardState extends State<AurumLiveGoldCard> {
  String _selectedRange = '1D';

  final List<String> _ranges = ['1D', '1W', '1M', '1Y', 'ALL'];

  // Synthetic price trend points for the sparkline depending on timeframe
  List<double> get _trendPoints {
    final base = widget.livePricePerGram > 0 ? widget.livePricePerGram : 15736.0;
    return switch (_selectedRange) {
      '1D' => [base * 0.995, base * 0.997, base * 0.996, base * 0.999, base * 1.001, base * 1.002],
      '1W' => [base * 0.985, base * 0.989, base * 0.992, base * 0.995, base * 0.998, base * 1.002],
      '1M' => [base * 0.960, base * 0.972, base * 0.980, base * 0.990, base * 0.998, base * 1.002],
      '1Y' => [base * 0.850, base * 0.890, base * 0.930, base * 0.965, base * 0.985, base * 1.002],
      _ => [base * 0.700, base * 0.780, base * 0.860, base * 0.920, base * 0.970, base * 1.002],
    };
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final isDark = AurumConsumerTheme.isDark(context);
    final isPositive = widget.change24hPct >= 0;

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
                        'Live 24K Gold Price',
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 3,
                            backgroundColor: Color(0xFF10B981),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Live',
                            style: TextStyle(
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
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Full Chart',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                      Icon(
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

          // Price & 24h change
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
                    '${isPositive ? '+' : ''}${widget.change24hPct.toStringAsFixed(1)}% (24h)',
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
                points: _trendPoints,
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
