import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/run.dart';
import '../../core/net/api.dart';
import '../../core/net/api_error.dart';

/// Backtest report library — list + client-side filter/sort + cards. Mobile
/// port of the React `Reports`: the 5-control filter bar folds into a single
/// "Filter" expandable; cards open `RunDetail`.
class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  List<RunListItem> _all = const [];
  List<RunListItem> _shown = const [];
  bool _loading = true;
  String? _error;
  String _needle = '';
  String _sort = 'newest';
  final _filterKey = GlobalKey<FormFieldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final runs = await ref.read(apiProvider).listRuns(100);
      _all = runs.where(_isReport).toList();
      _apply();
      setState(() => _loading = false);
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  // A "report" run has metrics (finite total_return or sharpe).
  bool _isReport(RunListItem r) =>
      (r.metrics?['total_return'] != null && r.metrics!['total_return']!.isFinite) ||
      (r.metrics?['sharpe'] != null && r.metrics!['sharpe']!.isFinite);

  void _apply() {
    var list = [..._all];
    if (_needle.isNotEmpty) {
      final n = _needle.toLowerCase();
      list = list
          .where((r) =>
              (r.id.toLowerCase().contains(n)) ||
              (r.prompt?.toLowerCase().contains(n) ?? false))
          .toList();
    }
    list.sort((a, b) {
      switch (_sort) {
        case 'oldest':
          return (a.startedAt ?? DateTime(1970)).compareTo(b.startedAt ?? DateTime(1970));
        case 'return_desc':
          return (b.metrics?['total_return'] ?? -1e9)
              .compareTo(a.metrics?['total_return'] ?? -1e9);
        case 'sharpe_desc':
          return (b.metrics?['sharpe'] ?? -1e9).compareTo(a.metrics?['sharpe'] ?? -1e9);
        case 'newest':
        default:
          return (b.startedAt ?? DateTime(1970)).compareTo(a.startedAt ?? DateTime(1970));
      }
    });
    _shown = list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.reportsTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(children: [
        ExpansionTile(
          title: Text(AppLocalizations.of(context)!.filter),
          leading: const Icon(Icons.filter_list),
          initiallyExpanded: false,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                TextField(
                  key: _filterKey,
                  decoration: InputDecoration(hintText: AppLocalizations.of(context)!.searchRun, isDense: true),
                  onChanged: (v) => setState(() { _needle = v; _apply(); }),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: _sort, isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 'newest', child: Text(AppLocalizations.of(context)!.sortNewest)),
                    DropdownMenuItem(value: 'oldest', child: Text(AppLocalizations.of(context)!.sortOldest)),
                    DropdownMenuItem(value: 'return_desc', child: Text(AppLocalizations.of(context)!.sortReturnDesc)),
                    DropdownMenuItem(value: 'sharpe_desc', child: Text(AppLocalizations.of(context)!.sortSharpeDesc)),
                  ],
                  onChanged: (v) => setState(() { _sort = v ?? 'newest'; _apply(); }),
                ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(AppLocalizations.of(context)!.nOfM(_shown.length.toString(), _all.length.toString()), style: const TextStyle(fontSize: 12)),
          ),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_shown.isEmpty) return Center(child: Text(AppLocalizations.of(context)!.noReports));
    return ListView.builder(
      itemCount: _shown.length,
      itemBuilder: (_, i) => _card(_shown[i]),
    );
  }

  Widget _card(RunListItem r) {
    final m = r.metrics ?? const <String, double>{};
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(r.prompt?.isNotEmpty == true ? r.prompt! : r.id, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            if (m['total_return'] != null)
              _pill('Return ${(m['total_return']! * 100).toStringAsFixed(1)}%',
                  m['total_return']! >= 0 ? Colors.green : Colors.red),
            if (m['sharpe'] != null)
              _pill('Sharpe ${m['sharpe']!.toStringAsFixed(2)}', Theme.of(context).colorScheme.primary),
            if (r.status != null) _pill(r.status!, Colors.grey),
          ]),
        ),
        onTap: () => context.push('/runs/${r.id}'),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}
