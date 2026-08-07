library;

/// Alpha Zoo models — port of `frontend/src/lib/api.ts` Alpha* interfaces,
/// parsed defensively. Bench/compare result shapes match the verified backend
/// projection (`src/api/alpha_routes.py` `_result_for_wire`).

class AlphaSummary {
  const AlphaSummary({
    required this.id,
    this.zoo,
    this.theme = const [],
    this.universe = const [],
    this.decayHorizon,
    this.nickname,
  });
  final String id;
  final String? zoo;
  /// Backend sends `theme` / `universe` as arrays (an alpha may belong to
  /// multiple). Kept as lists; the UI joins for display.
  final List<String> theme;
  final List<String> universe;
  final int? decayHorizon;
  final String? nickname;

  factory AlphaSummary.fromJson(Map<String, dynamic> j) => AlphaSummary(
        id: _string(j['id'] ?? j['alpha_id']) ?? '',
        zoo: _string(j['zoo']),
        theme: _list(j['theme']),
        universe: _list(j['universe']),
        decayHorizon: _int(j['decay_horizon']),
        nickname: _string(j['nickname']),
      );
}

class AlphaDetail {
  const AlphaDetail({
    required this.id,
    this.zoo,
    this.theme = const [],
    this.universe = const [],
    this.frequency,
    this.decayHorizon,
    this.minWarmupBars,
    this.modulePath,
    this.notes,
    this.formulaLatex,
    this.source,
  });
  final String id;
  final String? zoo;
  final List<String> theme;
  final List<String> universe;
  final String? frequency;
  final int? decayHorizon;
  final int? minWarmupBars;
  final String? modulePath;
  final String? notes;
  final String? formulaLatex;
  final String? source;

  /// Backend `/alpha/{id}` returns `{status, alpha:{id, zoo, module_path,
  /// meta:{theme[], universe[], formula_latex, frequency, decay_horizon,
  /// min_warmup_bars, notes?, …}}, source_code}`. Parse defensively.
  factory AlphaDetail.fromJson(Map<String, dynamic> j) {
    final alpha = j['alpha'] is Map ? Map<String, dynamic>.from(j['alpha']) : j;
    // `meta` is a free-form Record<string,*>; values may be String, List,
    // num, bool, … so coerce defensively instead of hard-casting.
    final meta = alpha['meta'] is Map ? Map<String, dynamic>.from(alpha['meta']) : const <String, dynamic>{};
    return AlphaDetail(
      id: (alpha['id'] ?? j['id']) as String,
      zoo: _string(alpha['zoo']),
      modulePath: _string(alpha['module_path']),
      formulaLatex: _string(meta['formula_latex']) ?? _string(alpha['formula_latex']),
      theme: _list(meta['theme']),
      universe: _list(meta['universe']),
      frequency: _string(meta['frequency']),
      decayHorizon: _int(meta['decay_horizon']),
      minWarmupBars: _int(meta['min_warmup_bars']),
      notes: _string(meta['notes']),
      source: _string(j['source_code']),
    );
  }
}

// ---- defensive coercion for the free-form alpha `meta` record -------------

String? _string(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is List) return v.map((e) => e.toString()).join(', ');
  if (v is bool || v is num) return v.toString();
  return v.toString();
}

List<String> _list(dynamic v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  if (v == null) return const [];
  return [v.toString()];
}

int? _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

class AlphaBenchRow {
  const AlphaBenchRow({this.id, this.icMean, this.ir, this.theme, this.formulaLatex});
  final String? id;
  final double? icMean;
  final double? ir;
  final String? theme;
  final String? formulaLatex;

  factory AlphaBenchRow.fromJson(Map<String, dynamic> j) => AlphaBenchRow(
        id: j['id'] as String?,
        icMean: (j['ic_mean'] as num?)?.toDouble(),
        ir: (j['ir'] as num?)?.toDouble(),
        theme: j['theme'] as String?,
        formulaLatex: j['formula_latex'] as String?,
      );
}

class AlphaBenchResult {
  const AlphaBenchResult({
    this.alive = 0,
    this.reversed = 0,
    this.dead = 0,
    this.skipped = 0,
    this.nAlphasTested = 0,
    this.top5ByIr = const [],
    this.deadExamples = const [],
    this.byTheme = const {},
  });
  final int alive;
  final int reversed;
  final int dead;
  final int skipped;
  final int nAlphasTested;
  final List<AlphaBenchRow> top5ByIr;
  final List<AlphaBenchRow> deadExamples;
  final Map<String, Map<String, int>> byTheme;

  factory AlphaBenchResult.fromJson(Map<String, dynamic> j) {
    Map<String, Map<String, int>> parseByTheme(dynamic bt) {
      if (bt is! Map) return const {};
      return bt.map((k, v) => MapEntry(
          k.toString(),
          (v is Map)
              ? v.map((kk, vv) => MapEntry(kk.toString(), (vv as num).toInt()))
              : <String, int>{}));
    }
    return AlphaBenchResult(
      alive: (j['alive'] as num?)?.toInt() ?? 0,
      reversed: (j['reversed'] as num?)?.toInt() ?? 0,
      dead: (j['dead'] as num?)?.toInt() ?? 0,
      skipped: (j['skipped'] as num?)?.toInt() ?? (j['n_skipped'] as num?)?.toInt() ?? 0,
      nAlphasTested: (j['n_alphas_tested'] as num?)?.toInt() ?? 0,
      top5ByIr: ((j['top5_by_ir'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AlphaBenchRow.fromJson)
          .toList(),
      deadExamples: ((j['dead_examples'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(AlphaBenchRow.fromJson)
          .toList(),
      byTheme: parseByTheme(j['by_theme']),
    );
  }
}

class AlphaCompareRow {
  const AlphaCompareRow({
    this.rank,
    this.id,
    this.zoo,
    this.icMean,
    this.icStd,
    this.ir,
    this.icPositiveRatio,
    this.icCount,
    this.deltaVsBest,
  });
  final int? rank;
  final String? id;
  final String? zoo;
  final double? icMean;
  final double? icStd;
  final double? ir;
  final double? icPositiveRatio;
  final int? icCount;
  final double? deltaVsBest;

  factory AlphaCompareRow.fromJson(Map<String, dynamic> j) => AlphaCompareRow(
        rank: (j['rank'] as num?)?.toInt(),
        id: j['id'] as String?,
        zoo: j['zoo'] as String?,
        icMean: (j['ic_mean'] as num?)?.toDouble(),
        icStd: (j['ic_std'] as num?)?.toDouble(),
        ir: (j['ir'] as num?)?.toDouble(),
        icPositiveRatio: (j['ic_positive_ratio'] as num?)?.toDouble(),
        icCount: (j['ic_count'] as num?)?.toInt(),
        deltaVsBest: (j['delta_ir_vs_best'] as num?)?.toDouble() ??
            (j['delta_ic_mean_vs_best'] as num?)?.toDouble(),
      );
}

class AlphaCompareResult {
  const AlphaCompareResult({
    this.universe,
    this.period,
    this.sort,
    this.nCompared = 0,
    this.nSkipped = 0,
    this.winner,
    this.ranking = const [],
    this.skipped = const [],
  });
  final String? universe;
  final String? period;
  final String? sort;
  final int nCompared;
  final int nSkipped;
  final AlphaCompareRow? winner;
  final List<AlphaCompareRow> ranking;
  final List<Map<String, dynamic>> skipped;

  factory AlphaCompareResult.fromJson(Map<String, dynamic> j) => AlphaCompareResult(
        universe: j['universe'] as String?,
        period: j['period']?.toString(),
        sort: j['sort'] as String?,
        nCompared: (j['n_compared'] as num?)?.toInt() ?? 0,
        nSkipped: (j['n_skipped'] as num?)?.toInt() ?? 0,
        winner: j['winner'] is Map
            ? AlphaCompareRow.fromJson(j['winner'] as Map<String, dynamic>)
            : null,
        ranking: ((j['ranking'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(AlphaCompareRow.fromJson)
            .toList(),
        skipped: ((j['skipped'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .toList(),
      );
}
