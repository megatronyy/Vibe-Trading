import 'package:flutter/material.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../../core/models/agent_message.dart';

/// A folded group of thinking / tool_call / tool_result / compact messages
/// shown as one collapsible card — the port of the React `ThinkingTimeline`.
/// Steps are the consecutive non-answer/non-user messages since the last
/// assistant answer. Each step shows a status icon, the tool or stage name,
/// and accumulated elapsed time.
class ThinkingTimeline extends StatelessWidget {
  const ThinkingTimeline({super.key, required this.steps});

  final List<AgentMessage> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folded = _fold(steps);
    final totalMs = folded.fold<int>(0, (s, st) => s + (st.elapsedMs ?? 0));
    final running = folded.any((s) => s.status == 'running');

    return Card(
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: SizedBox(
            width: 18,
            height: 18,
            child: running
                ? CircularProgressIndicator(strokeWidth: 2)
                : Icon(Icons.check_circle, size: 18, color: Colors.green),
          ),
          title: Text(
            running ? AppLocalizations.of(context)!.agentThinking : AppLocalizations.of(context)!.agentThoughtProcess,
            style: theme.textTheme.bodyMedium?.copyWith(
                color: running ? theme.colorScheme.primary : theme.colorScheme.outline),
          ),
          subtitle: Text(
            '${folded.length} steps · ${_fmtMs(totalMs)}',
            style: const TextStyle(fontSize: 11),
          ),
          children: [
            for (final s in folded)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 2, 16, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusIcon(s.status),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                          if (s.preview != null)
                            Text(s.preview!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                    if (s.elapsedMs != null)
                      Text(_fmtMs(s.elapsedMs!),
                          style: TextStyle(
                              fontSize: 11, color: theme.colorScheme.outline)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /// Merge consecutive tool_call + tool_result into one step (tool name +
  /// result preview + elapsed). thinking/compact entries become their own steps.
  List<_Step> _fold(List<AgentMessage> steps) {
    final out = <_Step>[];
    for (final m in steps) {
      switch (m.type) {
        case AgentMessageType.toolCall:
          out.add(_Step(
            label: m.tool ?? m.stage ?? 'tool',
            status: m.status ?? 'running',
            preview: null,
            elapsedMs: m.elapsedMs,
          ));
          break;
        case AgentMessageType.toolResult:
          if (out.isNotEmpty && out.last.label == (m.tool ?? 'tool')) {
            out[out.length - 1] = out.last.copyWith(
              status: m.status ?? 'ok',
              preview: m.content.isNotEmpty ? m.content : null,
            );
          } else {
            out.add(_Step(
              label: m.tool ?? 'result',
              status: m.status ?? 'ok',
              preview: m.content.isNotEmpty ? m.content : null,
              elapsedMs: m.elapsedMs,
            ));
          }
          break;
        case AgentMessageType.thinking:
        case AgentMessageType.compact:
        default:
          out.add(_Step(
            label: m.stage ?? m.tool ?? (m.type == AgentMessageType.compact ? 'compact' : 'thinking'),
            status: m.status ?? 'ok',
            preview: null,
            elapsedMs: m.elapsedMs,
          ));
      }
    }
    return out;
  }

  static Widget _statusIcon(String? status) {
    switch (status) {
      case 'running':
        return const SizedBox(
            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2));
      case 'error':
        return const Icon(Icons.error_outline, size: 16, color: Colors.red);
      default:
        return const Icon(Icons.check, size: 16, color: Colors.green);
    }
  }

  static String _fmtMs(int ms) {
    if (ms < 1000) return '${ms}ms';
    final s = ms / 1000;
    if (s < 60) return '${s.toStringAsFixed(1)}s';
    return '${(s / 60).toStringAsFixed(1)}m';
  }
}

class _Step {
  const _Step(
      {required this.label,
      required this.status,
      required this.preview,
      required this.elapsedMs});
  final String label;
  final String status;
  final String? preview;
  final int? elapsedMs;

  _Step copyWith({String? status, String? preview, int? elapsedMs}) => _Step(
        label: label,
        status: status ?? this.status,
        preview: preview ?? this.preview,
        elapsedMs: elapsedMs ?? this.elapsedMs,
      );
}
