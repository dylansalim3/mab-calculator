import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../format.dart';

/// Minimal line / step chart. `values` are y-values at evenly spaced x.
class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    super.key,
    required this.values,
    this.xLabel,
    this.stepped = false,
    this.height = 160,
  });

  final List<double> values;
  final String Function(int index)? xLabel;
  final bool stepped;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    final scheme = Theme.of(context).colorScheme;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final summary =
        'Chart from ${Fmt.money(values.first)} to ${Fmt.money(values.last)}, '
        'low ${Fmt.money(minV)}, high ${Fmt.money(maxV)}';
    return Semantics(
      label: summary,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LinePainter(
              values: values,
              stepped: stepped,
              line: scheme.primary,
              area: scheme.primary.withValues(alpha: 0.12),
              grid: scheme.outlineVariant,
              text: scheme.onSurfaceVariant,
              xFirst: xLabel?.call(0),
              xLast: xLabel?.call(values.length - 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.stepped,
    required this.line,
    required this.area,
    required this.grid,
    required this.text,
    this.xFirst,
    this.xLast,
  });

  final List<double> values;
  final bool stepped;
  final Color line;
  final Color area;
  final Color grid;
  final Color text;
  final String? xFirst;
  final String? xLast;

  TextPainter _tp(String s) => TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(color: text, fontSize: 11),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 52.0;
    const bottomPad = 18.0;
    const topPad = 6.0;
    final plot = Rect.fromLTWH(
      leftPad,
      topPad,
      size.width - leftPad - 4,
      size.height - topPad - bottomPad,
    );
    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    if (maxV - minV < 1e-9) {
      final pad = maxV.abs() < 1 ? 1.0 : maxV.abs() * 0.05;
      minV -= pad;
      maxV += pad;
    }
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, gridPaint);
    canvas.drawLine(plot.topLeft, plot.topRight, gridPaint);

    final top = _tp(Fmt.money(maxV));
    top.paint(canvas, Offset(leftPad - top.width - 6, plot.top - 6));
    final bottom = _tp(Fmt.money(minV));
    bottom.paint(canvas, Offset(leftPad - bottom.width - 6, plot.bottom - 8));
    if (xFirst != null) {
      _tp(xFirst!).paint(canvas, Offset(plot.left, plot.bottom + 3));
    }
    if (xLast != null) {
      final t = _tp(xLast!);
      t.paint(canvas, Offset(plot.right - t.width, plot.bottom + 3));
    }

    double x(int i) => values.length == 1
        ? plot.left
        : plot.left + plot.width * i / (values.length - 1);
    double y(double v) =>
        plot.bottom - plot.height * (v - minV) / (maxV - minV);

    final path = Path()..moveTo(x(0), y(values[0]));
    for (var i = 1; i < values.length; i++) {
      if (stepped) path.lineTo(x(i), y(values[i - 1]));
      path.lineTo(x(i), y(values[i]));
    }
    final areaPath = Path.from(path)
      ..lineTo(x(values.length - 1), plot.bottom)
      ..lineTo(x(0), plot.bottom)
      ..close();
    canvas.drawPath(areaPath, Paint()..color = area);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.values != values || old.stepped != stepped || old.line != line;
}

class SplitPart {
  const SplitPart(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Stacked horizontal bar with a legend. Zero/negative parts are omitted.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.parts});

  final List<SplitPart> parts;

  @override
  Widget build(BuildContext context) {
    final shown = parts.where((p) => p.value > 0).toList();
    final total = shown.fold<double>(0, (s, p) => s + p.value);
    if (total <= 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final p in shown)
                  Expanded(
                    flex: math.max(1, (p.value / total * 1000).round()),
                    child: ColoredBox(color: p.color),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final p in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: p.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(p.label, style: theme.textTheme.bodyMedium),
                ),
                Text(
                  '${Fmt.money(p.value)} (${(p.value / total * 100).toStringAsFixed(1)}%)',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
