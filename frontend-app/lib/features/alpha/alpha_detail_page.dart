import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/alpha.dart';
import '../../core/net/api.dart';
import '../../core/net/api_error.dart';

/// Alpha detail: LaTeX formula (flutter_math_fork, plain-text fallback on
/// parse error), metadata, collapsible source. Pushed full-screen.
class AlphaDetailPage extends ConsumerStatefulWidget {
  const AlphaDetailPage({super.key, required this.alphaId});
  final String alphaId;

  @override
  ConsumerState<AlphaDetailPage> createState() => _AlphaDetailPageState();
}

class _AlphaDetailPageState extends ConsumerState<AlphaDetailPage> {
  AlphaDetail? _alpha;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      _alpha = await ref.read(apiProvider).getAlpha(widget.alphaId);
      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text(widget.alphaId, style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final a = _alpha!;
    return ListView(padding: const EdgeInsets.all(12), children: [
      if (a.zoo != null || a.theme.isNotEmpty || a.universe.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (a.zoo != null) Chip(label: Text(a.zoo!)),
          for (final t in a.theme) Chip(label: Text(t)),
          for (final u in a.universe) Chip(label: Text(u)),
        ]),
      const SizedBox(height: 12),
      const Text('Formula', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: FittedBox(
          alignment: Alignment.centerLeft,
          child: _latex(a.formulaLatex),
        ),
      ),
      const SizedBox(height: 16),
      ..._metadata(a),
      if (a.source != null) ...[
        const SizedBox(height: 16),
        ExpansionTile(
          title: const Text('Source'),
          children: [SelectableText(a.source!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))],
        ),
      ],
    ]);
  }

  List<Widget> _metadata(AlphaDetail a) {
    final rows = <(String, String?)>[
      ('universe', a.universe.isEmpty ? null : a.universe.join(', ')),
      ('theme', a.theme.isEmpty ? null : a.theme.join(', ')),
      ('frequency', a.frequency),
      ('decay_horizon', a.decayHorizon?.toString()),
      ('min_warmup_bars', a.minWarmupBars?.toString()),
      ('module_path', a.modulePath),
      ('notes', a.notes),
    ];
    return [
      for (final (k, v) in rows)
        if (v != null && v.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: 110,
                  child: Text(k,
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline))),
              const SizedBox(width: 12),
              Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
            ]),
          ),
    ];
  }

  Widget _latex(String? tex) {
    final src = tex?.trim() ?? '';
    if (src.isEmpty) return const Text('—', style: TextStyle(color: Colors.grey));
    try {
      return Math.tex(src);
    } catch (_) {
      // Unsupported macro / parse error → fall back to raw text.
      return SelectableText(src, style: const TextStyle(fontFamily: 'monospace', fontSize: 13));
    }
  }
}
