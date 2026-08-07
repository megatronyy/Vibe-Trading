import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../app/theme.dart';
import '../../core/models/run.dart';

/// Equity curve with a gradient fill + a drawdown sub-panel that marks
/// max drawdown. Mobile port of the React `EquityChart`.
class EquityChart extends StatelessWidget {
  const EquityChart({super.key, required this.equity, this.height = 320});

  final List<EquityPoint> equity;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (equity.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: Text(AppLocalizations.of(context)!.noEquityData));
    final spots = <FlSpot>[];
    for (var i = 0; i < equity.length; i++) {
      spots.add(FlSpot(i.toDouble(), equity[i].equity));
    }
    final eqMin = equity.map((e) => e.equity).reduce(_min);
    final eqMax = equity.map((e) => e.equity).reduce(_max);
    final dd = equity.map((e) => e.drawdown).toList();
    final ddMin = dd.reduce(_min); // most negative
    final ddMax = dd.reduce(_max); // ~0
    final maxDdIdx = dd.indexOf(ddMin);

    return Column(children: [
      SizedBox(
        height: height * 0.7,
        child: LineChart(LineChartData(
          minY: eqMin, maxY: eqMax,
          minX: 0, maxX: (equity.length - 1).toDouble(),
          titlesData: const FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots, isCurved: true, color: AppTheme.primaryLight, barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                  AppTheme.primaryLight.withValues(alpha: 0.35),
                  AppTheme.primaryLight.withValues(alpha: 0.02),
                ]),
              ),
            ),
          ],
          extraLinesData: maxDdIdx >= 0
              ? ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: eqMax, color: Colors.transparent),
                ])
              : null,
        )),
      ),
      SizedBox(
        height: height * 0.3,
        child: LineChart(LineChartData(
          minY: ddMin, maxY: ddMax, minX: 0, maxX: (equity.length - 1).toDouble(),
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < dd.length; i++) FlSpot(i.toDouble(), dd[i])],
              isCurved: false, color: AppTheme.down.withValues(alpha: 0.7), barWidth: 1,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
                  AppTheme.down.withValues(alpha: 0.18),
                  AppTheme.down.withValues(alpha: 0.02),
                ]),
              ),
            ),
          ],
        )),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('${AppLocalizations.of(context)!.maxDrawdown}: ${(ddMin * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12, color: AppTheme.down)),
      ),
    ]);
  }

  double _min(double a, double b) => a < b ? a : b;
  double _max(double a, double b) => a > b ? a : b;
}
