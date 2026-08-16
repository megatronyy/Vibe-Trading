import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/state/agent_notifier.dart';

/// Safety-critical mandate confirmation. Shown as a full-screen sheet when a
/// `mandate.proposal` arrives. The user picks a profile, then a SEPARATE
/// "Confirm" button triggers biometric auth (Face ID / Touch ID / fingerprint)
/// and only on success sends `POST /mandate/commit` with `consent_ack: true`.
///
/// Invariants (plan §6.6):
/// - Confirmation never shares a position with the proposal's send/dismiss.
/// - No biometrics available ⇒ falls back to a double-tap confirm.
/// - The commit goes through `api.commitMandate`, never `sendMessage`.
void showMandateProposalSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> proposal) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _MandateSheet(proposal: proposal),
  );
}

class _MandateSheet extends ConsumerStatefulWidget {
  const _MandateSheet({required this.proposal});
  final Map<String, dynamic> proposal;

  @override
  ConsumerState<_MandateSheet> createState() => _MandateSheetState();
}

class _MandateSheetState extends ConsumerState<_MandateSheet> {
  int _selected = 0;
  bool _busy = false;
  final _auth = LocalAuthentication();

  List<Map<String, dynamic>> get _profiles {
    final p = widget.proposal['profiles'];
    return p is List ? p.cast<Map<String, dynamic>>() : const [];
  }

  String get _proposalId => widget.proposal['proposal_id'] as String? ?? '';

  Future<void> _confirm() async {
    setState(() => _busy = true);
    bool ok = false;
    try {
      // Only require biometric auth when the device has hardware AND at least
      // one biometric enrolled. A device with a lock screen but no enrolled
      // biometrics can never pass `authenticate` — fall back to the explicit
      // double-confirm instead of dead-ending the user.
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (supported && canCheck) {
        ok = await _auth.authenticate(
          localizedReason: 'Confirm mandate submission',
        );
      } else {
        // No biometrics (or none enrolled) → explicit double-confirm.
        ok = await _doubleConfirm();
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      _toast('Biometric confirmation required');
      return;
    }
    final profile = _profiles.isNotEmpty ? _profiles[_selected] : <String, dynamic>{};
    final committed =
        await ref.read(agentProvider.notifier).commitMandate(_proposalId, profile);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!committed) {
      // Keep the sheet open so the user can retry — closing here would lose
      // the proposal (it only re-opens on a null→non-null transition).
      _toast(AppLocalizations.of(context)!.mandateCommitFailed);
      return;
    }
    Navigator.pop(context);
  }

  Future<bool> _doubleConfirm() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx)!.doubleConfirmTitle),
            content: Text(AppLocalizations.of(ctx)!.doubleConfirmBody),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(ctx)!.commonCancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppLocalizations.of(ctx)!.commonSubmit)),
            ],
          ),
        ) ??
        false;
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final account = widget.proposal['account'];
    return PopScope(
      canPop: false,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: ListView(controller: controller, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Icon(Icons.shield, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.mandateProposal, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.mandateNote,
                textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.outline, fontSize: 13)),
            if (account is Map) ...[
              const SizedBox(height: 12),
              Card(child: ListTile(dense: true, title: Text(AppLocalizations.of(context)!.account), subtitle: Text('${account['broker'] ?? "?"} · ${account['type'] ?? "?"}'))),
            ],
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.chooseProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
            for (var i = 0; i < _profiles.length; i++)
              InkWell(
                onTap: () => setState(() => _selected = i),
                child: Card(
                  color: _selected == i ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
                  child: ListTile(
                    leading: Icon(_selected == i ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _selected == i ? theme.colorScheme.primary : theme.colorScheme.outline),
                    title: Text(_profileTitle(_profiles[i])),
                    subtitle: Text(_profileLimits(_profiles[i]), style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            if (_profiles.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(AppLocalizations.of(context)!.noProfiles)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _confirm,
              icon: _busy
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.fingerprint),
              label: Text(AppLocalizations.of(context)!.confirmBiometrics),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      ref.read(agentProvider.notifier).dismissMandate();
                      Navigator.pop(context);
                    },
              child: Text(AppLocalizations.of(context)!.commonDismiss),
            ),
          ]),
        ),
      ),
    );
  }

  String _profileTitle(Map<String, dynamic> p) => (p['name'] ?? p['label'] ?? 'Profile') as String;
  String _profileLimits(Map<String, dynamic> p) {
    final parts = <String>[];
    for (final k in const ['max_order_size', 'daily_cap', 'max_leverage', 'universe_size']) {
      if (p[k] != null) parts.add('$k: ${p[k]}');
    }
    return parts.isEmpty ? '' : parts.join('  ·  ');
  }
}
