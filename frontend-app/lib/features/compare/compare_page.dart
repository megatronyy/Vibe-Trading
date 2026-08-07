import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../app/theme.dart';
import '../../core/models/run.dart';
import '../../core/net/api.dart';
import '../../core/net/api_error.dart';

/// Side-by-side comparison of two runs: overlaid equity curves + a per-metric
/// card list (the React version's 4-column table reflows to one card/metric
/// on mobile). Metrics are the canonical 15 from `compare` i18n.
class ComparePage extends ConsumerStatefulWidget {
  const ComparePage({super.key});

  @override
  ConsumerState<ComparePage> createState() => _ComparePageState();
}

class _ComparePageState extends ConsumerState<ComparePage> {
  List<RunListItem> _runs = const [];
  String? _left;
  String? _right;
  RunData? _leftRun;
  RunData? _rightRun;
  bool _loading = false;

  static const _metricKeys = [
    ('total_return', '%'), ('annual_return', '%'), ('sharpe', ''),
    ('calmar_ratio', ''), ('sortino_ratio', ''), ('max_drawdown', '%'),
    ('volatility', '%'), ('win_rate', '%'), ('profit_factor', ''),
    ('avg_win', ''), ('avg_loss', ''), ('trade_count', '#'),
    ('max_consecutive_losses', '#'), ('exposure_time', '%'), ('avg_holding_period', ''),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final api = ref.read(apiProvider);
    try {
      final runs = await api.listRuns(100);
      setState(() {
        _runs = runs;
        if (runs.isNotEmpty) _left = runs.first.id;
        if (runs.length >= 2) _right = runs[1].id;
      });
      if (_left != null && _right != null) _compare();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _compare() async {
    if (_left == null || _right == null) return;
    setState(() => _loading = true);
    final api = ref.read(apiProvider);
    try {
      final results = await Future.wait([
        api.getRun(_left!),
        api.getRun(_right!),
      ]);
      setState(() {
        _leftRun = results[0];
        _rightRun = results[1];
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() => _loading = false);
      _toast(e.message);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.compareTitle)),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        Row(children: [
          Expanded(child: _dropdown((v) { _left = v; }, _left)),
          const Icon(Icons.compare_arrows),
          Expanded(child: _dropdown((v) { _right = v; }, _right)),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: (_left != null && _right != null && _left != _right && !_loading)
              ? _compare
              : null,
          icon: const Icon(Icons.play_arrow),
          label: Text(AppLocalizations.of(context)!.compareTitle),
        ),
        const SizedBox(height: 12),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_leftRun != null && _rightRun != null) ...[
          _equityOverlay(),
          const SizedBox(height: 12),
          for (final (key, unit) in _metricKeys) _metricCard(key, unit),
        ],
      ]),
    );
  }

  Widget _dropdown(void Function(String?) onPick, String? value) {
    return DropdownButton<String>(
      value: value, isExpanded: true,
      hint: Text(AppLocalizations.of(context)!.selectRun),
      items: [for (final r in _runs) DropdownMenuItem(value: r.id, child: Text((r.prompt ?? r.id), overflow: TextOverflow.ellipsis, maxLines: 1))],
      onChanged: (v) => setState(() => onPick(v)),
    );
  }

  Widget _equityOverlay() {
    final a = _leftRun?.equityCurve ?? const [];
    final b = _rightRun?.equityCurve ?? const [];
    if (a.isEmpty && b.isEmpty) return const SizedBox.shrink();
    final allY = <double>[];
    for (final e in a) { allY.add(e.equity); }
    for (final e in b) { allY.add(e.equity); }
    final min = allY.isEmpty ? 0.0 : allY.reduce(_min);
    final max = allY.isEmpty ? 1.0 : allY.reduce(_max);
    return SizedBox(
      height: 220,
      child: LineChart(LineChartData(
        minY: min, maxY: max,
        titlesData: const FlTitlesData(show: false),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          _line(a, AppTheme.primaryLight),
          _line(b, AppTheme.info),
        ],
      )),
    );
  }

  LineChartBarData _line(List<EquityPoint> eq, Color c) => LineChartBarData(
        spots: [for (var i = 0; i < eq.length; i++) FlSpot(i.toDouble(), eq[i].equity)],
        isCurved: true, color: c, barWidth: 2,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );

  Widget _metricCard(String key, String unit) {
    final l = _leftRun?.metrics?[key];
    final r = _rightRun?.metrics?[key];
    final delta = (l != null && r != null) ? r - l : null;
    final betterUp = key != 'max_drawdown' && key != 'volatility' && key != 'avg_loss' &&
        key != 'max_consecutive_losses';
    final good = delta == null ? null : (betterUp ? delta > 0 : delta < 0);
    String fmt(double? v) {
      if (v == null) return '—';
      switch (unit) {
        case '%': return '${(v * 100).toStringAsFixed(1)}%';
        case '#': return v.toStringAsFixed(0);
        default: return v.toStringAsFixed(2);
      }
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: Text(key, style: const TextStyle(fontSize: 13))),
          SizedBox(width: 60, child: Text(fmt(l), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace'))),
          SizedBox(width: 60, child: Text(fmt(r), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'monospace'))),
          SizedBox(
            width: 70,
            child: Text(
              delta == null ? '—' : '${delta >= 0 ? '+' : ''}${fmt(delta)}',
              textAlign: TextAlign.end,
              style: TextStyle(fontFamily: 'monospace', color: good == null ? null : (good ? Colors.green : Colors.red)),
            ),
          ),
        ]),
      ),
    );
  }

  double _min(double a, double b) => a < b ? a : b;
  double _max(double a, double b) => a > b ? a : b;
}
