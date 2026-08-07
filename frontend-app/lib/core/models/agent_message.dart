/// Port of `frontend/src/types/agent.ts` — the in-memory message/tool/swarm
/// models that the chat timeline renders. These are NOT the raw SSE payloads
/// (those are parsed in the dispatch layer); they are the normalized shape the
/// UI reads, identical to the React store's `AgentMessage`/`ToolCallEntry`.
library;


enum AgentMessageType {
  user,
  thinking,
  toolCall,
  toolResult,
  answer,
  error,
  runComplete,
  compact,
  swarmStatus,
  liveAction;

  static AgentMessageType fromString(String? s) {
    switch (s) {
      case 'user':
        return AgentMessageType.user;
      case 'thinking':
        return AgentMessageType.thinking;
      case 'tool_call':
        return AgentMessageType.toolCall;
      case 'tool_result':
        return AgentMessageType.toolResult;
      case 'answer':
        return AgentMessageType.answer;
      case 'error':
        return AgentMessageType.error;
      case 'run_complete':
        return AgentMessageType.runComplete;
      case 'compact':
        return AgentMessageType.compact;
      case 'swarm_status':
        return AgentMessageType.swarmStatus;
      default:
        return AgentMessageType.answer;
    }
  }
}

/// Structured progress emitted by a running tool. `current`/`total` present and
/// `total > 0` ⇒ determinate (show a ring); else indeterminate (spinner).
class ToolProgress {
  const ToolProgress({this.stage, this.current, this.total, this.message});

  final String? stage;
  final int? current;
  final int? total;
  final String? message;

  bool get isDeterminate => current != null && total != null && total! > 0;
  double? get ratio => isDeterminate ? (current! / total!).clamp(0.0, 1.0) : null;

  ToolProgress copyWith({String? stage, int? current, int? total, String? message}) =>
      ToolProgress(
        stage: stage ?? this.stage,
        current: current ?? this.current,
        total: total ?? this.total,
        message: message ?? this.message,
      );
}

/// A tracked tool invocation (live during streaming, finalized on tool_result).
class ToolCallEntry {
  ToolCallEntry({
    required this.id,
    required this.tool,
    required this.arguments,
    required this.status,
    required this.timestamp,
    this.preview,
    this.elapsedMs,
    this.elapsedS,
    this.progress,
  });

  final String id;
  final String tool;
  final Map<String, String> arguments;
  final String status; // 'running' | 'ok' | 'error'
  final int timestamp;
  final String? preview;
  final int? elapsedMs;
  final int? elapsedS;
  final ToolProgress? progress;

  bool get isRunning => status == 'running';

  ToolCallEntry copyWith({
    String? status,
    String? preview,
    int? elapsedMs,
    int? elapsedS,
    ToolProgress? progress,
  }) =>
      ToolCallEntry(
        id: id,
        tool: tool,
        arguments: arguments,
        status: status ?? this.status,
        timestamp: timestamp,
        preview: preview ?? this.preview,
        elapsedMs: elapsedMs ?? this.elapsedMs,
        elapsedS: elapsedS ?? this.elapsedS,
        progress: progress ?? this.progress,
      );
}

enum SwarmAgentDisplayStatus {
  waiting, running, done, failed, blocked, retry, cancelled;

  static SwarmAgentDisplayStatus fromString(String? s) {
    switch (s) {
      case 'waiting':
        return SwarmAgentDisplayStatus.waiting;
      case 'running':
        return SwarmAgentDisplayStatus.running;
      case 'done':
        return SwarmAgentDisplayStatus.done;
      case 'failed':
        return SwarmAgentDisplayStatus.failed;
      case 'blocked':
        return SwarmAgentDisplayStatus.blocked;
      case 'retry':
        return SwarmAgentDisplayStatus.retry;
      case 'cancelled':
        return SwarmAgentDisplayStatus.cancelled;
      default:
        return SwarmAgentDisplayStatus.waiting;
    }
  }
}

class SwarmAgentStatus {
  const SwarmAgentStatus({
    required this.agentId,
    required this.status,
    this.taskId,
    this.role,
    this.tool,
    this.elapsedS,
    this.iterations,
    this.startedAt,
    this.lastText,
    this.error,
    this.layer,
  });

  final String agentId;
  final String? taskId;
  final String? role;
  final SwarmAgentDisplayStatus status;
  final String? tool;
  final int? elapsedS;
  final int? iterations;
  final int? startedAt;
  final String? lastText;
  final String? error;
  final int? layer;
}

class SwarmRunStatus {
  SwarmRunStatus({
    required this.runId,
    required this.preset,
    required this.status,
    required this.currentLayer,
    required this.totalLayers,
    required this.startedAt,
    required this.agents,
    this.completedAt,
  });

  final String runId;
  final String preset;
  final String status; // pending|running|completed|failed|cancelled|unknown
  final int currentLayer;
  final int totalLayers;
  final int startedAt;
  final int? completedAt;
  final List<SwarmAgentStatus> agents;
}

class EquityPoint {
  const EquityPoint({required this.time, required this.equity});
  final String time;
  final double equity;
}

/// A single chat timeline entry — user message, assistant answer, a folded
/// thinking/tool step, a run-complete card, or a swarm status card.
class AgentMessage {
  AgentMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.tool,
    this.args,
    this.status,
    this.elapsedMs,
    this.runId,
    this.swarmRunId,
    this.swarmStatus,
    this.metrics,
    this.equityCurve,
    this.stage,
    this.shadowId,
    this.liveAction,
  });

  final String id;
  final AgentMessageType type;
  final String content;
  final int timestamp;
  final String? tool;
  final Map<String, String>? args;
  final String? status; // running|ok|error (for tool/thinking entries)
  final int? elapsedMs;
  final String? runId;
  final String? swarmRunId;
  final SwarmRunStatus? swarmStatus;
  final Map<String, double>? metrics;
  final List<EquityPoint>? equityCurve;
  final String? stage;
  final String? shadowId;
  /// For `liveAction` messages: the raw `live.action` payload
  /// ({kind, intent_normalized, outcome, remote_tool, error, ...}).
  final Map<String, dynamic>? liveAction;
}
