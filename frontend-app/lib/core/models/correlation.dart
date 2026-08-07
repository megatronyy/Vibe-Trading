library;

/// Correlation matrix + regime responses. Matrix is a square list-of-lists of
/// doubles in [-1, 1]; labels align rows/columns. Regime episodes mark fused
/// market-regime intervals plotted on the timeline.
class CorrelationResponse {
  const CorrelationResponse({this.labels = const [], this.matrix = const [], this.method, this.days});
  final List<String> labels;
  final List<List<double>> matrix;
  final String? method;
  final int? days;

  factory CorrelationResponse.fromJson(Map<String, dynamic> j) {
    final labels = (j['labels'] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final matrix = (j['matrix'] as List?)
            ?.map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
            .toList() ??
        const <List<double>>[];
    return CorrelationResponse(
      labels: labels,
      matrix: matrix,
      method: j['method'] as String?,
      days: (j['days'] as num?)?.toInt(),
    );
  }
}

class RegimeEpisode {
  const RegimeEpisode({this.start, this.end, this.regime, this.score});
  final String? start;
  final String? end;
  final String? regime;
  final double? score;

  factory RegimeEpisode.fromJson(Map<String, dynamic> j) => RegimeEpisode(
        start: j['start'] as String?,
        end: j['end'] as String?,
        regime: j['regime'] as String?,
        score: (j['score'] as num?)?.toDouble(),
      );
}

class CorrelationRegimeResponse {
  const CorrelationRegimeResponse({this.episodes = const [], this.labels = const []});
  final List<RegimeEpisode> episodes;
  final List<String> labels;

  factory CorrelationRegimeResponse.fromJson(Map<String, dynamic> j) =>
      CorrelationRegimeResponse(
        episodes: ((j['episodes'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(RegimeEpisode.fromJson)
            .toList(),
        labels: (j['labels'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}
