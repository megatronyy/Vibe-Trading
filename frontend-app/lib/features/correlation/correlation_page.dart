import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../core/models/correlation.dart';
import '../../core/net/api.dart';
import '../../core/net/api_error.dart';

/// Correlation matrix (self-drawn heatmap CustomPainter) + optional regime
/// timeline (CustomPainter) — fl_chart/syncfusion have no heatmap, so per
/// plan §6.3 these are hand-painted. A WebView+ECharts fallback is noted if
/// this proves insufficient (not wired by default).
class CorrelationPage extends ConsumerStatefulWidget {
  const CorrelationPage({super.key});

  @override
  ConsumerState<CorrelationPage> createState() => _CorrelationPageState();
}

class _CorrelationPageState extends ConsumerState<CorrelationPage> {
  final _codesCtrl = TextEditingController(text: '000001.SZ,600519.SH,000858.SZ,601318.SH');
  int _days = 90;
  String _method = 'pearson';
  bool _regime = false;
  CorrelationResponse? _corr;
  CorrelationRegimeResponse? _regimeResp;
  bool _loading = false;
  String? _error;

  static const _windows = [30, 60, 90, 180, 365];

  Future<void> _compute() async {
    final codes = _codesCtrl.text.trim();
    if (codes.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _corr = null;
      _regimeResp = null;
    });
    final api = ref.read(apiProvider);
    try {
      final results = await Future.wait([
        api.getCorrelation(codes, _days, _method),
        if (_regime) api.getCorrelationRegime(codes, _days),
      ]);
      setState(() {
        _corr = results[0] as CorrelationResponse;
        if (_regime && results.length > 1) _regimeResp = results[1] as CorrelationRegimeResponse;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  void dispose() {
    _codesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.correlationTitle)),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        TextField(controller: _codesCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.codesHint, isDense: true)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final w in _windows)
            ChoiceChip(label: Text('${w}d'), selected: _days == w, onSelected: (_) => setState(() => _days = w)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ChoiceChip(label: const Text('pearson'), selected: _method == 'pearson', onSelected: (_) => setState(() => _method = 'pearson')),
          ChoiceChip(label: const Text('spearman'), selected: _method == 'spearman', onSelected: (_) => setState(() => _method = 'spearman')),
          FilterChip(label: const Text('regime'), selected: _regime, onSelected: (_) => setState(() => _regime = !_regime)),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _loading ? null : _compute, icon: const Icon(Icons.calculate), label: Text(AppLocalizations.of(context)!.compute)),
        if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_corr != null && _corr!.matrix.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.matrix, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _heatScroll(),
        ],
        if (_regimeResp != null && _regimeResp!.episodes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.regimeTimeline, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(height: 120, child: RegimePainter(episodes: _regimeResp!.episodes)),
        ],
      ]),
    );
  }

  Widget _heatScroll() {
    final labels = _corr!.labels;
    final n = labels.length;
    // Cell size scales with count; allow horizontal scroll on small screens.
    final cell = n <= 6 ? 56.0 : n <= 10 ? 44.0 : 34.0;
    final labelW = n <= 6 ? 90.0 : 70.0;
    final side = cell * n + labelW;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: side,
        height: side,
        child: CustomPaint(painter: _HeatmapPainter(_corr!, cell, labelW), size: Size(side, side)),
      ),
    );
  }
}

/// Divergent heatmap: -1 → red, 0 → white, +1 → blue. Labels on the top + left;
/// cell value printed when the grid is small enough.
class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter(this.data, this.cell, this.labelW);
  final CorrelationResponse data;
  final double cell;
  final double labelW;

  @override
  void paint(Canvas canvas, Size size) {
    final labels = data.labels;
    final n = labels.length;
    if (n == 0) return;
    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = Colors.black26;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final v = (r < data.matrix.length && c < data.matrix[r].length)
            ? data.matrix[r][c]
            : 0.0;
        fill.color = _divergent(v);
        final rect = Rect.fromLTWH(labelW + c * cell, r * cell, cell, cell);
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        if (n <= 8) {
          _text(canvas, v.toStringAsFixed(2), rect.center, 10);
        }
      }
    }
    // Labels: left column + top row.
    for (var i = 0; i < n; i++) {
      _text(canvas, labels[i], Offset(labelW - 6, i * cell + cell / 2), 9, alignRight: true);
      _text(canvas, labels[i], Offset(labelW + i * cell + cell / 2, -1), 9, alignTop: true);
    }
  }

  Color _divergent(double v) {
    final t = v.clamp(-1.0, 1.0).toDouble();
    if (t >= 0) {
      return Color.lerp(Colors.white, const Color(0xFF2166AC), t)!; // blue
    }
    return Color.lerp(Colors.white, const Color(0xFFB2182B), -t)!; // red
  }

  void _text(Canvas canvas, String s, Offset center, double fontSize,
      {bool alignRight = false, bool alignTop = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fontSize, color: Colors.black87)),
      textDirection: TextDirection.ltr,
      textAlign: alignRight ? TextAlign.right : TextAlign.center,
    )..layout();
    final dx = alignRight ? center.dx - tp.width : center.dx - tp.width / 2;
    final dy = alignTop ? center.dy : center.dy - tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.data != data;
}

/// Regime timeline: fused episodes as colored horizontal bands over time.
class RegimePainter extends StatelessWidget {
  const RegimePainter({super.key, required this.episodes});
  final List<RegimeEpisode> episodes;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _RegimePainter(episodes), child: const SizedBox.expand());
  }
}

class _RegimePainter extends CustomPainter {
  _RegimePainter(this.episodes);
  final List<RegimeEpisode> episodes;

  @override
  void paint(Canvas canvas, Size size) {
    if (episodes.isEmpty) return;
    final times = episodes
        .map((e) => [e.start, e.end])
        .expand((p) => p)
        .whereType<String>()
        .map(DateTime.tryParse)
        .whereType<DateTime>()
        .toList();
    if (times.isEmpty) return;
    final minT = times.fold<DateTime>(times.first, (a, b) => a.isBefore(b) ? a : b).millisecondsSinceEpoch.toDouble();
    final maxT = times.fold<DateTime>(times.first, (a, b) => a.isAfter(b) ? a : b).millisecondsSinceEpoch.toDouble();
    final span = maxT - minT;
    if (span <= 0) return;
    double xOf(String? s) {
      final t = DateTime.tryParse(s ?? '');
      if (t == null) return 0;
      return (t.millisecondsSinceEpoch - minT) / span * size.width;
    }

    final grid = Paint()..color = Colors.black12..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), grid);

    for (final e in episodes) {
      final x0 = xOf(e.start);
      final x1 = xOf(e.end);
      final rect = Rect.fromLTWH(x0, 4, (x1 - x0).clamp(2.0, size.width).toDouble(), size.height - 8);
      canvas.drawRect(rect, Paint()..color = _regimeColor(e.regime)..style = PaintingStyle.fill);
    }
  }

  Color _regimeColor(String? regime) {
    switch (regime?.toLowerCase()) {
      case 'bull':
      case 'risk_on':
        return Colors.green.withValues(alpha: 0.5);
      case 'bear':
      case 'risk_off':
        return Colors.red.withValues(alpha: 0.5);
      case 'range':
      case 'neutral':
        return Colors.amber.withValues(alpha: 0.5);
      default:
        return Colors.blueGrey.withValues(alpha: 0.4);
    }
  }

  @override
  bool shouldRepaint(_RegimePainter old) => old.episodes != episodes;
}
