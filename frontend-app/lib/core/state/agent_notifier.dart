import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agent_message.dart';
import '../models/goal.dart';
import '../models/models.dart';
import '../net/api.dart';
import '../net/api_client.dart';
import '../net/api_error.dart';
import '../net/sse_client.dart';

enum SseStatus { disconnected, connected, reconnecting }

/// Immutable Agent view-state. Mirrors the React zustand store + the
/// privileged live/goal state that `Agent.tsx` kept in local React state.
class AgentState {
  const AgentState({
    this.sessionId,
    this.messages = const [],
    this.streamingText = '',
    this.streaming = false,
    this.reasoningActive = false,
    this.sseStatus = SseStatus.disconnected,
    this.sessions = const [],
    this.sessionLoading = false,
    this.goal,
    this.liveStatus,
    this.liveActive = false,
    this.swarmRuns = const {},
    this.pendingMandate,
    this.error,
  });

  final String? sessionId;
  final List<AgentMessage> messages;
  final String streamingText;
  final bool streaming;
  final bool reasoningActive;
  final SseStatus sseStatus;
  final List<SessionItem> sessions;
  final bool sessionLoading;
  final GoalSnapshot? goal;
  final LiveStatus? liveStatus;
  final bool liveActive;
  final Map<String, SwarmRunStatus> swarmRuns;
  /// Pending mandate proposal (from `mandate.proposal` SSE) awaiting the
  /// user's biometric-gated commit.
  final Map<String, dynamic>? pendingMandate;
  final String? error;

  bool get isEmpty => messages.isEmpty && streamingText.isEmpty;

  AgentState copyWith({
    String? sessionId,
    List<AgentMessage>? messages,
    String? streamingText,
    bool? streaming,
    bool? reasoningActive,
    SseStatus? sseStatus,
    List<SessionItem>? sessions,
    bool? sessionLoading,
    GoalSnapshot? goal,
    LiveStatus? liveStatus,
    bool? liveActive,
    Map<String, SwarmRunStatus>? swarmRuns,
    Map<String, dynamic>? pendingMandate,
    String? error,
    bool clearError = false,
    bool clearMandate = false,
  }) =>
      AgentState(
        sessionId: sessionId ?? this.sessionId,
        messages: messages ?? this.messages,
        streamingText: streamingText ?? this.streamingText,
        streaming: streaming ?? this.streaming,
        reasoningActive: reasoningActive ?? this.reasoningActive,
        sseStatus: sseStatus ?? this.sseStatus,
        sessions: sessions ?? this.sessions,
        sessionLoading: sessionLoading ?? this.sessionLoading,
        goal: goal ?? this.goal,
        liveStatus: liveStatus ?? this.liveStatus,
        liveActive: liveActive ?? this.liveActive,
        swarmRuns: swarmRuns ?? this.swarmRuns,
        pendingMandate: clearMandate ? null : (pendingMandate ?? this.pendingMandate),
        error: clearError ? null : (error ?? this.error),
      );
}

/// Owns the session, the SSE subscription, and the event→state dispatch (the
/// three-slot separation: timeline messages / privileged live+goal state /
/// coalesced tool progress). The dispatch matches the verified backend contract.
class AgentNotifier extends Notifier<AgentState> {
  SseClient? _sse;
  StreamSubscription<SseEvent>? _sub;
  Timer? _liveTimer;
  // Live tool progress, keyed by tool name within the current attempt.
  final Map<String, ToolCallEntry> _liveTools = {};
  // Streaming timeout removed: sessions may run for a long time on the backend
  // (backtests, swarm). The streaming indicator stays visible until
  // attempt.completed/failed arrives.
  // Dedup flag: attempt.completed and message.received both can deliver the
  // final answer — whichever fires first wins.
  bool _answerFinalized = false;

  @override
  AgentState build() {
    ref.onDispose(_dispose);
    return const AgentState();
  }

  Api get _api => ref.read(apiProvider);
  Dio get _dio => ref.read(dioProvider);

  // --- sessions ----------------------------------------------------------

  Future<void> refreshSessions() async {
    try {
      final sessions = await _api.listSessions();
      state = state.copyWith(sessions: sessions);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  /// Optimistically remove a session from the local list (so the Dismissible
  /// leaves the tree immediately), then delete on the backend and refresh.
  Future<void> deleteSession(String sid) async {
    state = state.copyWith(
      sessions: state.sessions.where((s) => s.id != sid).toList(),
    );
    if (state.sessionId == sid) {
      resetToWelcome();
    }
    try {
      await _api.deleteSession(sid);
    } catch (_) {}
    await refreshSessions();
  }

  /// Rename a session (optimistic local update + backend PATCH).
  Future<void> renameSession(String sid, String title) async {
    state = state.copyWith(
      sessions: state.sessions
          .map((s) => s.id == sid ? SessionItem(id: s.id, title: title, status: s.status, createdAt: s.createdAt, updatedAt: s.updatedAt) : s)
          .toList(),
    );
    try {
      await _api.renameSession(sid, title);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> loadSession(String sid) async {
    _disposeStream();
    state = state.copyWith(
        sessionId: sid, sessionLoading: true, streaming: false, streamingText: '', clearError: true);
    _liveTools.clear();
    try {
      final history = await _api.getSessionMessages(sid);
      final messages = <AgentMessage>[];
      for (final m in history) {
        messages.add(_historyMessage(m, sid));
      }
      final goal = await _safeGetGoal(sid);
      state = state.copyWith(
          messages: messages, sessionLoading: false, goal: goal);
      _subscribe(sid);
      _ensureLivePolling();
    } on ApiException catch (e) {
      state = state.copyWith(sessionLoading: false, error: e.message);
    }
  }

  Future<void> newSession() async {
    try {
      final s = await _api.createSession('New session');
      state = state.copyWith(sessions: [s, ...state.sessions]);
      await loadSession(s.id);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  /// Return to the welcome / examples screen (React parity: a "new chat" just
  /// clears the current conversation; the session is created lazily on the
  /// first send). Keeps the session list + live status; tears down the SSE
  /// stream. No network call, so it lands on the examples page immediately.
  void resetToWelcome() {
    _disposeStream();
    _liveTools.clear();
    state = AgentState(
      sessions: state.sessions,
      liveStatus: state.liveStatus,
      liveActive: state.liveActive,
    );
  }

  Future<void> sendMessage(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;
    // Ensure there's a session to send to. Create one inline if needed — no
    // recursion (the old code recursed and could hang forever if createSession
    // kept failing, e.g. an unreachable backend).
    var sid = state.sessionId;
    if (sid == null) {
      try {
        final s = await _api.createSession('New session');
        sid = s.id;
        state = state.copyWith(sessionId: sid, sessions: [s, ...state.sessions]);
        _subscribe(sid);
        _ensureLivePolling();
      } on ApiException catch (e) {
        state = state.copyWith(error: e.message);
        return; // surface the error; don't hang.
      }
    }
    final userMsg = AgentMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      type: AgentMessageType.user,
      content: text,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      streaming: true,
      streamingText: '',
      reasoningActive: false,
      clearError: true,
    );
    try {
      await _api.sendMessage(sid, text);
      // Auto-title the session (LLM generates a title from the first message).
      unawaited(_api.autoTitleSession(sid).then((_) => refreshSessions()));
    } on ApiException catch (e) {
      state = state.copyWith(streaming: false, error: e.message);
    }
  }

  Future<void> cancelGeneration() async {
    final sid = state.sessionId;
    if (sid == null) return;
    try {
      await _api.cancelSession(sid);
    } catch (_) {}
    state = state.copyWith(streaming: false);
  }

  Future<void> haltLive({String? reason}) async {
    try {
      await _api.haltLive(sessionId: state.sessionId, reason: reason);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
    await pollLiveStatus();
  }

  Future<void> resumeLive() async {
    try {
      await _api.resumeLive(sessionId: state.sessionId);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
    await pollLiveStatus();
  }

  // --- live status polling (15s) -----------------------------------------

  void _ensureLivePolling() {
    _liveTimer ??= Timer.periodic(const Duration(seconds: 15), (_) => pollLiveStatus());
    pollLiveStatus();
  }

  Future<void> pollLiveStatus() async {
    try {
      final ls = await _api.getLiveStatus();
      state = state.copyWith(liveStatus: ls, liveActive: ls.liveActive);
    } on ApiException {
      // Live status is best-effort; don't surface as a hard error.
    }
  }

  /// Public hook for the UI to push a freshly-fetched goal snapshot (after an
  /// edit-objective / cancel-goal action).
  void setGoal(GoalSnapshot g) => state = state.copyWith(goal: g);

  /// Privileged: submit a mandate commit. The caller (MandateProposalCard)
  /// MUST have already obtained biometric confirmation — this sends
  /// `consent_ack: true` and clears the pending proposal on success.
  Future<void> commitMandate(String proposalId, Map<String, dynamic> profile) async {
    try {
      await _api.commitMandate({
        'proposal_id': proposalId,
        'profile': profile,
        'consent_ack': true,
      });
      state = state.copyWith(clearMandate: true);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
    await pollLiveStatus();
  }

  /// Dismiss a pending mandate without committing.
  void dismissMandate() => state = state.copyWith(clearMandate: true);

  // --- SSE subscription + dispatch ---------------------------------------

  void _subscribe(String sid) {
    _disposeStream();
    final url = _api.sessionEventsUrl(sid, replayActive: true);
    _sse = SseClient(dio: _dio, url: url);
    _sub = _sse!.connect().listen(_dispatch, onError: (Object e) {
      state = state.copyWith(sseStatus: SseStatus.reconnecting);
    });
  }

  /// The event→state dispatch. One branch per verified event type.
  void _dispatch(SseEvent ev) {
    if (state.sseStatus != SseStatus.connected) {
      state = state.copyWith(sseStatus: SseStatus.connected);
    }
    // Any event resets the streaming safety timeout (React parity).
    final d = ev.json ?? <String, dynamic>{};
    switch (ev.type) {
      case 'text_delta':
        state = state.copyWith(
            streamingText: state.streamingText + (d['delta'] as String? ?? ''),
            reasoningActive: false);
        break;
      case 'reasoning_delta':
        // Backend sends only a char count, not text.
        state = state.copyWith(reasoningActive: true);
        break;
      case 'thinking_done':
        final content = d['content'] as String?;
        if (content != null && content.isNotEmpty) {
          _addMessage(AgentMessage(
            id: 'thk-${d['iter']}-${DateTime.now().microsecondsSinceEpoch}',
            type: AgentMessageType.thinking,
            content: content,
            stage: 'reasoning',
            status: 'ok',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
        }
        state = state.copyWith(reasoningActive: false);
        break;
      case 'tool_call':
        final tool = d['tool'] as String? ?? 'tool';
        final args = (d['arguments'] as Map?)?.cast<String, String>() ?? {};
        _liveTools[tool] = ToolCallEntry(
          id: tool,
          tool: tool,
          arguments: args,
          status: 'running',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        _addMessage(AgentMessage(
          id: 'tc-$tool-${DateTime.now().microsecondsSinceEpoch}',
          type: AgentMessageType.toolCall,
          content: '',
          tool: tool,
          args: args,
          status: 'running',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
        _flushLiveTools();
        break;
      case 'tool_heartbeat':
        _updateTool(d['tool'] as String?, elapsedS: (d['elapsed_s'] as num?)?.toInt());
        break;
      case 'tool_progress':
        _updateTool(
          d['tool'] as String?,
          progress: ToolProgress(
            stage: d['stage'] as String?,
            current: (d['current'] as num?)?.toInt(),
            total: (d['total'] as num?)?.toInt(),
            message: d['message'] as String?,
          ),
          elapsedS: (d['elapsed_s'] as num?)?.toInt(),
        );
        break;
      case 'tool_result':
        final tool = d['tool'] as String?;
        final status = d['status'] as String? ?? 'ok';
        _liveTools.remove(tool);
        _flushLiveTools();
        _finalizeToolMessage(tool, status, d['preview'] as String?,
            (d['elapsed_ms'] as num?)?.toInt());
        break;
      case 'attempt.created':
        _liveTools.clear();
        _answerFinalized = false;
        break;
      case 'attempt.started':
        break;
      case 'attempt.completed':
      case 'attempt.failed':
        _finishStreaming(
          ok: ev.type == 'attempt.completed',
          summary: d['summary'] as String?,
          error: d['error'] as String?,
          runDir: d['run_dir'] as String?,
        );
        // run_dir present ⇒ the assistant message now carries run metadata;
        // fetch it to attach the run-complete card.
        if (ev.type == 'attempt.completed' && (d['run_dir'] as String?) != null) {
          _maybeAttachRunCard();
        }
        break;
      case 'message.received':
        _onMessageReceived(d);
        break;
      case 'session.created':
        // A new session for this user; refresh the list lazily.
        refreshSessions();
        break;
      case 'compact':
        _addMessage(AgentMessage(
          id: 'cmp-${DateTime.now().microsecondsSinceEpoch}',
          type: AgentMessageType.compact,
          content: d['summary'] as String? ?? '',
          stage: 'compact',
          status: 'ok',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
        break;
      case 'stream_reset':
      case 'llm_usage':
      case 'heartbeat':
      case 'mcp.warning':
        // No UI state change required.
        break;
      case 'goal.created':
      case 'goal.updated':
        final snap = d['snapshot'] as Map<String, dynamic>? ??
            (d['goal'] != null ? <String, dynamic>{'goal': d['goal']} : null);
        if (snap != null) {
          state = state.copyWith(goal: GoalSnapshot.fromJson(snap));
        }
        break;
      case 'goal.evidence':
        // Re-fetch the snapshot to get updated evidence/criteria counts.
        if (state.sessionId != null) {
          _safeGetGoal(state.sessionId).then((g) {
            if (g != null) state = state.copyWith(goal: g);
          });
        }
        break;
      case 'swarm.started':
      case 'swarm.event':
        _applySwarmEvent(ev.type, d);
        break;
      case 'mandate.proposal':
        state = state.copyWith(pendingMandate: d);
        break;
      case 'mandate.committed':
        state = state.copyWith(clearMandate: true);
        pollLiveStatus();
        break;
      case 'live.action':
        // Inline live-action chip in the timeline (order_rejected / breach /
        // halt_tripped / mandate_committed / halt_cleared / …).
        _addMessage(AgentMessage(
          id: 'la-${DateTime.now().microsecondsSinceEpoch}',
          type: AgentMessageType.liveAction,
          content: '',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          liveAction: d,
        ));
        if ((d['kind'] as String?) == 'halt_tripped') {
          state = state.copyWith(liveActive: true);
        }
        pollLiveStatus();
        break;
      case 'live.halted':
      case 'live.resumed':
        // Privileged surface — refresh live status so kill switch / badges
        // reflect reality. Mandate proposal/committed handled above.
        pollLiveStatus();
        break;
      default:
        break;
    }
  }

  // --- dispatch helpers --------------------------------------------------

  void _addMessage(AgentMessage m) {
    state = state.copyWith(messages: [...state.messages, m]);
  }

  void _updateTool(String? tool,
      {ToolProgress? progress, int? elapsedS}) {
    if (tool == null) return;
    final cur = _liveTools[tool];
    if (cur == null) return;
    _liveTools[tool] = cur.copyWith(progress: progress, elapsedS: elapsedS);
    _flushLiveTools();
  }

  /// Surface live tool progress as a synthetic trailing "running tools"
  /// message so the timeline shows rings while tools execute. We keep this
  /// separate from finalized tool_call messages.
  void _flushLiveTools() {
    // Tool progress is read by the UI via a dedicated provider (see below) to
    // avoid rebuilding the whole message list on every progress tick.
    _liveToolsController.add(Map.unmodifiable(_liveTools));
  }

  void _finalizeToolMessage(String? tool, String status, String? preview, int? elapsedMs) {
    final messages = [...state.messages];
    // Find the last tool_call for this tool still marked running.
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.type == AgentMessageType.toolCall &&
          m.tool == tool &&
          m.status == 'running') {
        messages[i] = AgentMessage(
          id: m.id,
          type: AgentMessageType.toolResult,
          content: preview ?? '',
          tool: tool,
          args: m.args,
          status: status,
          elapsedMs: elapsedMs,
          timestamp: m.timestamp,
        );
        break;
      }
    }
    state = state.copyWith(messages: messages);
  }

  void _finishStreaming({
    required bool ok,
    String? summary,
    String? error,
    String? runDir,
  }) {
    // On success, finalize the streamed text (or the summary) as the assistant
    // answer — React parity: attempt.completed itself adds the final answer.
    if (ok && !_answerFinalized) {
      _answerFinalized = true;
      final text = state.streamingText.isNotEmpty
          ? state.streamingText
          : (summary ?? '');
      if (text.isNotEmpty) {
        _addMessage(AgentMessage(
          id: 'ans-${DateTime.now().microsecondsSinceEpoch}',
          type: AgentMessageType.answer,
          content: text,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }
    state = state.copyWith(
      streaming: false,
      reasoningActive: false,
      streamingText: '',
    );
    if (!ok && error != null && error.isNotEmpty) {
      _addMessage(AgentMessage(
        id: 'err-${DateTime.now().microsecondsSinceEpoch}',
        type: AgentMessageType.error,
        content: error,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void _onMessageReceived(Map<String, dynamic> d) {
    final role = d['role'] as String? ?? 'assistant';
    final content = d['content'] as String? ?? '';
    if (role != 'assistant') return;
    if (content.isEmpty) return;
    if (_answerFinalized) return; // already added by attempt.completed
    _answerFinalized = true;
    _addMessage(AgentMessage(
      id: (d['message_id'] as String?) ??
          'ans-${DateTime.now().microsecondsSinceEpoch}',
      type: AgentMessageType.answer,
      content: content,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    state = state.copyWith(streamingText: '', streaming: false);
  }

  Future<void> _maybeAttachRunCard() async {
    final sid = state.sessionId;
    if (sid == null) return;
    try {
      final history = await _api.getSessionMessages(sid);
      final last = history.lastWhere(
        (m) => m.role == 'assistant' && m.metadata['run_id'] != null,
        orElse: () => const MessageItem(
            id: '', role: 'assistant', content: ''),
      );
      if (last.id.isEmpty) return;
      final meta = last.metadata;
      final metrics = (meta['metrics'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      // Only show a "Backtest complete" card when the run actually has
      // backtest metrics — a pure research/analysis run (no metrics.csv)
      // should NOT get this card.
      if (metrics == null || metrics.isEmpty) return;
      _addMessage(AgentMessage(
        id: 'rc-${last.id}',
        type: AgentMessageType.runComplete,
        content: (meta['status'] as String?) ?? 'completed',
        runId: meta['run_id'] as String?,
        metrics: metrics,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    } on ApiException {
      // best-effort
    }
  }

  AgentMessage _historyMessage(MessageItem m, String sid) {
    final meta = m.metadata;
    if (m.role == 'user') {
      return AgentMessage(
        id: m.id, type: AgentMessageType.user, content: m.content,
        timestamp: m.createdAt?.millisecondsSinceEpoch ?? 0,
      );
    }
    if (m.role == 'assistant' && meta['run_id'] != null &&
        meta['metrics'] is Map && (meta['metrics'] as Map).isNotEmpty) {
      final metrics = (meta['metrics'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      return AgentMessage(
        id: m.id, type: AgentMessageType.runComplete,
        content: m.content.isNotEmpty
            ? m.content
            : (meta['status'] as String? ?? 'completed'),
        runId: meta['run_id'] as String?, metrics: metrics,
        timestamp: m.createdAt?.millisecondsSinceEpoch ?? 0,
      );
    }
    return AgentMessage(
      id: m.id, type: AgentMessageType.answer, content: m.content,
      timestamp: m.createdAt?.millisecondsSinceEpoch ?? 0,
    );
  }

  Future<GoalSnapshot?> _safeGetGoal(String? sid) async {
    if (sid == null) return null;
    try {
      return await _api.getGoal(sid);
    } on ApiException {
      return null;
    }
  }

  void _applySwarmEvent(String type, Map<String, dynamic> d) {
    // Session-stream swarm events (swarm.started/swarm.event). The dedicated
    // /swarm/runs stream uses different types (run_started/task_started/…)
    // and is handled in P3/P4 if a standalone swarm monitor is added.
    final runId = d['run_id'] as String? ?? d['runId'] as String?;
    if (runId == null) return;
    final existing = state.swarmRuns[runId];
    final preset = d['preset'] as String? ?? existing?.preset ?? 'swarm';
    final agents = (d['agents'] as List?)
            ?.cast<Map<String, dynamic>>()
            .map((j) => SwarmAgentStatus(
                  agentId: (j['agent_id'] as String?) ?? (j['agentId'] as String?) ?? '',
                  role: j['role'] as String?,
                  status: SwarmAgentDisplayStatus.fromString(
                      j['status'] as String?),
                  tool: j['tool'] as String?,
                  elapsedS: (j['elapsed_s'] as num?)?.toInt(),
                  iterations: (j['iterations'] as num?)?.toInt(),
                  layer: (j['layer'] as num?)?.toInt(),
                  lastText: j['last_text'] as String? ?? j['lastText'] as String?,
                ))
            .toList() ??
        existing?.agents ??
        const [];
    final updated = SwarmRunStatus(
      runId: runId,
      preset: preset,
      status: d['status'] as String? ?? existing?.status ?? 'running',
      currentLayer: (d['current_layer'] as num?)?.toInt() ?? existing?.currentLayer ?? 0,
      totalLayers: (d['total_layers'] as num?)?.toInt() ?? existing?.totalLayers ?? 0,
      startedAt: (d['started_at'] as num?)?.toInt() ?? existing?.startedAt ?? DateTime.now().millisecondsSinceEpoch,
      agents: agents,
    );
    final runs = Map<String, SwarmRunStatus>.from(state.swarmRuns)..[runId] = updated;
    state = state.copyWith(swarmRuns: runs);
    // Ensure a swarm_status card is in the timeline.
    final hasCard = state.messages.any((m) =>
        m.type == AgentMessageType.swarmStatus && m.swarmRunId == runId);
    if (!hasCard) {
      _addMessage(AgentMessage(
        id: 'swarm-$runId',
        type: AgentMessageType.swarmStatus,
        content: '',
        swarmRunId: runId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    } else {
      final messages = state.messages.map((m) {
        if (m.type == AgentMessageType.swarmStatus && m.swarmRunId == runId) {
          return AgentMessage(
            id: m.id, type: m.type, content: '',
            timestamp: m.timestamp, swarmRunId: runId, swarmStatus: updated,
          );
        }
        return m;
      }).toList();
      state = state.copyWith(messages: messages);
    }
  }

  // --- teardown ----------------------------------------------------------

  void _disposeStream() {
    _sub?.cancel();
    _sub = null;
    _sse?.dispose();
    _sse = null;
  }

  void _dispose() {
    _disposeStream();
    _liveTimer?.cancel();
    _liveTimer = null;
    _liveToolsController.close();
  }

  /// Broadcast stream of live tool progress (coalesced). The UI listens to
  /// avoid rebuilding the whole message list on every tool_progress tick.
  final StreamController<Map<String, ToolCallEntry>> _liveToolsController =
      StreamController<Map<String, ToolCallEntry>>.broadcast();
}

final agentProvider =
    NotifierProvider<AgentNotifier, AgentState>(AgentNotifier.new);

/// Live tool-progress stream (coalesced per tick), read by the composer-area
/// progress strip.
final liveToolsProvider = StreamProvider<Map<String, ToolCallEntry>>((ref) {
  final notifier = ref.watch(agentProvider.notifier);
  return notifier._liveToolsController.stream;
});
