import 'package:flutter/material.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../../core/models/agent_message.dart';

/// Swarm run status — mobile design: each agent is its own card (the React
/// desktop version is a 620px 6-column grid that relies on horizontal scroll).
class SwarmStatusCard extends StatelessWidget {
  const SwarmStatusCard({super.key, required this.status});

  final SwarmRunStatus? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = status;
    if (s == null) {
      return Card(child: ListTile(title: Text(AppLocalizations.of(context)!.swarmWaiting)));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.groups, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Swarm · ${s.preset}',
                    style: theme.textTheme.titleSmall),
              ),
              _statusChip(s.status, theme),
            ]),
            if (s.totalLayers > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    '${AppLocalizations.of(context)!.swarmLayer} ${s.currentLayer}/${s.totalLayers} · ${s.agents.length} ${AppLocalizations.of(context)!.swarmAgents}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
              ),
            const SizedBox(height: 8),
            for (final a in s.agents)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _AgentCard(agent: a),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status, ThemeData theme) {
    final color = status == 'completed'
        ? Colors.green
        : status == 'failed'
            ? Colors.red
            : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12)),
      child: Text(status,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});
  final SwarmAgentStatus agent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _icon(agent.status),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(agent.role ?? agent.agentId,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                if (agent.tool != null)
                  Text('${agent.tool}'
                      '${agent.elapsedS != null ? " · ${agent.elapsedS}s" : ""}'
                      '${agent.iterations != null ? " · ${agent.iterations} it" : ""}',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
              ],
            ),
          ),
          Text(agent.status.name,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _icon(SwarmAgentDisplayStatus s) {
    switch (s) {
      case SwarmAgentDisplayStatus.running:
        return const SizedBox(
            width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2));
      case SwarmAgentDisplayStatus.done:
        return const Icon(Icons.check_circle, size: 16, color: Colors.green);
      case SwarmAgentDisplayStatus.failed:
        return const Icon(Icons.error, size: 16, color: Colors.red);
      case SwarmAgentDisplayStatus.blocked:
        return const Icon(Icons.block, size: 16, color: Colors.orange);
      default:
        return const Icon(Icons.hourglass_empty, size: 16, color: Colors.grey);
    }
  }
}
