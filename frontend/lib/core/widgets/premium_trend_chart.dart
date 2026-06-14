import 'package:flutter/material.dart';
import 'package:ags_gold/core/theme/app_theme.dart';

/// Reusable line chart for analytics dashboards and reports.
class PremiumTrendChart extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final String? badge;

  const PremiumTrendChart({
    super.key,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.labels,
    this.lineColor = AppTheme.primaryGold,
    this.badge,
  });

  @override
  State<PremiumTrendChart> createState() => _PremiumTrendChartState();
}

class _PremiumTrendChartState extends State<PremiumTrendChart> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = widget.values.isEmpty
        ? List<double>.filled(7, 0.0)
        : widget.values;
    final labels = widget.labels.isEmpty
        ? ['—', '—', '—', '—', '—', '—', '—']
        : widget.labels;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.lineColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.badge!,
                      style: TextStyle(
                        color: widget.lineColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: _TrendChartPainter(
                  values: values,
                  labels: labels,
                  lineColor: widget.lineColor,
                  hoveredIndex: _hoveredIndex,
                  isDark: theme.brightness == Brightness.dark,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final x = details.localPosition.dx;
                    final idx = ((x / box.size.width) * values.length)
                        .floor()
                        .clamp(0, values.length - 1);
                    if (idx != _hoveredIndex) {
                      setState(() => _hoveredIndex = idx);
                    }
                  },
                  onPanEnd: (_) => setState(() => _hoveredIndex = -1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final Color lineColor;
  final int hoveredIndex;
  final bool isDark;

  _TrendChartPainter({
    required this.values,
    required this.labels,
    required this.lineColor,
    required this.hoveredIndex,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final chartMax = maxVal <= 0 ? 1.0 : maxVal * 1.1;
    final bottom = size.height - 28;
    final stepX = size.width / (values.length - 1).clamp(1, values.length);

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = bottom - (bottom * i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    final fillPath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = bottom - (values[i] / chartMax) * bottom;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, bottom);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo((values.length - 1) * stepX, bottom);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.25),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, bottom)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    final labelStyle = TextStyle(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
      fontSize: 10,
    );
    for (var i = 0; i < labels.length && i < values.length; i++) {
      final x = i * stepX;
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i].length > 6
              ? labels[i].substring(labels[i].length - 5)
              : labels[i],
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, bottom + 8));
    }

    if (hoveredIndex >= 0 && hoveredIndex < values.length) {
      final x = hoveredIndex * stepX;
      final y = bottom - (values[hoveredIndex] / chartMax) * bottom;
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.hoveredIndex != hoveredIndex;
}
