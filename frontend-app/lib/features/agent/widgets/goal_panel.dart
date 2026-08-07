import 'package:flutter/material.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';

import '../../../core/models/goal.dart';

/// Research-goal lifecycle panel (the flagged P1 gap). Shows objective, status,
/// criteria coverage, the criterion list, and evidence count; exposes
/// Continue / Edit-objective / Cancel. Collapses when the goal is terminal.
class GoalPanel extends StatelessWidget {
  const GoalPanel({
    super.key,
    required this.goal,
    required this.onContinue,
    required this.onEditObjective,
    required this.onCancel,
  });

  final GoalSnapshot goal;
  final VoidCallback onContinue;
  final VoidCallback onEditObjective;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: !goal.isTerminal,
          leading: Icon(goal.isTerminal ? Icons.flag : Icons.flag_outlined,
              color: theme.colorScheme.primary),
          title: Text(
            goal.isTerminal
                ? '${AppLocalizations.of(context)!.goal}: ${goal.status}'
                : '${AppLocalizations.of(context)!.goal} · ${goal.coveredCount}/${goal.criteria.length}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            goal.objective.isEmpty
                ? '—'
                : (goal.objective.length > 80
                    ? '${goal.objective.substring(0, 80)}…'
                    : goal.objective),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(goal.objective,
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  if (goal.criteria.isNotEmpty) ...[
                    Text('${AppLocalizations.of(context)!.goalCriteria} (${goal.coveredCount}/${goal.criteria.length})',
                        style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    for (final c in goal.criteria)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            c.covered ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 16,
                            color: c.covered ? Colors.green : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(c.text,
                                style: const TextStyle(fontSize: 13)),
                          ),
                          if (c.evidenceCount > 0)
                            Text('${c.evidenceCount}',
                                style: TextStyle(
                                    fontSize: 11, color: theme.colorScheme.outline)),
                        ],
                      ),
                  ],
                  if (goal.evidenceCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${AppLocalizations.of(context)!.goalEvidence}: ${goal.evidenceCount}',
                          style: TextStyle(
                              fontSize: 12, color: theme.colorScheme.outline)),
                    ),
                  if (!goal.isTerminal)
                    OverflowBar(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                            onPressed: onContinue,
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: Text(AppLocalizations.of(context)!.goalContinue)),
                        TextButton.icon(
                            onPressed: onEditObjective,
                            icon: const Icon(Icons.edit, size: 18),
                            label: Text(AppLocalizations.of(context)!.goalEdit)),
                        TextButton.icon(
                            onPressed: onCancel,
                            icon: const Icon(Icons.cancel_outlined, size: 18),
                            label: Text(AppLocalizations.of(context)!.goalCancel),
                            style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
