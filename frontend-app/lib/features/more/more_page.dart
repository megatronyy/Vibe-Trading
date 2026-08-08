import 'package:flutter/material.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/auth_provider.dart';

/// "More" tab — secondary destinations that don't fit the 4 main bottom-nav
/// slots: live runtime monitor, correlation matrix, run compare. These push
/// full-screen above the shell. P1 adds a profile header (个人资料) showing
/// the logged-in user with a logout affordance.
class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);
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
          ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.person),
            ),
            title: Text(auth.userName?.isNotEmpty == true
                ? auth.userName!
                : '未登录'),
            subtitle: Text(auth.role ?? '点击查看个人资料'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showProfileDialog(context, ref),
          ),
          const Divider(height: 1),
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

  void _showProfileDialog(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider);
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('个人资料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row(scheme.onSurface, '用户名', auth.userName ?? '-'),
            const SizedBox(height: 8),
            _row(scheme.onSurface, '角色', auth.role ?? '-'),
            const SizedBox(height: 8),
            _row(scheme.onSurface, '用户ID', auth.userId ?? '-'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }

  Widget _row(Color color, String label, String value) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: color),
        children: [
          TextSpan(
              text: '$label：',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value),
        ],
      ),
    );
  }
}
