import 'package:flutter/material.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

/// Chat input bar. Mobile design (per plan §7.2): Enter inserts a newline and
/// only the dedicated Send button submits — this sidesteps the IME/CJK
/// composition-vs-send problem the React `Composer` works around (keyCode 229
/// guards) without any special handling. The `+` menu opens a bottom sheet;
/// the kill switch is a separate, always-reachable button when live is active.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    required this.onMenuUpload,
    required this.onMenuGoal,
    required this.onMenuSwarm,
    required this.onMenuConnector,
    required this.isStreaming,
    required this.onStop,
    required this.onHalt,
    required this.liveActive,
    this.hintText,
    this.controller,
  });

  final ValueChanged<String> onSend;
  final VoidCallback onMenuUpload;
  final VoidCallback onMenuGoal;
  final VoidCallback onMenuSwarm;
  final VoidCallback onMenuConnector;
  final bool isStreaming;
  final VoidCallback onStop;
  final VoidCallback onHalt;
  final bool liveActive;
  final String? hintText;
  /// Optional external controller — when provided, the Composer uses it
  /// instead of its own, so the parent can set text (e.g. from example picks).
  final TextEditingController? controller;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  late final TextEditingController _ctrl;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _ctrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Only dispose if we own it (not passed from parent).
    if (widget.controller == null) _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _hasText => _ctrl.text.trim().isNotEmpty;

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _focus.unfocus();
    _ctrl.clear();
    _focus.requestFocus();
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.upload_file),
                title: Text(AppLocalizations.of(context)!.composerUpload),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMenuUpload();
                }),
            ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(AppLocalizations.of(context)!.composerGoal),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMenuGoal();
                }),
            ListTile(
                leading: const Icon(Icons.groups),
                title: Text(AppLocalizations.of(context)!.composerSwarm),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMenuSwarm();
                }),
            ListTile(
                leading: const Icon(Icons.link),
                title: Text(AppLocalizations.of(context)!.composerConnector),
                onTap: () {
                  Navigator.pop(context);
                  widget.onMenuConnector();
                }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.liveActive)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        size: 16, color: theme.colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(AppLocalizations.of(context)!.liveActive,
                            style: const TextStyle(fontSize: 12))),
                    TextButton.icon(
                      onPressed: widget.onHalt,
                      icon: const Icon(Icons.power_settings_new, size: 18),
                      label: Text(AppLocalizations.of(context)!.halt),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _openMenu,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: AppLocalizations.of(context)!.more,
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: widget.hintText ?? AppLocalizations.of(context)!.composerHint,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                widget.isStreaming
                    ? IconButton.filled(
                        onPressed: widget.onStop,
                        icon: const Icon(Icons.stop),
                        tooltip: AppLocalizations.of(context)!.stop,
                      )
                    : IconButton.filled(
                        onPressed: _hasText ? _submit : null,
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: AppLocalizations.of(context)!.send,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
