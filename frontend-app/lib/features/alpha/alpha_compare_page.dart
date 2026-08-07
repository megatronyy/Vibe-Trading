import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/alpha.dart';
import '../../core/net/api.dart';
import '../../core/net/api_client.dart';
import '../../core/net/api_error.dart';
import '../../core/net/sse_client.dart';

/// Alpha compare runner: ids + universe + period + rank-by → POST /alpha/compare
/// → SSE (progress/result/done/error) → ranking cards.
class AlphaComparePage extends ConsumerStatefulWidget {
  const AlphaComparePage({super.key});

  @override
  ConsumerState<AlphaComparePage> createState() => _AlphaComparePageState();
}

class _AlphaComparePageState extends ConsumerState<AlphaComparePage> {
  final _idsCtrl = TextEditingController();
  final _universeCtrl = TextEditingController(text: 'csi300');
  final _periodCtrl = TextEditingController(text: '365');
  String _sort = 'ir';
  bool _running = false;
  int _done = 0;
  int _total = 0;
  AlphaCompareResult? _result;
  String? _error;
  SseClient? _sse;

  @override
  void dispose() {
    _sse?.dispose();
    _idsCtrl.dispose();
    _universeCtrl.dispose();
    _periodCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final ids = _idsCtrl.text.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).toList();
    if (ids.isEmpty) return;
    setState(() {
      _running = true;
      _done = 0;
      _total = ids.length;
      _result = null;
      _error = null;
    });
    final api = ref.read(apiProvider);
    try {
      final jobId = await api.createAlphaCompare({
        'alpha_ids': ids,
        'universe': _universeCtrl.text,
        'period': int.tryParse(_periodCtrl.text) ?? 365,
        'sort': _sort,
      });
      _sse = SseClient(dio: ref.read(dioProvider), url: api.alphaCompareStreamUrl(jobId))
        ..connect().listen(_onEvent, onError: (e) => setState(() => _error = '$e'));
    } on ApiException catch (e) {
      setState(() {
        _running = false;
        _error = e.message;
      });
    }
  }

  void _onEvent(SseEvent ev) {
    final d = ev.json ?? const {};
    switch (ev.type) {
      case 'progress':
        setState(() => _done = (d['n_done'] as num?)?.toInt() ?? _done);
        break;
      case 'result':
        setState(() => _result = AlphaCompareResult.fromJson(d));
        break;
      case 'done':
        setState(() => _running = false);
        _sse?.dispose();
        break;
      case 'error':
        setState(() {
          _running = false;
          _error = d['message'] as String? ?? 'error';
        });
        _sse?.dispose();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(AppLocalizations.of(context)!.compareTitle),
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        TextField(
            controller: _idsCtrl,
            decoration: InputDecoration(labelText: AppLocalizations.of(context)!.idsHint, isDense: true),
            maxLines: 2),
        Row(children: [
          Expanded(child: TextField(controller: _universeCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.benchUniverse, isDense: true))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _periodCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.benchPeriod, isDense: true), keyboardType: TextInputType.number)),
        ]),
        DropdownButton<String>(
          value: _sort,
          isExpanded: true,
          items: [
            DropdownMenuItem(value: 'ir', child: Text(AppLocalizations.of(context)!.rankByIr)),
            DropdownMenuItem(value: 'ic_mean', child: Text(AppLocalizations.of(context)!.rankByIcMean)),
            DropdownMenuItem(value: 'ic_positive_ratio', child: Text(AppLocalizations.of(context)!.rankByIcPos)),
          ],
          onChanged: (v) => setState(() => _sort = v ?? 'ir'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(onPressed: _running ? null : _run, icon: const Icon(Icons.play_arrow), label: Text(AppLocalizations.of(context)!.compareTitle)),
        if (_running || _total > 0) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _total > 0 ? _done / _total : null),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_result != null) ...[
          if (_result!.winner != null)
            Card(
                color: Colors.green.withValues(alpha: 0.12),
                child: ListTile(title: Text(AppLocalizations.of(context)!.winner), subtitle: Text(_result!.winner!.id ?? '', style: const TextStyle(fontFamily: 'monospace')))),
          const SizedBox(height: 8),
          for (final r in _result!.ranking) _rankRow(r),
        ],
      ]),
    );
  }

  Widget _rankRow(AlphaCompareRow r) => Card(child: ListTile(
        leading: CircleAvatar(child: Text('${r.rank ?? "-"}')),
        title: Text(r.id ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        subtitle: Text(_rankSub(r), style: const TextStyle(fontSize: 12)),
        trailing: r.deltaVsBest != null
            ? Text(_delta(r.deltaVsBest!, r.rank ?? 1),
                style: TextStyle(fontSize: 12, color: (r.rank ?? 1) == 1 ? Colors.green : Colors.red))
            : null,
        onTap: r.id != null ? () => context.push('/alpha-zoo/${r.id}') : null,
      ));

  String _rankSub(AlphaCompareRow r) {
    final parts = <String>[
      'IR ${r.ir?.toStringAsFixed(2) ?? "-"}',
      'IC ${r.icMean?.toStringAsFixed(3) ?? "-"}',
      'pos ${((r.icPositiveRatio ?? 0) * 100).toStringAsFixed(0)}%',
    ];
    return parts.join('  ·  ');
  }

  String _delta(double v, int rank) {
    final sign = v >= 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(2)}';
  }
}
