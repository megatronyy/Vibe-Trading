import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/agent/agent_page.dart';
import '../features/alpha/alpha_bench_page.dart';
import '../features/alpha/alpha_compare_page.dart';
import '../features/alpha/alpha_detail_page.dart';
import '../features/alpha/alpha_page.dart';
import '../features/compare/compare_page.dart';
import '../features/correlation/correlation_page.dart';
import '../features/more/more_page.dart';
import '../features/reports/reports_page.dart';
import '../features/run_detail/run_detail_page.dart';
import '../features/scheduled/scheduled_page.dart';
import '../features/runtime/runtime_page.dart';
import '../features/settings/settings_page.dart';
import '../features/shadow/shadow_report_page.dart';
import '../features/shell/shell_page.dart';

/// go_router with a [StatefulShellRoute.indexedStack] bottom-nav shell. The 5
/// primary tabs preserve their own state; secondary destinations
/// (RunDetail/Compare/Correlation/Runtime) are pushed full-screen above the
/// shell. Mirrors the React routes in `frontend/src/router.tsx`.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/agent',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellPage(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
              routes: [GoRoute(path: '/agent', builder: (_, _) => const AgentPage())]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/reports', builder: (_, _) => const ReportsPage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/alpha-zoo', builder: (_, _) => const AlphaPage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage())
          ]),
          StatefulShellBranch(
              routes: [GoRoute(path: '/more', builder: (_, _) => const MorePage())]),
        ],
      ),
      // Full-screen, above the shell:
      GoRoute(path: '/runtime', builder: (_, _) => const RuntimePage()),
      GoRoute(
          path: '/shadow-reports/:id',
          builder: (context, state) =>
              ShadowReportPage(shadowId: state.pathParameters['id']!)),
      GoRoute(path: '/correlation', builder: (_, _) => const CorrelationPage()),
      GoRoute(path: '/compare', builder: (_, _) => const ComparePage()),
      GoRoute(path: '/scheduled', builder: (_, _) => const ScheduledPage()),
      GoRoute(
          path: '/runs/:runId',
          builder: (context, state) =>
              RunDetailPage(runId: state.pathParameters['runId']!)),
      // Alpha Zoo sub-views (static paths before the :alphaId param).
      GoRoute(path: '/alpha-zoo/bench', builder: (_, _) => const AlphaBenchPage()),
      GoRoute(path: '/alpha-zoo/compare', builder: (_, _) => const AlphaComparePage()),
      GoRoute(
          path: '/alpha-zoo/:alphaId',
          builder: (context, state) =>
              AlphaDetailPage(alphaId: state.pathParameters['alphaId']!)),
    ],
  );
});
