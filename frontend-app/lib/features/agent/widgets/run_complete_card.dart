import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/agent_message.dart';
import 'pine_script_viewer.dart';

/// Lite run-complete card: status + metric pills + links to the full report and
/// Pine Script. The mini equity chart lands in P2 (needs fl_chart); Shadow
/// report link arrives when shadowId capture is wired.
class RunCompleteCard extends ConsumerWidget {
  const RunCompleteCard({super.key, required this.message});

  final AgentMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final metrics = message.metrics ?? const <String, double>{};
    final pills = <_Pill>[
      if (metrics['total_return'] != null)
        _Pill('Return', '${(metrics['total_return']! * 100).toStringAsFixed(1)}%',
            metrics['total_return']! >= 0 ? Colors.green : Colors.red),
      if (metrics['sharpe'] != null)
        _Pill('Sharpe', metrics['sharpe']!.toStringAsFixed(2), theme.colorScheme.primary),
      if (metrics['max_drawdown'] != null)
        _Pill('MaxDD', '${(metrics['max_drawdown']! * 100).toStringAsFixed(1)}%', Colors.red),
      if (metrics['win_rate'] != null)
        _Pill('Win', '${(metrics['win_rate']! * 100).toStringAsFixed(0)}%', theme.colorScheme.secondary),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Backtest complete',
                    style: theme.textTheme.titleSmall),
              ),
              if (message.runId != null) ...[
                TextButton(
                  onPressed: () => showPineScript(context, ref, message.runId!),
                  child: const Text('Pine'),
                ),
                TextButton(
                  onPressed: () => context.push('/runs/${message.runId}'),
                  child: const Text('Report'),
                ),
              ],
            ]),
            if (pills.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final p in pills) _pill(p, theme)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill(_Pill p, ThemeData theme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: p.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('${p.label}: ${p.value}',
            style: TextStyle(
                fontSize: 12, color: p.color, fontWeight: FontWeight.w600)),
      );
}

class _Pill {
  const _Pill(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
}
