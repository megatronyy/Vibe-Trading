import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/alpha.dart';
import '../../core/net/api.dart';
import '../../core/net/api_client.dart';
import '../../core/net/api_error.dart';
import '../../core/net/sse_client.dart';

/// Alpha benchmark runner: form → POST /alpha/bench → SSE stream
/// (progress/result/done/error) → stat tiles + top-5-by-IR cards.
class AlphaBenchPage extends ConsumerStatefulWidget {
  const AlphaBenchPage({super.key});

  @override
  ConsumerState<AlphaBenchPage> createState() => _AlphaBenchPageState();
}

class _AlphaBenchPageState extends ConsumerState<AlphaBenchPage> {
  final _zooCtrl = TextEditingController(text: 'qlib158');
  final _universeCtrl = TextEditingController(text: 'csi300');
  final _periodCtrl = TextEditingController(text: '365');
  final _topCtrl = TextEditingController(text: '50');
  bool _running = false;
  int _done = 0;
  int _total = 0;
  String? _current;
  AlphaBenchResult? _result;
  String? _error;
  SseClient? _sse;

  @override
  void dispose() {
    _sse?.dispose();
    _zooCtrl.dispose();
    _universeCtrl.dispose();
    _periodCtrl.dispose();
    _topCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _done = 0; _total = 0; _current = null;
      _result = null; _error = null;
    });
    final api = ref.read(apiProvider);
    try {
      final jobId = await api.createAlphaBench({
        'zoo': _zooCtrl.text,
        'universe': _universeCtrl.text,
        'period': int.tryParse(_periodCtrl.text) ?? 365,
        'top': int.tryParse(_topCtrl.text) ?? 50,
      });
      _sse = SseClient(dio: ref.read(dioProvider), url: api.alphaBenchStreamUrl(jobId))
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
        setState(() {
          _done = (d['n_done'] as num?)?.toInt() ?? _done;
          _total = (d['n_total'] as num?)?.toInt() ?? _total;
          _current = d['current_alpha_id'] as String?;
        });
        break;
      case 'result':
        setState(() => _result = AlphaBenchResult.fromJson(d));
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
        title: const Text('Benchmark'),
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        _form(),
        if (_running || _total > 0) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(value: _total > 0 ? _done / _total : null),
          const SizedBox(height: 4),
          Text('$_done / $_total${_current != null ? "  ·  $_current" : ""}', style: const TextStyle(fontSize: 12)),
        ],
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_result != null) ...[
          const SizedBox(height: 16),
          _stats(_result!),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.topByIr, style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final r in _result!.top5ByIr) _benchRow(r),
        ],
      ]),
    );
  }

  Widget _form() => Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: _zooCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.benchZoo, isDense: true))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _universeCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.benchUniverse, isDense: true))),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: _periodCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.benchPeriod, isDense: true), keyboardType: TextInputType.number)),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _topCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.benchTop, isDense: true), keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _running ? null : _run,
          icon: const Icon(Icons.play_arrow),
          label: Text(AppLocalizations.of(context)!.runBenchmark),
        ),
      ]);

  Widget _stats(AlphaBenchResult r) => Wrap(spacing: 8, runSpacing: 8, children: [
        _tile(AppLocalizations.of(context)!.alive, r.alive, Colors.green),
        _tile(AppLocalizations.of(context)!.reversed, r.reversed, Colors.orange),
        _tile(AppLocalizations.of(context)!.dead, r.dead, Colors.red),
        _tile(AppLocalizations.of(context)!.skipped, r.skipped, Colors.grey),
      ]);

  Widget _tile(String label, int v, Color c) => SizedBox(
        width: (MediaQuery.sizeOf(context).width - 40) / 4,
        child: Card(child: ListTile(dense: true, title: Text('$v', style: TextStyle(fontSize: 20, color: c, fontWeight: FontWeight.bold)), subtitle: Text(label, style: const TextStyle(fontSize: 11)))),
      );

  Widget _benchRow(AlphaBenchRow r) => Card(child: ListTile(
        dense: true,
        title: Text(r.id ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        subtitle: Text(_benchSub(r), style: const TextStyle(fontSize: 12)),
        trailing: r.id != null
            ? TextButton(child: Text(AppLocalizations.of(context)!.detail), onPressed: () => context.push('/alpha-zoo/${r.id}'))
            : null,
      ));

  String _benchSub(AlphaBenchRow r) {
    final parts = <String>[
      'IR ${r.ir?.toStringAsFixed(2) ?? "-"}',
      'IC ${r.icMean?.toStringAsFixed(3) ?? "-"}',
      if (r.theme != null) r.theme!,
    ];
    return parts.join('  ·  ');
  }
}
