import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../core/util/share_file.dart';

import '../../core/models/run.dart';
import '../../core/net/api.dart';
import '../../core/net/api_error.dart';
import '../charts/candlestick_chart.dart';
import '../charts/equity_chart.dart';
import '../charts/validation_panel.dart';

/// Single backtest run: overview / chart / trades / run-card / code / validation
/// tabs. Mobile port of the React `RunDetail`. Lazy-loads per-symbol chart
/// data (`?chart_symbol=`) and exports Trades/Metrics CSV via `share_plus`.
class RunDetailPage extends ConsumerStatefulWidget {
  const RunDetailPage({super.key, required this.runId});
  final String runId;

  @override
  ConsumerState<RunDetailPage> createState() => _RunDetailPageState();
}

class _RunDetailPageState extends ConsumerState<RunDetailPage> {
  RunData? _run;
  bool _loading = true;
  String? _error;
  String? _symbol;
  final _loadedSymbols = <String>{};
  final _priceSeries = <String, List<PriceBar>>{};
  Map<String, String>? _code;
  String _codeFile = '';

  static const _tabKeys = [
    'overview', 'chart', 'trades', 'runCard', 'code', 'validation',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = ref.read(apiProvider);
    try {
      final run = await api.getRun(widget.runId, chartPayload: 'summary');
      _mergeSeries(run);
      setState(() {
        _run = run;
        _symbol = (run.chartSymbols?.isNotEmpty ?? false) ? run.chartSymbols!.first : null;
        _loading = false;
      });
      // Lazy-load the first symbol's chart data (chart_payload=summary omits
      // the bars), so the Chart tab isn't empty on open.
      final sym = _symbol;
      if (sym != null) _ensureSymbol(sym);
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      // Any other failure (e.g. a parse error) must not leave the page stuck
      // on the loading spinner — surface it instead.
      setState(() {
        _loading = false;
        _error = 'Failed to load run: $e';
      });
    }
  }

  void _mergeSeries(RunData run) {
    if (run.priceSeries != null) _priceSeries.addAll(run.priceSeries!);
  }

  /// True when the run has NO backtest artifacts at all (metrics, equity,
  /// trades, run card, validation, chart symbols) — e.g. a pure research /
  /// analysis run that never executed a backtest.
  bool get _hasNoData {
    final r = _run;
    if (r == null) return true;
    return (r.metrics == null || r.metrics!.isEmpty) &&
        (r.equityCurve == null || r.equityCurve!.isEmpty) &&
        (r.tradeLog == null || r.tradeLog!.isEmpty) &&
        (r.tradeMarkers == null || r.tradeMarkers!.isEmpty) &&
        r.runCard == null &&
        r.validation == null &&
        (r.chartSymbols == null || r.chartSymbols!.isEmpty);
  }

  Future<void> _ensureSymbol(String sym) async {
    if (_loadedSymbols.contains(sym)) return;
    try {
      final run = await ref.read(apiProvider).getRun(widget.runId, chartSymbol: sym);
      // Only mark loaded on success — a failed fetch stays retryable.
      _loadedSymbols.add(sym);
      _mergeSeries(run);
      if (mounted) setState(() {});
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      // Parse/merge failures shouldn't crash the tab; leave it retryable.
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabKeys.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          title: Text(_run?.runId ?? widget.runId, style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
          actions: [
            IconButton(
              tooltip: AppLocalizations.of(context)!.exportTradesCsv,
              icon: const Icon(Icons.table_chart_outlined),
              onPressed: _run == null ? null : () => _exportTrades(),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.exportMetricsCsv,
              icon: const Icon(Icons.analytics_outlined),
              onPressed: _run == null ? null : () => _exportMetrics(),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: AppLocalizations.of(context)!.tabOverview),
              Tab(text: AppLocalizations.of(context)!.tabChart),
              Tab(text: AppLocalizations.of(context)!.tabTrades),
              Tab(text: AppLocalizations.of(context)!.tabRunCard),
              Tab(text: AppLocalizations.of(context)!.tabCode),
              Tab(text: AppLocalizations.of(context)!.tabValidation),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                : _hasNoData
                    ? Center(child: Padding(padding: const EdgeInsets.all(24),
                        child: Text('该运行无回测产物（metrics/equity/trades 等），可能是一个纯研究/分析运行，未执行回测。',
                            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium)))
                    : TabBarView(
                    children: [
                      _overview(),
                      _chart(),
                      _trades(),
                      _runCard(),
                      _codeTab(),
                      _validation(),
                    ],
                  ),
      ),
    );
  }

  Widget _overview() {
    final m = _run?.metrics ?? const <String, double>{};
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (_run?.prompt != null)
        Card(child: ListTile(title: Text(_run!.prompt!), subtitle: Text('${_run!.status} · ${(_run!.elapsedSeconds ?? 0).toStringAsFixed(1)}s'))),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _metricTile(AppLocalizations.of(context)!.metricTotalReturn, m['total_return'], pct: true),
        _metricTile(AppLocalizations.of(context)!.metricAnnual, m['annual_return'], pct: true),
        _metricTile(AppLocalizations.of(context)!.metricMaxDD, m['max_drawdown'], pct: true, negColor: true),
        _metricTile(AppLocalizations.of(context)!.metricSharpe, m['sharpe']),
        _metricTile(AppLocalizations.of(context)!.metricWinRate, m['win_rate'], pct: true),
        _metricTile(AppLocalizations.of(context)!.metricTrades, m['trade_count']?.toDouble(), int: true),
      ]),
    ]);
  }

  Widget _metricTile(String label, double? v, {bool pct = false, bool negColor = false, bool int = false}) {
    final theme = Theme.of(context);
    String val = '—';
    Color? c;
    if (v != null) {
      val = pct ? '${(v * 100).toStringAsFixed(1)}%' : (int ? v.toStringAsFixed(0) : v.toStringAsFixed(2));
      if (negColor) c = const Color(0xFFEF4444);
    }
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 40) / 2,
      child: Card(child: ListTile(dense: true, title: Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c ?? theme.colorScheme.primary)), subtitle: Text(label))),
    );
  }

  Widget _chart() {
    final symbols = _run?.chartSymbols ?? const <String>[];
    final sym = _symbol;
    return ListView(padding: const EdgeInsets.all(8), children: [
      if (symbols.length > 1)
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: DropdownButton<String>(
            value: sym, isExpanded: true,
            items: [for (final s in symbols) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (s) {
              if (s == null) return;
              setState(() => _symbol = s);
              _ensureSymbol(s);
            },
          ),
        ),
      if (sym != null && _priceSeries[sym] != null)
        CandleChart(bars: _priceSeries[sym]!)
      else
        Padding(padding: const EdgeInsets.all(16), child: Text(AppLocalizations.of(context)!.noChartSymbol)),
      const Divider(),
      if (_run?.equityCurve != null && _run!.equityCurve!.isNotEmpty)
        EquityChart(equity: _run!.equityCurve!),
    ]);
  }

  Widget _trades() {
    final markers = _run?.tradeMarkers ?? const <TradeMarker>[];
    final log = _run?.tradeLog ?? const <Map<String, String>>[];
    if (markers.isEmpty && log.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noTrades));
    }
    // Prefer structured markers (chart payload); fall back to raw trade_log
    // CSV rows when the summary payload omits trade_markers.
    if (markers.isNotEmpty) {
      return ListView.builder(
        itemCount: markers.length,
        itemBuilder: (_, i) {
          final t = markers[i];
          return _tradeCard(t.time, t.side, t.price, t.qty?.toString(), t.reason);
        },
      );
    }
    return ListView.builder(
      itemCount: log.length,
      itemBuilder: (_, i) {
        final r = log[i];
        final price = double.tryParse(r['price'] ?? r['fill_price'] ?? r['avg_price'] ?? '') ?? 0.0;
        return _tradeCard(
          r['timestamp'] ?? r['time'] ?? r['date'] ?? '',
          r['side'] ?? r['type'] ?? r['action'] ?? '',
          price,
          r['quantity'] ?? r['qty'] ?? r['shares'],
          r['reason'] ?? r['note'],
        );
      },
    );
  }

  Widget _tradeCard(String time, String side, double price, String? qty, String? reason) {
    final buy = side.toUpperCase().startsWith('B');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (buy ? Colors.green : Colors.red).withValues(alpha: 0.15),
          child: Text(buy ? 'B' : 'S', style: TextStyle(color: buy ? Colors.green : Colors.red)),
        ),
        title: Text('$time  ·  ${price.toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        subtitle: Text([if (qty != null && qty.isNotEmpty) 'qty $qty', side, reason].whereType<String>().join(' · '),
            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _runCard() {
    final rc = _run?.runCard;
    if (rc == null) return Center(child: Text(AppLocalizations.of(context)!.noRunCard));
    final warnings = rc.warnings ?? const <String>[];
    final sources = rc.dataSources ?? const <String>[];
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (warnings.isNotEmpty) ...[
        Text(AppLocalizations.of(context)!.warnings, style: Theme.of(context).textTheme.titleSmall),
        for (final w in warnings) ListTile(dense: true, leading: const Icon(Icons.warning_amber, size: 18), title: Text(w, style: const TextStyle(fontSize: 13))),
        const Divider(),
      ],
      if (sources.isNotEmpty) ...[
        Text(AppLocalizations.of(context)!.dataSources, style: Theme.of(context).textTheme.titleSmall),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final s in sources) Chip(label: Text(s, style: const TextStyle(fontSize: 11)))]),
        const Divider(),
      ],
      Text(AppLocalizations.of(context)!.rawJson, style: Theme.of(context).textTheme.titleSmall),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
        child: SelectableText(_pretty(rc.raw), style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
      ),
    ]);
  }

  Widget _codeTab() {
    return FutureBuilder<Map<String, String>>(
      future: _codeFuture(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final files = snap.data ?? const {};
        final tabs = files.keys.toList();
        if (tabs.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.noSourceCode));
        final sel = tabs.contains(_codeFile) ? _codeFile : tabs.first;
        return Column(children: [
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final f in tabs)
              Padding(padding: const EdgeInsets.all(8), child: ChoiceChip(label: Text(f), selected: sel == f, onSelected: (_) => setState(() => _codeFile = f))),
          ])),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(8), child: SelectableText(files[sel] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)))),
        ]);
      },
    );
  }

  Future<Map<String, String>> _codeFuture() async {
    if (_code != null) return _code!;
    try {
      _code = await ref.read(apiProvider).getRunCode(widget.runId);
    } on ApiException {
      _code = {};
    }
    return _code!;
  }

  Widget _validation() {
    final v = _run?.validation;
    if (v == null) return Center(child: Text(AppLocalizations.of(context)!.noValidation));
    return ValidationPanel(data: v);
  }

  // --- CSV export --------------------------------------------------------

  void _exportTrades() {
    final markers = _run?.tradeMarkers ?? const <TradeMarker>[];
    final log = _run?.tradeLog ?? const <Map<String, String>>[];
    String csv;
    if (log.isNotEmpty) {
      final keys = log.first.keys.toList();
      csv = '${keys.join(",")}\n${log.map((r) => keys.map((k) => _csv(r[k] ?? "")).join(",")).join("\n")}';
    } else {
      csv = 'time,side,price,qty,reason\n${markers.map((t) => [_csv(t.time), t.side, t.price, t.qty ?? "", _csv(t.reason ?? "")].join(",")).join("\n")}';
    }
    shareFile(csv, 'trades_${_run!.runId}.csv');
  }

  void _exportMetrics() {
    final m = _run?.metrics ?? const <String, double>{};
    if (m.isEmpty) {
      _toast('No metrics');
      return;
    }
    final csv = 'metric,value\n${m.entries.map((e) => '${e.key},${e.value}').join("\n")}';
    shareFile(csv, 'metrics_${_run!.runId}.csv');
  }

  String _csv(String s) => '"${s.replaceAll('"', '""')}"';

  String _pretty(Map<String, dynamic> m) {
    // Lightweight indented JSON (avoid dart:convert JsonEncoder with non-finite).
    return const JsonPrettyEncoder().convert(m);
  }
}

/// Minimal indented JSON encoder (the codebase enforces non-finite→null for
/// strict JSON; this is a local helper for the run-card raw view).
class JsonPrettyEncoder {
  const JsonPrettyEncoder();
  String convert(Object? o, [String indent = '']) {
    if (o is Map) {
      if (o.isEmpty) return '{}';
      final entries = o.entries.map((e) => '$indent  "${e.key}": ${convert(e.value, '$indent  ')}').join(',\n');
      return '{\n$entries\n$indent}';
    }
    if (o is List) {
      if (o.isEmpty) return '[]';
      return '[\n${o.map((e) => '$indent  ${convert(e, '$indent  ')}').join(',\n')}\n$indent]';
    }
    if (o is String) return '"${o.replaceAll('"', '\\"')}"';
    return '$o';
  }
}
