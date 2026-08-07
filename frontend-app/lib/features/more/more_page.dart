import 'package:flutter/material.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:go_router/go_router.dart';

/// "More" tab — secondary destinations that don't fit the 4 main bottom-nav
/// slots: live runtime monitor, correlation matrix, run compare. These push
/// full-screen above the shell.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries = <(IconData, String, String)>[
      (Icons.monitor_heart_outlined, l.runtimeTitle, '/runtime'),
      (Icons.grid_on_outlined, l.correlationTitle, '/correlation'),
      (Icons.compare_arrows, l.compareTitle, '/compare'),
      (Icons.schedule_outlined, '定时研究', '/scheduled'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.moreTitle)),
      body: ListView(
        children: [
          for (final (icon, label, route) in entries)
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(route),
            ),
        ],
      ),
    );
  }
}
