// Regression tests for the fixes applied to the agent state layer:
// - AgentState.copyWith explicit clear flags (session-switch residue bug)
// - ApiException.fromDio auth-error normalization
// No platform channels needed — pure Dart.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_app/core/models/agent_message.dart';
import 'package:frontend_app/core/models/goal.dart';
import 'package:frontend_app/core/net/api_error.dart';
import 'package:frontend_app/core/state/agent_notifier.dart';

void main() {
  group('AgentState.copyWith clear semantics', () {
    test('clearGoal/clearSwarmRuns/clearMandate null the fields out', () {
      final s = const AgentState().copyWith(
        goal: GoalSnapshot(objective: 'obj', status: 'active'),
        swarmRuns: {'r1': SwarmRunStatus(runId: 'r1', preset: 'p', status: 'running', currentLayer: 0, totalLayers: 1, startedAt: 0, agents: [])},
        pendingMandate: {'proposal_id': 'p1'},
        error: 'boom',
      );
      // Sanity: without the flags the values persist (old behavior).
      expect(s.goal, isNotNull);
      expect(s.swarmRuns, isNotEmpty);
      expect(s.pendingMandate, isNotNull);

      final cleared = s.copyWith(
        clearGoal: true,
        clearSwarmRuns: true,
        clearMandate: true,
        clearError: true,
      );
      expect(cleared.goal, isNull, reason: 'goal must be clearable');
      expect(cleared.swarmRuns, isEmpty, reason: 'swarmRuns must be clearable');
      expect(cleared.pendingMandate, isNull, reason: 'pendingMandate must be clearable');
      expect(cleared.error, isNull);
    });

    test('a null goal passed without clearGoal keeps the previous goal', () {
      final goal = GoalSnapshot(objective: 'obj', status: 'active');
      final s = const AgentState().copyWith(goal: goal);
      final next = s.copyWith(goal: null);
      expect(next.goal, same(goal));
    });
  });

  group('ApiException.fromDio', () {
    RequestOptions options(String path) =>
        RequestOptions(path: path, baseUrl: 'http://localhost:8899');

    test('401/403 map to an auth-required ApiException', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: options('/sessions'),
        response: Response(
          requestOptions: options('/sessions'),
          statusCode: 401,
          data: {'detail': 'bad token'},
        ),
      ));
      expect(e.isAuthRequired, isTrue);
      expect(e.status, 401);
    });

    test('transport failures (no response) stay status 0', () {
      final e = ApiException.fromDio(DioException(
        requestOptions: options('/runs'),
        type: DioExceptionType.connectionTimeout,
      ));
      expect(e.status, 0);
      expect(e.isAuthRequired, isFalse);
      expect(e.message, 'Request timed out');
    });
  });
}
