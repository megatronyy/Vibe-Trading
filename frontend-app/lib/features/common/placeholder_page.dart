import 'package:flutter/material.dart';

/// Lightweight stand-in for a page whose full implementation lands in a later
/// phase (P2 reports/run-detail, P3 alpha/correlation, P4 runtime). Keeps the
/// navigation graph complete so deep links and the bottom-nav wiring are
/// testable end-to-end now.
class PhasePlaceholderPage extends StatelessWidget {
  const PhasePlaceholderPage({
    super.key,
    required this.title,
    required this.phase,
    this.hint,
  });

  final String title;
  final String phase;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.construction_outlined, size: 48,
                  color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Built in $phase.',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              if (hint != null) ...[
                const SizedBox(height: 12),
                Text(hint!, textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
