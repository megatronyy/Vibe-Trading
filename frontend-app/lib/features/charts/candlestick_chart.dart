import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../app/theme.dart';
import '../../core/models/run.dart';
import '../../core/util/indicators.dart';

/// Candlestick chart with MA/EMA/BOLL overlays and a volume / MACD / RSI / KDJ
/// sub-panel — mobile port of the React `CandlestickChart`.
///
/// Design (plan §6.3):
/// - Candlesticks: fl_chart 1.x `CandlestickChart` with a built-in
///   `FlTransformationConfig` (pinch-zoom / pan = mobile dataZoom).
/// - MA/EMA/BOLL overlays: a transparent `LineChart` stacked on top, sharing
///   the same `transformationController` + axis bounds so it pans/zooms in sync
///   (CandlestickChartData has no native line-overlay series).
/// - Range presets (1M/3M/6M/1Y/ALL) replace the desktop bottom slider.
///   Trade B/S markers are deferred to P2-polish (need a dot-painter overlay).
class CandleChart extends StatefulWidget {
  const CandleChart({
    super.key,
    required this.bars,
    this.height = 420,
  });

  final List<PriceBar> bars;
  final double height;

  @override
  State<CandleChart> createState() => _CandleChartState();
}

enum _Sub { vol, macd, rsi, kdj }

class _CandleChartState extends State<CandleChart> {
  _Sub _sub = _Sub.vol;
  String _range = 'ALL';
  final _ctrl = TransformationController();
  final _overlays = <String>{'MA5', 'MA20'};

  static const _ranges = {'1M': 22, '3M': 63, '6M': 126, '1Y': 252, 'ALL': 1 << 30};
  static const _overlayColors = <Color>[
    AppTheme.primaryLight, Color(0xFF8B5CF6), Color(0xFF3B82F6),
    Color(0xFFEC4899), Color(0xFF10B981), Color(0xFFF97316), Color(0xFF6366F1),
  ];

  List<PriceBar> get _windowed {
    final n = _ranges[_range]!;
    if (n >= widget.bars.length) return widget.bars;
    return widget.bars.sublist(widget.bars.length - n);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bars = _windowed;
    if (bars.isEmpty) {
      return Padding(padding: const EdgeInsets.all(16), child: Text(AppLocalizations.of(context)!.noPriceData));
    }
    final closes = bars.map((b) => b.close).toList();
    final highs = bars.map((b) => b.high).toList();
    final lows = bars.map((b) => b.low).toList();

    final candleSpots = <CandlestickSpot>[];
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      candleSpots.add(CandlestickSpot(
          x: i.toDouble(), open: b.open, high: b.high, low: b.low, close: b.close));
    }

    final ma = {
      'MA5': calcMA(closes, 5), 'MA10': calcMA(closes, 10), 'MA20': calcMA(closes, 20),
      'MA60': calcMA(closes, 60), 'EMA12': calcEMA(closes, 12), 'EMA26': calcEMA(closes, 26),
    };
    final boll = calcBOLL(closes, 20, 2);
    final overlayLines = <LineChartBarData>[];
    var ci = 0;
    for (final e in ma.entries) {
      if (_overlays.contains(e.key)) {
        overlayLines.add(_line(e.value, _overlayColors[ci++ % _overlayColors.length]));
      }
    }
    if (_overlays.contains('BOLL')) {
      overlayLines.add(_line(boll.upper, AppTheme.primaryLight, dashed: true));
      overlayLines.add(_line(boll.mid, AppTheme.primaryLight));
      overlayLines.add(_line(boll.lower, AppTheme.primaryLight, dashed: true));
    }

    final yMin = lows.reduce(min);
    final yMax = highs.reduce(max);
    final pad = (yMax - yMin) * 0.05;
    final tf = FlTransformationConfig(
        minScale: 1, maxScale: 6, panEnabled: true, scaleEnabled: true,
        transformationController: _ctrl);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _toolbar(),
      SizedBox(
        height: widget.height * 0.72,
        child: Stack(children: [
          CandlestickChart(
            CandlestickChartData(
              candlestickSpots: candleSpots,
              minX: 0, maxX: (bars.length - 1).toDouble(),
              minY: yMin - pad, maxY: yMax + pad,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 44)),
              ),
            ),
            transformationConfig: tf,
          ),
          if (overlayLines.isNotEmpty)
            LineChart(
              LineChartData(
                minX: 0, maxX: (bars.length - 1).toDouble(),
                minY: yMin - pad, maxY: yMax + pad,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(show: false),
                lineBarsData: overlayLines,
              ),
              transformationConfig: tf,
            ),
        ]),
      ),
      SizedBox(height: widget.height * 0.28, child: _subChart(closes, highs, lows)),
    ]);
  }

  double min(double a, double b) => a < b ? a : b;
  double max(double a, double b) => a > b ? a : b;

  Widget _toolbar() => Wrap(
        spacing: 4, runSpacing: 4,
        children: [
          for (final r in const ['1M', '3M', '6M', '1Y', 'ALL'])
            ChoiceChip(label: Text(r, style: const TextStyle(fontSize: 11)),
                selected: _range == r, visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _range = r)),
          const SizedBox(width: 8),
          for (final o in const ['MA5', 'MA10', 'MA20', 'MA60', 'EMA12', 'EMA26', 'BOLL'])
            FilterChip(label: Text(o, style: const TextStyle(fontSize: 11)),
                selected: _overlays.contains(o), visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() {
                  if (_overlays.contains(o)) { _overlays.remove(o); } else { _overlays.add(o); }
                })),
          const SizedBox(width: 8),
          for (final s in _Sub.values)
            ChoiceChip(label: Text(s.name, style: const TextStyle(fontSize: 11)),
                selected: _sub == s, visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _sub = s)),
        ],
      );

  LineChartBarData _line(List<double?> data, Color color, {bool dashed = false}) =>
      LineChartBarData(
        spots: [for (var i = 0; i < data.length; i++) if (data[i] != null) FlSpot(i.toDouble(), data[i]!)],
        isCurved: false, color: color, barWidth: dashed ? 0.8 : 1,
        dashArray: dashed ? [4, 4] : null,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );

  Widget _subChart(List<double> closes, List<double> highs, List<double> lows) {
    switch (_sub) {
      case _Sub.vol:
        final rods = <BarChartRodData>[];
        for (final b in _windowed) {
          final up = b.close >= b.open;
          rods.add(BarChartRodData(
            toY: b.volume,
            color: up ? AppTheme.up.withValues(alpha: 0.5) : AppTheme.down.withValues(alpha: 0.5),
            width: 3,
          ));
        }
        final maxY = rods.map((r) => r.toY).reduce(max) * 1.1;
        return BarChart(BarChartData(
          maxY: maxY,
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          alignment: BarChartAlignment.spaceBetween,
          barGroups: [BarChartGroupData(x: 0, barRods: rods)],
        ));
      case _Sub.macd:
        final m = calcMACD(closes);
        return _linesChart([_spots(m.dif, AppTheme.info), _spots(m.signal, AppTheme.warning)]);
      case _Sub.rsi:
        final rsi = calcRSI(closes);
        return _linesChart([_spots(rsi, AppTheme.info)], yMin: 0, yMax: 100);
      case _Sub.kdj:
        final k = calcKDJ(highs, lows, closes);
        return _linesChart([
          _spots(k.k, AppTheme.info), _spots(k.d, AppTheme.warning), _spots(k.j, const Color(0xFFA855F7)),
        ]);
    }
  }

  List<FlSpot> _spots(List<double?> data, Color _) =>
      [for (var i = 0; i < data.length; i++) if (data[i] != null) FlSpot(i.toDouble(), data[i]!)];

  Widget _linesChart(List<List<FlSpot>> lines, {double? yMin, double? yMax}) {
    return LineChart(LineChartData(
      minY: yMin, maxY: yMax,
      titlesData: const FlTitlesData(show: false),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        for (final l in lines)
          LineChartBarData(
            spots: l, isCurved: false, color: AppTheme.info, barWidth: 1,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
      ],
    ));
  }
}
