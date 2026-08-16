import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../app/app_state.dart';
import '../../core/net/api.dart';
import '../../core/net/api_error.dart';

/// Settings: backend connection + appearance + LLM + data source + IM channels.
/// Saving the backend connection re-creates the [dioProvider] live (no reload,
/// unlike the React app's `window.location.reload()`). QVeris is intentionally
/// out of scope this phase.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Backend connection config removed from UI — now compile-time in app_config.dart.

  // LLM
  final _llmCtrls = <String, TextEditingController>{
    'provider': TextEditingController(),
    'model_name': TextEditingController(),
    'base_url': TextEditingController(),
    'api_key': TextEditingController(),
    'temperature': TextEditingController(),
    'timeout_seconds': TextEditingController(),
    'max_retries': TextEditingController(),
  };
  // Backend LLM_REASONING_EFFORTS = {"", "none", "low", "medium", "high",
  // "max"} — "" leaves the setting unset (provider default). Must stay in
  // sync with agent/src/api/settings_routes.py.
  static const _reasoningEfforts = ['', 'none', 'low', 'medium', 'high', 'max'];
  String _reasoningEffort = '';

  // Model discovery
  Future<List<String>> _modelsFuture = Future.value(const <String>[]);

  // Data source
  final _dsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    for (final c in _llmCtrls.values) {
      c.dispose();
    }
    _dsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final api = ref.read(apiProvider);
    final results = await Future.wait([
      api.getLLMSettings().catchError((_) => <String, dynamic>{}),
      api.getDataSourceSettings().catchError((_) => <String, dynamic>{}),
    ]);
    final llm = (results[0] as Map).cast<String, dynamic>();
    final ds = (results[1] as Map).cast<String, dynamic>();
    if (mounted) {
      setState(() {
        for (final k in _llmCtrls.keys) {
          _llmCtrls[k]!.text = (llm[k] ?? '').toString();
        }
        // Clamp to a value the dropdown actually offers, else DropdownButton
        // asserts (backend may use 'minimal'/…, which we map to unset).
        final re = llm['reasoning_effort']?.toString() ?? '';
        _reasoningEffort = _reasoningEfforts.contains(re) ? re : '';
        _dsCtrl.text = (ds['tushare_token'] ?? '').toString();
        // Fetch available models for the loaded provider.
        final provider = (llm['provider'] ?? '').toString();
        if (provider.isNotEmpty) {
          _modelsFuture = ref.read(apiProvider).listLLMModels(provider);
        }
      });
    }
  }


  Future<void> _saveLLM() async {
    final body = <String, dynamic>{
      for (final e in _llmCtrls.entries) e.key: e.value.text,
      'reasoning_effort': _reasoningEffort,
    };
    final temp = double.tryParse(_llmCtrls['temperature']!.text);
    if (temp != null) body['temperature'] = temp;
    final to = int.tryParse(_llmCtrls['timeout_seconds']!.text);
    if (to != null) body['timeout_seconds'] = to;
    final mr = int.tryParse(_llmCtrls['max_retries']!.text);
    if (mr != null) body['max_retries'] = mr;
    try {
      await ref.read(apiProvider).updateLLMSettings(body);
      _toast('LLM settings saved.');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _saveDataSource() async {
    try {
      await ref.read(apiProvider)
          .updateDataSourceSettings({'tushare_token': _dsCtrl.text});
      _toast('Data source saved.');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Backend connection section removed — base URL is now configured via
        // app_config.dart (compile-time default) or secure storage (set by
        // the build/installer, not editable from the UI).

        _section(l.settingsAppearance),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            const Icon(Icons.brightness_6, size: 20),
            const SizedBox(width: 12),
            Text(l.settingsTheme),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.auto_mode), label: Text(l.settingsThemeSystem)),
              ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode), label: Text(l.settingsThemeLight)),
              ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode), label: Text(l.settingsThemeDark)),
            ],
            selected: {themeMode},
            onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l.settingsLanguage),
          trailing: DropdownButton<Locale?>(
            value: supportedLocales.contains(locale) ? locale : null,
            hint: Text(l.settingsSystem),
            items: [
              DropdownMenuItem(value: null, child: Text(l.settingsSystem)),
              ...supportedLocales.map((loc) => DropdownMenuItem(value: loc, child: Text(_localeLabel(loc)))),
            ],
            onChanged: (loc) {
              ref.read(localeProvider.notifier).set(loc);
              _toast(l.settingsLanguageChanged);
            },
          ),
        ),
        const SizedBox(height: 20),

        _section(l.settingsLLM),
        _llmRow('provider', l.provider),
        _llmRow('model_name', l.model),
        // Model discovery: fetch models for the current provider and show a
        // dropdown; falls back to the plain text field if the endpoint is
        // unavailable.
        FutureBuilder<List<String>>(
          future: _modelsFuture,
          builder: (ctx, snap) {
            final models = snap.data ?? const [];
            if (models.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DropdownButton<String>(
                isExpanded: true,
                hint: Text('选择模型'),
                value: models.contains(_llmCtrls['model_name']!.text)
                    ? _llmCtrls['model_name']!.text
                    : null,
                items: [for (final m in models) DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13)))],
                onChanged: (v) { if (v != null) setState(() => _llmCtrls['model_name']!.text = v); },
              ),
            );
          },
        ),
        _llmRow('base_url', l.settingsBaseUrl),
        _llmRow('api_key', l.settingsApiKey, obscure: true),
        Row(children: [
          Expanded(child: _llmRow('temperature', l.temp)),
          const SizedBox(width: 8),
          Expanded(child: _llmRow('timeout_seconds', l.timeoutSec)),
          const SizedBox(width: 8),
          Expanded(child: _llmRow('max_retries', l.retries)),
        ]),
        DropdownButton<String>(
          value: _reasoningEffort, isExpanded: true,
          items: _reasoningEfforts
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e.isEmpty
                        ? l.reasoningProviderDefault
                        : l.reasoningLabel(e)),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _reasoningEffort = v ?? ''),
        ),
        FilledButton(onPressed: _saveLLM, child: Text('${l.commonSave} ${l.settingsLLM}')),
        const SizedBox(height: 20),

        _section(l.settingsDataSource),
        TextField(controller: _dsCtrl, decoration: InputDecoration(labelText: l.tushareToken), obscureText: true),
        const SizedBox(height: 8),
        FilledButton(onPressed: _saveDataSource, child: Text('${l.commonSave} ${l.settingsDataSource}')),
        const SizedBox(height: 20),

        // "Clear stored credentials" removed — no longer has connection config to clear.
      ]),
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );

  Widget _llmRow(String key, String label, {bool obscure = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(controller: _llmCtrls[key], decoration: InputDecoration(labelText: label, isDense: true), obscureText: obscure),
      );

  static String _localeLabel(Locale l) {
    switch (l.languageCode) {
      case 'en': return 'English';
      case 'zh': return '中文';
      case 'ja': return '日本語';
      case 'ko': return '한국어';
      case 'ar': return 'العربية';
      default: return l.languageCode;
    }
  }
}
