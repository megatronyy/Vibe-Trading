import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import '../../../core/util/share_file.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/net/api.dart';
import '../../../core/net/api_error.dart';

/// Pine Script viewer (P5): full-screen modal showing the generated TradingView
/// Pine code, with copy / share and a link to the Pine Editor docs. Port of the
/// React `PineScriptViewer`.
Future<void> showPineScript(BuildContext context, WidgetRef ref, String runId) async {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _PineScreen(runId: runId, api: ref.read(apiProvider)),
  ));
}

class _PineScreen extends StatefulWidget {
  const _PineScreen({required this.runId, required this.api});
  final String runId;
  final Api api;

  @override
  State<_PineScreen> createState() => _PineScreenState();
}

class _PineScreenState extends State<_PineScreen> {
  String? _code;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final code = await widget.api.getRunPine(widget.runId);
      setState(() {
        _code = code;
        _loading = false;
        if (code == null || code.isEmpty) _error = 'No Pine Script for this run.';
      });
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.pineTitle),
        actions: [
          if (_code != null && _code!.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: AppLocalizations.of(context)!.copied,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _code!));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.copied)));
              },
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share',
              onPressed: () => shareFile(_code!, 'pine_${widget.runId}.pine'),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.menu_book),
            tooltip: AppLocalizations.of(context)!.pineDocs,
            onPressed: () => launchUrl(Uri.parse('https://www.tradingview.com/pine-script-docs/')),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(_code!,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4)),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            AppLocalizations.of(context)!.pineHint,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}
