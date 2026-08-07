import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/config/app_config.dart';

/// Shadow-account report viewer. `/shadow-reports/:id` is a backend-rendered
/// HTML route (not a frontend page), so it opens in an in-app WebView with the
/// Bearer header injected when an API key is set.
class ShadowReportPage extends ConsumerStatefulWidget {
  const ShadowReportPage({super.key, required this.shadowId});
  final String shadowId;

  @override
  ConsumerState<ShadowReportPage> createState() => _ShadowReportPageState();
}

class _ShadowReportPageState extends ConsumerState<ShadowReportPage> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cfg = ref.read(appConfigProvider);
    final url = '${cfg.baseUrl}/shadow-reports/${widget.shadowId}?format=html';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (e) => setState(() {
          _loading = false;
          _error = e.description;
        }),
      ))
      ..loadRequest(
        Uri.parse(url),
        headers: cfg.apiKey.isNotEmpty ? {'Authorization': 'Bearer ${cfg.apiKey}'} : const {},
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: Text('Shadow ${widget.shadowId}', style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
      ),
      body: Stack(children: [
        if (_error != null)
          Center(child: Text(_error!))
        else
          WebViewWidget(controller: _controller),
        if (_loading) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
