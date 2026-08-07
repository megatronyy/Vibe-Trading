// REST DTOs matching the backend response models exactly (verified against
// agent/src/api/sessions_routes.py / live_routes.py). The in-memory chat
// models live in agent_message.dart.

/// `GET /sessions` → `SessionResponse`: session_id / title / status /
/// created_at / updated_at / last_attempt_id.
class SessionItem {
  SessionItem({
    required this.id,
    required this.title,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
    this.lastAttemptId,
  });

  final String id;
  final String title;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? lastAttemptId;

  factory SessionItem.fromJson(Map<String, dynamic> j) => SessionItem(
        id: (j['session_id'] ?? j['id']) as String,
        title: (j['title'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'active',
        createdAt: _parse(j['created_at']),
        updatedAt: _parse(j['updated_at']),
        lastAttemptId: j['last_attempt_id'] as String?,
      );
}

/// `GET /sessions/{id}/messages` → `MessageResponse`. Assistant replies carry a
/// `metadata` block (`run_id` / `status` / `metrics`) used to render the
/// RunComplete card — there is no separate run_complete event.
class MessageItem {
  const MessageItem({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
    this.linkedAttemptId,
    this.metadata = const {},
  });

  final String id;
  final String role; // user | assistant | system
  final String content;
  final DateTime? createdAt;
  final String? linkedAttemptId;
  final Map<String, dynamic> metadata;

  factory MessageItem.fromJson(Map<String, dynamic> j) => MessageItem(
        id: (j['message_id'] ?? j['id']) as String,
        role: (j['role'] as String?) ?? 'assistant',
        content: (j['content'] as String?) ?? '',
        createdAt: _parse(j['created_at'] ?? j['timestamp']),
        linkedAttemptId: j['linked_attempt_id'] as String?,
        metadata: (j['metadata'] as Map<String, dynamic>?) ?? const {},
      );
}

DateTime? _parse(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    return DateTime.fromMillisecondsSinceEpoch(
        v > 1e12 ? v.toInt() : v.toInt() * 1000);
  }
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class HealthStatus {
  HealthStatus({this.status = 'unknown'});
  final String status;
  factory HealthStatus.fromJson(Map<String, dynamic> j) =>
      HealthStatus(status: (j['status'] as String?) ?? 'unknown');
}

/// `GET /live/status` — matches the backend `LiveStatusResponse` exactly
/// (nested `auth` / `mandate` / `runner` objects per broker).
class LiveStatus {
  LiveStatus({this.globalHalted = false, this.brokers = const []});

  final bool globalHalted;
  final List<LiveBroker> brokers;

  bool get liveActive =>
      globalHalted || brokers.any((b) => b.runner.alive || b.hasMandate);

  factory LiveStatus.fromJson(Map<String, dynamic> j) {
    final list = (j['brokers'] as List?) ?? const [];
    return LiveStatus(
      globalHalted: j['global_halted'] as bool? ?? false,
      brokers: list
          .whereType<Map>()
          .map((e) => LiveBroker.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

class LiveBroker {
  const LiveBroker({required this.auth, required this.runner, this.mandate, this.halted = false});

  final BrokerAuth auth;
  final RunnerLiveness runner;
  final ActiveMandate? mandate;
  final bool halted;

  // Convenience getters (backward-compatible with old flat fields).
  String get broker => auth.broker;
  bool get isAuthorized => auth.oauthTokenPresent;
  bool get isRunnerAlive => runner.alive;
  bool get isSdk => auth.transport == 'broker_sdk';
  bool get hasMandate => mandate != null && !mandate!.expired;

  factory LiveBroker.fromJson(Map<String, dynamic> j) {
    final authMap = j['auth'] is Map ? Map<String, dynamic>.from(j['auth']) : <String, dynamic>{};
    final runnerMap = j['runner'] is Map ? Map<String, dynamic>.from(j['runner']) : <String, dynamic>{};
    final mandateMap = j['mandate'] is Map ? Map<String, dynamic>.from(j['mandate']) : null;
    return LiveBroker(
      auth: BrokerAuth.fromJson(authMap),
      runner: RunnerLiveness.fromJson(runnerMap),
      mandate: mandateMap != null ? ActiveMandate.fromJson(mandateMap) : null,
      halted: j['halted'] as bool? ?? false,
    );
  }
}

/// Per-broker authorization snapshot (`BrokerAuthState` in the backend).
class BrokerAuth {
  const BrokerAuth({
    required this.broker,
    this.oauthTokenPresent = false,
    this.isLiveBroker = false,
    this.transport,
    this.connectionState,
    this.configured,
    this.readonly,
    this.errorCode,
  });

  final String broker;
  final bool oauthTokenPresent;
  final bool isLiveBroker;
  final String? transport; // broker_sdk | remote_mcp | local_tws | null
  final String? connectionState; // connected | not_configured | error | null
  final bool? configured;
  final bool? readonly;
  final String? errorCode;

  factory BrokerAuth.fromJson(Map<String, dynamic> j) => BrokerAuth(
        broker: j['broker'] as String? ?? '',
        oauthTokenPresent: j['oauth_token_present'] as bool? ?? false,
        isLiveBroker: j['is_live_broker'] as bool? ?? false,
        transport: j['transport'] as String?,
        connectionState: j['connection_state'] as String?,
        configured: j['configured'] as bool?,
        readonly: j['readonly'] as bool?,
        errorCode: j['error_code'] as String?,
      );
}

/// Runner liveness snapshot (`RunnerLivenessState` in the backend).
class RunnerLiveness {
  const RunnerLiveness({required this.broker, this.alive = false, this.lastTickAgeSeconds});

  final String broker;
  final bool alive;
  final double? lastTickAgeSeconds;

  factory RunnerLiveness.fromJson(Map<String, dynamic> j) => RunnerLiveness(
        broker: j['broker'] as String? ?? '',
        alive: j['alive'] as bool? ?? false,
        lastTickAgeSeconds: (j['last_tick_age_seconds'] as num?)?.toDouble(),
      );
}

/// Active mandate with expiry + limits (`ActiveMandateState` in the backend).
class ActiveMandate {
  const ActiveMandate({
    required this.broker,
    required this.expiresAt,
    this.expiresInSeconds,
    required this.expired,
    this.limits,
  });

  final String broker;
  final String expiresAt;
  final int? expiresInSeconds;
  final bool expired;
  final MandateLimits? limits;

  factory ActiveMandate.fromJson(Map<String, dynamic> j) {
    final limitsMap = j['limits'] is Map ? Map<String, dynamic>.from(j['limits']) : null;
    return ActiveMandate(
      broker: j['broker'] as String? ?? '',
      expiresAt: j['expires_at'] as String? ?? '',
      expiresInSeconds: (j['expires_in_seconds'] as num?)?.toInt(),
      expired: j['expired'] as bool? ?? false,
      limits: limitsMap != null ? MandateLimits.fromJson(limitsMap) : null,
    );
  }
}

/// Flattened mandate limits (`MandateLimits` in the backend).
class MandateLimits {
  const MandateLimits({
    this.maxOrderNotionalUsd = 0,
    this.maxLeverage = 0,
    this.maxTradesPerDay = 0,
    this.allowedInstruments = const [],
  });

  final double maxOrderNotionalUsd;
  final double maxLeverage;
  final int maxTradesPerDay;
  final List<String> allowedInstruments;

  factory MandateLimits.fromJson(Map<String, dynamic> j) => MandateLimits(
        maxOrderNotionalUsd: (j['max_order_notional_usd'] as num?)?.toDouble() ?? 0,
        maxLeverage: (j['max_leverage'] as num?)?.toDouble() ?? 0,
        maxTradesPerDay: (j['max_trades_per_day'] as num?)?.toInt() ?? 0,
        allowedInstruments: (j['allowed_instruments'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}
