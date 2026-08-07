import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../core/models/models.dart';
import '../../core/net/api.dart';
import '../../core/net/api_error.dart';

/// Live runtime monitor (read-only). 15s poll of `/live/status` + a 1s clock
/// for mandate countdowns. Per-broker cards show auth / runner / mandate /
/// halt state. SDK brokers get verify/retry; OAuth brokers get runner controls.
class RuntimePage extends ConsumerStatefulWidget {
  const RuntimePage({super.key});

  @override
  ConsumerState<RuntimePage> createState() => _RuntimePageState();
}

class _RuntimePageState extends ConsumerState<RuntimePage> {
  LiveStatus? _status;
  bool _loading = true;
  String? _error;
  Timer? _poll;
  Timer? _clock;
  int _tick = 0;
  final _busyBrokers = <String>{};

  bool get _hasActiveMandates =>
      _status?.brokers.any((b) => b.mandate != null) ?? false;

  @override
  void initState() {
    super.initState();
    _fetch();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetch();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  void _ensureClock() {
    if (_hasActiveMandates && _clock == null) {
      _clock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _tick++);
      });
    } else if (!_hasActiveMandates && _clock != null) {
      _clock?.cancel();
      _clock = null;
    }
  }

  Future<void> _fetch() async {
    try {
      final s = await ref.read(apiProvider).getLiveStatus();
      if (!mounted) return;
      setState(() {
        _status = s;
        _loading = false;
        _error = null;
      });
      _ensureClock();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.runtimeTitle),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : ListView(padding: const EdgeInsets.all(12), children: [
                  // Summary tiles
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _globalHaltTile(s?.globalHalted == true),
                    _summaryTile(
                      AppLocalizations.of(context)!.brokers,
                      '${s?.brokers.length ?? 0}',
                      Colors.blue),
                    _summaryTile(
                      AppLocalizations.of(context)!.authorized,
                      '${s?.brokers.where((b) => b.isAuthorized).length ?? 0}',
                      Colors.green),
                    _summaryTile(
                      AppLocalizations.of(context)!.runners,
                      '${s?.brokers.where((b) => b.isRunnerAlive).length ?? 0}',
                      Colors.orange),
                  ]),
                  const SizedBox(height: 12),
                  for (final b in s?.brokers ?? const <LiveBroker>[])
                    _brokerCard(b),
                  if (s == null || s.brokers.isEmpty)
                    Center(child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(AppLocalizations.of(context)!.noLiveBrokers))),
                ]),
    );
  }

  // --- Widgets -----------------------------------------------------------

  Widget _summaryTile(String label, String value, Color c) => SizedBox(
        width: (MediaQuery.sizeOf(context).width - 40) / 2,
        child: Card(
          child: ListTile(
            dense: true,
            title: Text(value,
                style: TextStyle(fontSize: 18, color: c, fontWeight: FontWeight.bold)),
            subtitle: Text(label, style: const TextStyle(fontSize: 11)),
          ),
        ),
      );

  /// Global halt summary tile — mirrors `_summaryTile`, but adds a small
  /// Resume button below the value when a global halt is active.
  Widget _globalHaltTile(bool halted) {
    final c = halted ? Colors.red : Colors.green;
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 40) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(halted ? 'HALTED' : AppLocalizations.of(context)!.rtOk,
                  style: TextStyle(fontSize: 18, color: c, fontWeight: FontWeight.bold)),
              Text(AppLocalizations.of(context)!.globalHalt,
                  style: const TextStyle(fontSize: 11)),
              if (halted)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _resumeGlobal,
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: Text(AppLocalizations.of(context)!.rtResume),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      );

  Widget _brokerCard(LiveBroker b) {
    final isSdk = b.isSdk;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        initiallyExpanded: b.hasMandate || b.halted,
        title: Text(b.broker.isEmpty ? AppLocalizations.of(context)!.rtUnknown : b.broker),
        subtitle: Wrap(spacing: 6, runSpacing: 4, children: [
          _pill(
            b.isAuthorized
                ? AppLocalizations.of(context)!.pillAuthorized
                : AppLocalizations.of(context)!.pillNoAuth,
            b.isAuthorized ? Colors.green : Colors.grey),
          _pill(
            b.isRunnerAlive
                ? AppLocalizations.of(context)!.pillRunner
                : AppLocalizations.of(context)!.pillStopped,
            b.isRunnerAlive ? Colors.orange : Colors.grey),
          if (b.halted) _pill(AppLocalizations.of(context)!.pillHalted, Colors.red),
          if (b.hasMandate) _pill(AppLocalizations.of(context)!.pillMandate, Colors.blue),
          if (isSdk && b.auth.connectionState != null)
            _pill(b.auth.connectionState!, _connColor(b.auth.connectionState)),
        ]),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Transport / connection info
              if (isSdk) ...[
                _infoRow(AppLocalizations.of(context)!.rtTransport, b.auth.transport ?? 'broker_sdk'),
                if (b.auth.connectionState != null)
                  _infoRow(AppLocalizations.of(context)!.rtConnection, b.auth.connectionState!),
                if (b.auth.errorCode != null)
                  _infoRow(AppLocalizations.of(context)!.rtError, b.auth.errorCode!, color: Colors.red),
                if (b.auth.configured == false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('⚠ ${AppLocalizations.of(context)!.rtSdkNotConfigured}',
                        style: const TextStyle(fontSize: 12, color: Colors.orange)),
                  ),
              ] else ...[
                _infoRow(AppLocalizations.of(context)!.rtOauthToken,
                    b.isAuthorized ? AppLocalizations.of(context)!.rtPresent : AppLocalizations.of(context)!.rtMissing,
                    color: b.isAuthorized ? Colors.green : Colors.red),
              ],
              // Runner liveness
              if (b.runner.lastTickAgeSeconds != null)
                _infoRow(AppLocalizations.of(context)!.rtLastTick,
                    AppLocalizations.of(context)!.rtAgo(b.runner.lastTickAgeSeconds!.toStringAsFixed(0))),
              // Active mandate
              if (b.mandate != null) ...[
                const SizedBox(height: 8),
                _mandateSection(b.mandate!),
              ] else if (!b.halted) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(AppLocalizations.of(context)!.rtNoMandate,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                ),
              ],
              // Actions
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                // Verify (SDK brokers)
                if (isSdk)
                  TextButton.icon(
                    onPressed: _busyBrokers.contains(b.broker)
                        ? null
                        : () => _verify(b.broker),
                    icon: const Icon(Icons.cached, size: 18),
                    label: Text(AppLocalizations.of(context)!.verify),
                  ),
                // Authorize (OAuth, not yet authorized)
                if (!isSdk && !b.isAuthorized)
                  TextButton.icon(
                    onPressed: _busyBrokers.contains(b.broker)
                        ? null
                        : () => _authorize(b.broker),
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(AppLocalizations.of(context)!.rtAuthorizeBtn),
                  ),
                // Start / Stop runner (has mandate, not halted)
                if (b.hasMandate && !b.halted) ...[
                  if (b.isRunnerAlive)
                    TextButton.icon(
                      onPressed: _busyBrokers.contains(b.broker)
                          ? null
                          : () => _runnerAction(b.broker, stop: true),
                      icon: const Icon(Icons.power_settings_new, size: 18),
                      label: Text(AppLocalizations.of(context)!.rtStopRunner),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    )
                  else
                    TextButton.icon(
                      onPressed: _busyBrokers.contains(b.broker)
                          ? null
                          : () => _runnerAction(b.broker, stop: false),
                      icon: const Icon(Icons.play_arrow, size: 18),
                      label: Text(AppLocalizations.of(context)!.rtStartRunner),
                      style: TextButton.styleFrom(foregroundColor: Colors.green),
                    ),
                ],
                // Resume (halted broker)
                if (b.halted)
                  TextButton.icon(
                    onPressed: _busyBrokers.contains(b.broker)
                        ? null
                        : () => _resume(b.broker),
                    icon: const Icon(Icons.play_circle_outline, size: 18),
                    label: Text(AppLocalizations.of(context)!.rtResume),
                    style: TextButton.styleFrom(foregroundColor: Colors.green),
                  ),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline))),
        const SizedBox(width: 8),
        Expanded(child: Text(value,
            style: TextStyle(fontSize: 13, color: color))),
      ]),
    );
  }

  Widget _mandateSection(ActiveMandate m) {
    final secs = m.expiresInSeconds ?? 0;
    final expiryColor = m.expired
        ? Colors.red
        : secs < 86400
            ? Colors.orange
            : Colors.green;
    // Human-friendly countdown
    String countdown;
    if (m.expired) {
      countdown = AppLocalizations.of(context)!.rtExpired;
    } else if (secs < 3600) {
      countdown = '${secs ~/ 60}m ${secs % 60}s';
    } else if (secs < 86400) {
      countdown = '${secs ~/ 3600}h ${(secs % 3600) ~/ 60}m';
    } else {
      countdown = '${secs ~/ 86400}d ${(secs % 86400) ~/ 3600}h';
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.shield, size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(AppLocalizations.of(context)!.rtActiveMandate,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: expiryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(countdown,
                style: TextStyle(fontSize: 11, color: expiryColor, fontWeight: FontWeight.w600)),
          ),
        ]),
        if (m.limits != null) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (m.limits!.maxOrderNotionalUsd > 0)
              _pill('≤\$${m.limits!.maxOrderNotionalUsd.toStringAsFixed(0)}/order', Colors.blue),
            if (m.limits!.maxTradesPerDay > 0)
              _pill('${m.limits!.maxTradesPerDay}/day', Colors.blue),
            if (m.limits!.maxLeverage > 0)
              _pill('${m.limits!.maxLeverage}x', Colors.blue),
          ]),
        ],
      ]),
    );
  }

  Color _connColor(String? state) {
    switch (state) {
      case 'connected':
      case 'ready':
        return Colors.green;
      case 'not_configured':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // --- Actions -----------------------------------------------------------

  Future<void> _verify(String broker) async {
    setState(() => _busyBrokers.add(broker));
    try {
      await ref.read(apiProvider).verifyConnector(broker);
      await _fetch();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyBrokers.remove(broker));
    }
  }

  Future<void> _authorize(String broker) async {
    setState(() => _busyBrokers.add(broker));
    try {
      final r = await ref.read(apiProvider).authorizeLive(broker);
      final instruction = r['instruction'] as String?;
      if (instruction != null && instruction.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx)!.rtAuthorizeTitle(broker)),
            content: SelectableText(instruction),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(ctx)!.rtOk)),
            ],
          ),
        );
      }
      await _fetch();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyBrokers.remove(broker));
    }
  }

  Future<void> _runnerAction(String broker, {required bool stop}) async {
    setState(() => _busyBrokers.add(broker));
    try {
      final api = ref.read(apiProvider);
      if (stop) {
        await api.stopLiveRunner(broker);
      } else {
        await api.startLiveRunner(broker);
      }
      await _fetch();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyBrokers.remove(broker));
    }
  }

  Future<void> _resume(String broker) async {
    setState(() => _busyBrokers.add(broker));
    try {
      await ref.read(apiProvider).resumeLive(broker: broker);
      await _fetch();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyBrokers.remove(broker));
    }
  }

  /// Clear the global halt (no broker scope) then refresh.
  Future<void> _resumeGlobal() async {
    try {
      await ref.read(apiProvider).resumeLive();
      await _fetch();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
