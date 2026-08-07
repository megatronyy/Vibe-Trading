/// `GET /sessions/{id}/goal` snapshot — `{goal, claims, criteria, evidence,
/// evidence_count}`. Field names within `goal` / `criteria` / `evidence` are
/// parsed defensively; the React frontend's `GoalSnapshot` type is the shape
/// this mirrors. Exact sub-field spelling for criteria/evidence should be
/// confirmed against `src/goal/` if the panel shows gaps.
class GoalSnapshot {
  GoalSnapshot({
    this.goalId,
    required this.objective,
    required this.status,
    this.criteria = const [],
    this.evidenceCount = 0,
    this.recentEvidence = const [],
  });

  final String? goalId;
  final String objective;
  final String status; // active | complete | cancelled | blocked | superseded | usage_limited
  final List<GoalCriterion> criteria;
  final int evidenceCount;
  final List<GoalEvidence> recentEvidence;

  static const _terminal = {
    'complete', 'cancelled', 'blocked', 'superseded', 'usage_limited'
  };

  bool get isTerminal => _terminal.contains(status);
  int get coveredCount => criteria.where((c) => c.covered).length;

  factory GoalSnapshot.fromJson(Map<String, dynamic> j) {
    final goal = (j['goal'] as Map<String, dynamic>?) ?? const {};
    final criteria = (j['criteria'] as List?) ?? const [];
    final evidence = (j['evidence'] as List?) ?? const [];
    return GoalSnapshot(
      goalId: goal['id'] as String?,
      objective: (goal['objective'] as String?) ?? '',
      status: (goal['status'] as String?) ?? 'active',
      criteria:
          criteria.cast<Map<String, dynamic>>().map(GoalCriterion.fromJson).toList(),
      evidenceCount: (j['evidence_count'] as num?)?.toInt() ?? evidence.length,
      recentEvidence:
          evidence.cast<Map<String, dynamic>>().map(GoalEvidence.fromJson).toList(),
    );
  }
}

class GoalCriterion {
  const GoalCriterion({
    required this.id,
    required this.text,
    required this.covered,
    required this.evidenceCount,
  });

  final String id;
  final String text;
  final bool covered;
  final int evidenceCount;

  factory GoalCriterion.fromJson(Map<String, dynamic> j) => GoalCriterion(
        id: (j['id'] as String?) ?? (j['criterion_id'] as String?) ?? '',
        text: (j['text'] as String?) ?? (j['description'] as String?) ?? '',
        covered: j['covered'] as bool? ??
            ((j['status'] as String?) == 'met'),
        evidenceCount: (j['evidence_count'] as num?)?.toInt() ?? 0,
      );
}

class GoalEvidence {
  const GoalEvidence({this.source, this.status, required this.text});

  final String? source;
  final String? status;
  final String text;

  factory GoalEvidence.fromJson(Map<String, dynamic> j) => GoalEvidence(
        source: (j['source_provider'] as String?) ?? (j['source'] as String?),
        status: (j['verification_status'] as String?) ?? (j['status'] as String?),
        text: (j['text'] as String?) ?? (j['content'] as String?) ?? '',
      );
}
