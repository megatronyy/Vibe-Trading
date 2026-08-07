import 'package:flutter/material.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../../core/models/agent_message.dart';

/// Inline timeline chip for `live.action` events (order_rejected, breach,
/// halt_tripped, mandate_committed, halt_cleared, …). Port of the React
/// `LiveActionChip` — tone-colored by kind.
class LiveActionChip extends StatelessWidget {
  const LiveActionChip({super.key, required this.message});
  final AgentMessage message;

  @override
  Widget build(BuildContext context) {
    final d = message.liveAction ?? const <String, dynamic>{};
    final kind = (d['kind'] as String?) ?? 'action';
    final intent = d['intent_normalized'] as String?;
    final outcome = d['outcome'] as String?;
    final tool = d['remote_tool'] as String?;
    final err = d['error'] as String?;
    final (color, icon) = _tone(kind);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(AppLocalizations.of(context)!.runtimeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
              const SizedBox(width: 6),
              Flexible(child: Text(kind.replaceAll('_', ' '),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              if (outcome != null) ...[
                const SizedBox(width: 6),
                Text(outcome, style: TextStyle(fontSize: 11, color: color)),
              ],
            ]),
            if (intent != null)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(intent, style: const TextStyle(fontSize: 12))),
            if (tool != null)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(tool, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline))),
            if (err != null)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(err, style: const TextStyle(fontSize: 11, color: Colors.red))),
          ]),
        ),
      ]),
    );
  }

  (Color, IconData) _tone(String kind) {
    switch (kind) {
      case 'halt_tripped':
        return (Colors.red, Icons.power_settings_new);
      case 'mandate_committed':
      case 'halt_cleared':
        return (Colors.green, Icons.check_circle_outline);
      case 'order_rejected':
      case 'breach':
        return (Colors.orange, Icons.warning_amber);
      default:
        return (Colors.blue, Icons.bolt);
    }
  }
}
