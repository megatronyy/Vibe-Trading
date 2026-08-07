/// Port of the run/backtest types in `frontend/src/lib/api.ts` (PriceBar,
/// TradeMarker, …). Parsed defensively — backend fields may be string-or-number.
library;


class PriceBar {
  const PriceBar({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final String time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  factory PriceBar.fromJson(Map<String, dynamic> j) => PriceBar(
        time: (j['time'] ?? j['timestamp'] ?? '') as String,
        open: _n(j['open']),
        high: _n(j['high']),
        low: _n(j['low']),
        close: _n(j['close']),
        volume: _n(j['volume']),
      );
}

class TradeMarker {
  const TradeMarker({
    required this.time,
    required this.side,
    required this.price,
    this.qty,
    this.reason,
  });

  final String time;
  final String side; // BUY | SELL
  final double price;
  final double? qty;
  final String? reason;

  factory TradeMarker.fromJson(Map<String, dynamic> j) => TradeMarker(
        time: (j['time'] ?? j['timestamp'] ?? '') as String,
        side: (j['side'] as String?) ?? 'BUY',
        price: _n(j['price']),
        qty: j['qty'] != null ? _n(j['qty']) : null,
        reason: j['reason'] as String? ?? j['text'] as String?,
      );
}

class EquityPoint {
  const EquityPoint({required this.time, required this.equity, required this.drawdown});
  final String time;
  final double equity;
  final double drawdown;

  factory EquityPoint.fromJson(Map<String, dynamic> j) => EquityPoint(
        time: (j['time'] ?? '') as String,
        equity: _n(j['equity']),
        drawdown: _n(j['drawdown']),
      );
}

class IndicatorPoint {
  const IndicatorPoint({required this.time, required this.value});
  final String time;
  final double value;

  factory IndicatorPoint.fromJson(Map<String, dynamic> j) => IndicatorPoint(
        time: (j['time'] ?? '') as String,
        value: _n(j['value']),
      );
}

/// Monte Carlo / Bootstrap / Walk-Forward validation payload.
class ValidationData {
  const ValidationData({this.monteCarlo, this.bootstrap, this.walkForward});

  final MonteCarlo? monteCarlo;
  final Bootstrap? bootstrap;
  final WalkForward? walkForward;

  factory ValidationData.fromJson(Map<String, dynamic> j) => ValidationData(
        monteCarlo: j['monte_carlo'] is Map
            ? MonteCarlo.fromJson(j['monte_carlo'] as Map<String, dynamic>)
            : null,
        bootstrap: j['bootstrap'] is Map
            ? Bootstrap.fromJson(j['bootstrap'] as Map<String, dynamic>)
            : null,
        walkForward: j['walk_forward'] is Map
            ? WalkForward.fromJson(j['walk_forward'] as Map<String, dynamic>)
            : null,
      );
}

class MonteCarlo {
  const MonteCarlo({
    required this.actualSharpe,
    required this.actualMaxDd,
    required this.pValueSharpe,
    required this.pValueMaxDd,
    required this.simulatedSharpeMean,
    required this.nSimulations,
    this.error,
  });
  final double actualSharpe;
  final double actualMaxDd;
  final double pValueSharpe;
  final double pValueMaxDd;
  final double simulatedSharpeMean;
  final int nSimulations;
  final String? error;

  factory MonteCarlo.fromJson(Map<String, dynamic> j) => MonteCarlo(
        actualSharpe: _n(j['actual_sharpe']),
        actualMaxDd: _n(j['actual_max_dd']),
        pValueSharpe: _n(j['p_value_sharpe']),
        pValueMaxDd: _n(j['p_value_max_dd']),
        simulatedSharpeMean: _n(j['simulated_sharpe_mean']),
        nSimulations: (j['n_simulations'] as num?)?.toInt() ?? 0,
        error: j['error'] as String?,
      );
}

class Bootstrap {
  const Bootstrap({
    required this.observedSharpe,
    required this.ciLower,
    required this.ciUpper,
    required this.probPositive,
    this.error,
  });
  final double observedSharpe;
  final double ciLower;
  final double ciUpper;
  final double probPositive;
  final String? error;

  factory Bootstrap.fromJson(Map<String, dynamic> j) => Bootstrap(
        observedSharpe: _n(j['observed_sharpe']),
        ciLower: _n(j['ci_lower']),
        ciUpper: _n(j['ci_upper']),
        probPositive: _n(j['prob_positive']),
        error: j['error'] as String?,
      );
}

class WalkForwardWindow {
  const WalkForwardWindow({
    required this.window,
    required this.start,
    required this.end,
    required this.ret,
    required this.sharpe,
    required this.maxDd,
    required this.trades,
    required this.winRate,
  });
  final int window;
  final String start;
  final String end;
  final double ret;
  final double sharpe;
  final double maxDd;
  final int trades;
  final double winRate;

  factory WalkForwardWindow.fromJson(Map<String, dynamic> j) => WalkForwardWindow(
        window: (j['window'] as num?)?.toInt() ?? 0,
        start: (j['start'] ?? '') as String,
        end: (j['end'] ?? '') as String,
        ret: _n(j['return']),
        sharpe: _n(j['sharpe']),
        maxDd: _n(j['max_dd']),
        trades: (j['trades'] as num?)?.toInt() ?? 0,
        winRate: _n(j['win_rate']),
      );
}

class WalkForward {
  const WalkForward({
    required this.nWindows,
    required this.windows,
    required this.profitableWindows,
    required this.consistencyRate,
    required this.returnMean,
    required this.sharpeMean,
    this.error,
  });
  final int nWindows;
  final List<WalkForwardWindow> windows;
  final int profitableWindows;
  final double consistencyRate;
  final double returnMean;
  final double sharpeMean;
  final String? error;

  factory WalkForward.fromJson(Map<String, dynamic> j) => WalkForward(
        nWindows: (j['n_windows'] as num?)?.toInt() ?? 0,
        windows: ((j['windows'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(WalkForwardWindow.fromJson)
            .toList(),
        profitableWindows: (j['profitable_windows'] as num?)?.toInt() ?? 0,
        consistencyRate: _n(j['consistency_rate']),
        returnMean: _n(j['return_mean']),
        sharpeMean: _n(j['sharpe_mean']),
        error: j['error'] as String?,
      );
}

class RunCard {
  const RunCard({this.warnings, this.dataSources, this.raw = const {}});
  final List<String>? warnings;
  final List<String>? dataSources;
  final Map<String, dynamic> raw;

  factory RunCard.fromJson(Map<String, dynamic> j) => RunCard(
        warnings: (j['warnings'] as List?)?.cast<String>(),
        dataSources: (j['data_sources'] as List?)?.cast<String>(),
        raw: j,
      );
}

/// Full run detail (`GET /runs/{id}`).
class RunData {
  const RunData({
    required this.runId,
    required this.status,
    this.prompt,
    this.elapsedSeconds,
    this.metrics,
    this.runCard,
    this.validation,
    this.chartSymbols,
    this.priceSeries,
    this.indicatorSeries,
    this.tradeMarkers,
    this.equityCurve,
    this.tradeLog,
  });

  final String runId;
  final String status;
  final String? prompt;
  final double? elapsedSeconds;
  final Map<String, double>? metrics;
  final RunCard? runCard;
  final ValidationData? validation;
  final List<String>? chartSymbols;
  final Map<String, List<PriceBar>>? priceSeries;
  final Map<String, Map<String, List<IndicatorPoint>>>? indicatorSeries;
  final List<TradeMarker>? tradeMarkers;
  final List<EquityPoint>? equityCurve;
  final List<Map<String, String>>? tradeLog;

  factory RunData.fromJson(Map<String, dynamic> j) {
    // Defensive parsing: the RunResponse carries many optional, loosely-typed
    // fields (CSV-derived lists, free-form run_card, …). Avoid hard casts that
    // could throw and leave the page stuck — coerce each field safely.
    Map<String, List<PriceBar>>? parsePrice(dynamic v) {
      if (v is! Map) return null;
      final out = <String, List<PriceBar>>{};
      for (final e in v.entries) {
        out[e.key.toString()] = _asMapList(e.value).map(PriceBar.fromJson).toList();
      }
      return out;
    }

    return RunData(
      runId: (j['run_id'] ?? j['id'])?.toString() ?? '',
      status: j['status']?.toString() ?? 'unknown',
      prompt: j['prompt']?.toString(),
      elapsedSeconds: j['elapsed_seconds'] == null ? null : _n(j['elapsed_seconds']),
      metrics: j['metrics'] is Map
          ? Map<String, double>.from(
              (j['metrics'] as Map).map((k, v) => MapEntry(k.toString(), _n(v))))
          : null,
      runCard: j['run_card'] is Map
          ? RunCard.fromJson(Map<String, dynamic>.from(j['run_card'] as Map))
          : null,
      validation: j['validation'] is Map
          ? ValidationData.fromJson(Map<String, dynamic>.from(j['validation'] as Map))
          : null,
      chartSymbols: _asStringList(j['chart_symbols']),
      priceSeries: parsePrice(j['price_series']),
      indicatorSeries: _parseIndicatorSeries(j['indicator_series']),
      tradeMarkers: _asMapList(j['trade_markers']).map(TradeMarker.fromJson).toList(),
      equityCurve: _asMapList(j['equity_curve']).map(EquityPoint.fromJson).toList(),
      tradeLog: _asMapList(j['trade_log'])
          .map((m) => m.map((k, v) => MapEntry(k, v?.toString() ?? '')))
          .toList(),
    );
  }
}

class RunListItem {
  const RunListItem({required this.id, this.prompt, this.status, this.startedAt, this.metrics});
  final String id;
  final String? prompt;
  final String? status;
  final DateTime? startedAt;
  final Map<String, double>? metrics;

  factory RunListItem.fromJson(Map<String, dynamic> j) {
    // Backend `RunInfo` sends total_return/sharpe at the top level (not under
    // a `metrics` map) and uses `created_at` (not `started_at`).
    final metrics = <String, double>{};
    final tr = j['total_return'];
    final sh = j['sharpe'];
    if (tr != null) metrics['total_return'] = _n(tr);
    if (sh != null) metrics['sharpe'] = _n(sh);
    final created = j['created_at'];
    return RunListItem(
      id: (j['run_id'] ?? j['id']) as String,
      prompt: j['prompt'] as String?,
      status: j['status'] as String?,
      startedAt: created is String
          ? DateTime.tryParse(created.replaceFirst(' ', 'T'))
          : null,
      metrics: metrics.isEmpty ? null : metrics,
    );
  }
}

class PineScriptResult {
  const PineScriptResult({required this.exists, this.content});
  final bool exists;
  final String? content;
  factory PineScriptResult.fromJson(Map<String, dynamic> j) => PineScriptResult(
        exists: j['exists'] as bool? ?? false,
        content: j['content'] as String?,
      );
}

Map<String, Map<String, List<IndicatorPoint>>>? _parseIndicatorSeries(dynamic v) {
  if (v is! Map) return null;
  final out = <String, Map<String, List<IndicatorPoint>>>{};
  for (final symEntry in v.entries) {
    if (symEntry.value is! Map) continue;
    final inner = <String, List<IndicatorPoint>>{};
    for (final nameEntry in (symEntry.value as Map).entries) {
      inner[nameEntry.key.toString()] =
          _asMapList(nameEntry.value).map(IndicatorPoint.fromJson).toList();
    }
    out[symEntry.key.toString()] = inner;
  }
  return out;
}

double _n(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// Coerce a JSON list-of-objects into `List<Map<String,dynamic>>`, skipping any
/// non-map elements instead of throwing.
List<Map<String, dynamic>> _asMapList(dynamic v) {
  if (v is! List) return const [];
  final out = <Map<String, dynamic>>[];
  for (final e in v) {
    if (e is Map) out.add(Map<String, dynamic>.from(e));
  }
  return out;
}

List<String> _asStringList(dynamic v) {
  if (v is! List) return const [];
  return v.map((e) => e?.toString() ?? '').toList();
}
