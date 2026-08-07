import 'package:flutter/material.dart';

import '../../../core/models/agent_message.dart';

/// Renders a running/finished tool with a determinate progress ring (when the
/// tool emits `current/total`) or an indeterminate spinner, plus an ETA
/// estimate derived from elapsed time × progress ratio — the port of the React
/// `ToolProgressIndicator` ETA engine.
class ToolProgressIndicator extends StatelessWidget {
  const ToolProgressIndicator({super.key, required this.tool});

  final ToolCallEntry tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = tool.progress;
    final determinate = progress?.isDeterminate ?? false;
    final eta = _estimateEta(tool);
    final pct = determinate && progress!.ratio != null
        ? '${(progress.ratio! * 100).round()}%'
        : null;

    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: determinate && progress!.ratio != null
              ? CircularProgressIndicator(
                  value: progress.ratio,
                  strokeWidth: 2.5,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                )
              : CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tool.tool,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (progress?.message != null || progress?.stage != null)
                Text(progress?.message ?? progress!.stage!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
            ],
          ),
        ),
        if (pct != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(pct,
                style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600)),
          ),
        if (eta != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(eta,
                style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
          ),
      ],
    );
  }

  /// ETA = elapsed × (1−ratio)/ratio, only when we have elapsed seconds and a
  /// meaningful ratio. Returns null (hide) when not estimable or < 1s left.
  static String? _estimateEta(ToolCallEntry t) {
    final p = t.progress;
    final elapsedS = t.elapsedS;
    if (p == null || !p.isDeterminate || elapsedS == null) return null;
    final ratio = p.ratio!;
    if (ratio <= 0.02) return null;
    final remaining = (elapsedS * (1 - ratio) / ratio).round();
    if (remaining < 1) return null;
    if (remaining < 60) return '~${remaining}s left';
    return '~${(remaining / 60).ceil()}m left';
  }
}
