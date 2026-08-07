import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/models/run.dart';

/// Tiny sparkline equity curve, colored green/red by overall direction.
/// Used inside `RunCompleteCard` (lazy) and `Compare`.
class MiniEquityChart extends StatelessWidget {
  const MiniEquityChart({super.key, required this.equity, this.height = 40});

  final List<EquityPoint> equity;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (equity.length < 2) return SizedBox(height: height);
    final up = equity.last.equity >= equity.first.equity;
    final color = up ? AppTheme.up : AppTheme.down;
    final spots = <FlSpot>[];
    // Down-sample to ~60 points for perf.
    final step = (equity.length / 60).ceil();
    for (var i = 0; i < equity.length; i += step) {
      spots.add(FlSpot(i.toDouble(), equity[i].equity));
    }
    if (spots.last.x != (equity.length - 1).toDouble()) {
      spots.add(FlSpot((equity.length - 1).toDouble(), equity.last.equity));
    }
    return SizedBox(
      height: height,
      child: LineChart(LineChartData(
        minX: spots.first.x, maxX: spots.last.x,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots, isCurved: true, color: color, barWidth: 1.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      )),
    );
  }
}
