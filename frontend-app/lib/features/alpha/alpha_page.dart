import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/alpha.dart';
import '../../core/net/api.dart';
import '../../core/net/api_error.dart';

/// Alpha Zoo browse view: zoo cards + filter bar + catalogue list. The shell
/// "Alpha" tab lands here; bench / compare / detail are pushed full-screen.
class AlphaPage extends ConsumerStatefulWidget {
  const AlphaPage({super.key});

  @override
  ConsumerState<AlphaPage> createState() => _AlphaPageState();
}

class _AlphaPageState extends ConsumerState<AlphaPage> {
  List<AlphaSummary> _all = const [];
  List<AlphaSummary> _shown = const [];
  bool _loading = true;
  String? _error;
  String _needle = '';
  String? _zoo;
  String _universe = 'csi300';

  static const _zoos = ['qlib158', 'alpha101', 'gtja191', 'academic', 'fundamental'];
  static const _universes = ['csi300', 'sp500', 'btc-usdt'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(apiProvider).listAlphas(universe: _universe, limit: 200);
      _all = list;
      _apply();
      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _apply() {
    var list = [..._all];
    if (_zoo != null) list = list.where((a) => a.zoo == _zoo).toList();
    if (_needle.isNotEmpty) {
      final n = _needle.toLowerCase();
      list = list.where((a) =>
          a.id.toLowerCase().contains(n) ||
          (a.nickname?.toLowerCase().contains(n) ?? false)).toList();
    }
    _shown = list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.alphaTitle), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        PopupMenuButton<String>(
          icon: const Icon(Icons.science_outlined),
          onSelected: (v) => context.push(v == 'bench' ? '/alpha-zoo/bench' : '/alpha-zoo/compare'),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'bench', child: Text(AppLocalizations.of(context)!.runBenchmark)),
            PopupMenuItem(value: 'compare', child: Text(AppLocalizations.of(context)!.compareAlphas)),
          ],
        ),
      ]),
      body: Column(children: [
        SizedBox(
          height: 92,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [
            for (final z in _zoos)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(z),
                  selected: _zoo == z,
                  onSelected: (_) => setState(() { _zoo = _zoo == z ? null : z; _apply(); }),
                ),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(child: TextField(
              decoration: InputDecoration(hintText: AppLocalizations.of(context)!.searchIdNickname, isDense: true),
              onChanged: (v) => setState(() { _needle = v; _apply(); }),
            )),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _universe,
              items: [for (final u in _universes) DropdownMenuItem(value: u, child: Text(u))],
              onChanged: (v) { if (v != null) { setState(() => _universe = v); _load(); } },
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_shown.isEmpty) return const Center(child: Text('No alphas'));
    return ListView.builder(
      itemCount: _shown.length,
      itemBuilder: (_, i) {
        final a = _shown[i];
        return ListTile(
          title: Text(a.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          subtitle: Text([
                  a.zoo,
                  if (a.theme.isNotEmpty) a.theme.join('/'),
                  if (a.universe.isNotEmpty) a.universe.join('/'),
                ].whereType<String>().join(' · '),
              style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/alpha-zoo/${a.id}'),
        );
      },
    );
  }
}
