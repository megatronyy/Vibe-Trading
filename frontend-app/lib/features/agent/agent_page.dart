import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../core/util/share_file.dart';

import '../../core/config/app_config.dart';
import '../../core/util/markdown_content.dart';
import '../../core/state/auth_provider.dart';
import '../../core/models/agent_message.dart';
import '../../core/net/api.dart';
import '../../core/net/api_error.dart';
import '../../core/state/agent_notifier.dart';
import 'widgets/composer.dart';
import 'widgets/goal_panel.dart';
import 'widgets/live_action_chip.dart';
import 'widgets/mandate_proposal_card.dart';
import 'widgets/message_bubble.dart';
import 'widgets/run_complete_card.dart';
import 'widgets/swarm_status_card.dart';
import 'widgets/thinking_timeline.dart';
import 'widgets/tool_progress_indicator.dart';
import 'widgets/welcome_screen.dart';

/// The Agent chat workspace — the primary screen. Wires the [AgentNotifier]
/// state to a virtualized timeline, streaming preview, goal panel, live tool
/// progress, composer, and session switcher.
class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});

  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends ConsumerState<AgentPage> {
  final _scroll = ScrollController();
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  bool _nearBottom = true;
  // Trailing-edge throttle for streaming auto-scroll: one animateTo per tick
  // instead of one per text_delta token.
  Timer? _jumpTimer;
  bool _jumpScheduled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final near = _scroll.position.pixels >=
          _scroll.position.maxScrollExtent - 120;
      if (near != _nearBottom) setState(() => _nearBottom = near);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    // Don't fetch anything if not logged in — the router redirect should have
    // sent us to /login, but IndexedStack may pre-build this page.
    final auth = ref.read(authProvider);
    if (!auth.isLoggedIn) return;

    final notifier = ref.read(agentProvider.notifier);
    await notifier.refreshSessions();
    notifier.pollLiveStatus();
    final sessions = ref.read(agentProvider).sessions;
    if (sessions.isNotEmpty && ref.read(agentProvider).sessionId == null) {
      notifier.loadSession(sessions.first.id);
    }
  }

  @override
  void dispose() {
    _jumpTimer?.cancel();
    _scroll.dispose();
    _inputCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  /// Coalesce streaming auto-scrolls to ~4/s; the last delta in the window
  /// still lands at the bottom.
  void _scheduleJump() {
    if (_jumpScheduled) return;
    _jumpScheduled = true;
    _jumpTimer = Timer(const Duration(milliseconds: 250), () {
      _jumpScheduled = false;
      if (mounted && _nearBottom) _jumpToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Fine-grained subscriptions: a text_delta only changes `streamingText`,
    // which is watched exclusively by the trailing _TrailingStreamSlot — so a
    // streaming token rebuilds one bubble, not the AppBar / goal panel /
    // composer / entire history.
    final messages = ref.watch(agentProvider.select((s) => s.messages));
    final swarmRuns = ref.watch(agentProvider.select((s) => s.swarmRuns));
    final goal = ref.watch(agentProvider.select((s) => s.goal));
    final streaming = ref.watch(agentProvider.select((s) => s.streaming));
    final liveActive = ref.watch(agentProvider.select((s) => s.liveActive));
    final sseStatus = ref.watch(agentProvider.select((s) => s.sseStatus));
    final timelineEmpty = ref.watch(
        agentProvider.select((s) => s.messages.isEmpty && s.streamingText.isEmpty));
    final hasTrailing = ref.watch(agentProvider.select((s) =>
        s.streamingText.isNotEmpty ||
        (s.reasoningActive && s.streamingText.isEmpty)));
    final cfg = ref.watch(appConfigProvider);
    ref.listen<AgentState>(agentProvider, (prev, next) {
      final grew = prev == null ||
          next.messages.length != prev.messages.length ||
          next.streamingText != prev.streamingText;
      if (grew) _scheduleJump();
      // Surface a mandate proposal as a biometric-gated full-screen sheet.
      if (prev?.pendingMandate == null && next.pendingMandate != null) {
        showMandateProposalSheet(context, ref, next.pendingMandate!);
      }
      // Surface backend/network errors so a failed action doesn't look like
      // "tap did nothing". Auth errors get a shortcut to Settings.
      if (next.error != null && next.error != prev?.error) {
        final isAuth = next.error!.startsWith('Authentication required');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.error!),
          action: isAuth
              ? SnackBarAction(
                  label: AppLocalizations.of(context)!.openSettings,
                  onPressed: () => context.go('/settings'),
                )
              : null,
        ));
      }
      // Connection transition toasts (React parity).
      if (prev?.sseStatus != next.sseStatus) {
        if (prev?.sseStatus == SseStatus.connected &&
            next.sseStatus == SseStatus.reconnecting) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.connLost)));
        } else if (prev?.sseStatus == SseStatus.reconnecting &&
            next.sseStatus == SseStatus.connected) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.connRestored)));
        }
      }
    });
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.list),
          tooltip: AppLocalizations.of(context)!.sessions,
          onPressed: () => _showSessions(context),
        ),
        title: Text(AppLocalizations.of(context)!.agentTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: AppLocalizations.of(context)!.newSession,
            onPressed: () => ref.read(agentProvider.notifier).resetToWelcome(),
          ),
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: AppLocalizations.of(context)!.exportChat,
              onPressed: _exportChat,
            ),
          if (streaming)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _Dot(status: sseStatus)),
          ),
        ],
      ),
      body: !cfg.isConfigured
          ? _unconfigured(context)
          : Column(
              children: [
                Expanded(
                  // React parity: the welcome / examples screen is the empty
                  // state (no messages yet), shown for a brand-new or cleared
                  // session — not only when there's no session at all.
                  child: timelineEmpty
                      ? WelcomeScreen(onPick: _pickExample)
                      : _timeline(context, messages, swarmRuns, hasTrailing),
                ),
                // Hide the goal sheet while the soft keyboard is up — it
                // reappears when the keyboard drops. A pinned panel plus
                // keyboard plus composer can exceed the shrunken body and
                // overflow the column; giving the keyboard its space back
                // guarantees the fixed bottom section always fits.
                if (goal != null &&
                    MediaQuery.viewInsetsOf(context).bottom == 0)
                  GoalPanel(
                    goal: goal,
                    onContinue: () =>
                        _send(AppLocalizations.of(context)!.promptContinueGoal),
                    onEditObjective: _editObjective,
                    onCancel: _cancelGoal,
                  ),
                _liveToolsStrip(),
                if (streaming) _streamingPulseBar(context),
                Composer(
                  controller: _inputCtrl,
                  onSend: _send,
                  onMenuUpload: _uploadFile,
                  onMenuGoal: () =>
                    _send(AppLocalizations.of(context)!.promptDefineGoal),
                  onMenuSwarm: () =>
                      _send(AppLocalizations.of(context)!.promptSwarmTeam),
                  onMenuConnector: () =>
                      _send(AppLocalizations.of(context)!.promptCheckConnector),
                  isStreaming: streaming,
                  onStop: () => ref.read(agentProvider.notifier).cancelGeneration(),
                  onHalt: () => ref.read(agentProvider.notifier).haltLive(),
                  liveActive: liveActive,
                ),
              ],
            ),
    );
  }

  /// Group consecutive folded (thinking/tool/compact) messages. Pure data —
  /// cheap to recompute on message-list changes, no widget building here.
  static bool _isFolded(AgentMessageType t) =>
      t == AgentMessageType.thinking ||
      t == AgentMessageType.toolCall ||
      t == AgentMessageType.toolResult ||
      t == AgentMessageType.compact;

  List<Object> _groupEntries(List<AgentMessage> msgs) {
    final entries = <Object>[]; // AgentMessage | List<AgentMessage> (group)
    int i = 0;
    while (i < msgs.length) {
      if (_isFolded(msgs[i].type)) {
        final start = i;
        while (i < msgs.length && _isFolded(msgs[i].type)) {
          i++;
        }
        entries.add(msgs.sublist(start, i));
      } else {
        entries.add(msgs[i]);
        i++;
      }
    }
    return entries;
  }

  Widget _timeline(BuildContext context, List<AgentMessage> msgs,
      Map<String, SwarmRunStatus> swarmRuns, bool hasTrailing) {
    final entries = _groupEntries(msgs);
    return Listener(
      // Tapping (or dragging) the conversation drops the keyboard — it only
      // comes back when the composer input itself is tapped. A raw pointer
      // listener rather than a gesture detector, so presses that land on
      // child gestures (selectable text, links, table rows) still dismiss.
      onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 12),
        // +1 trailing slot (thinking spinner / streamed text) so both live in
        // the scrollable timeline like before — but rebuilt independently via
        // their own provider subscription.
        itemCount: entries.length + (hasTrailing ? 1 : 0),
        itemBuilder: (_, idx) {
          if (idx >= entries.length) {
            return const _TrailingStreamSlot();
          }
          final e = entries[idx];
          if (e is List<AgentMessage>) {
            return Padding(
              key: ValueKey('grp-${e.first.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ThinkingTimeline(steps: e),
            );
          }
          final m = e as AgentMessage;
          return Padding(
            key: ValueKey('msg-${m.id}'),
            padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
            child: _itemFor(m, msgs, swarmRuns),
          );
        },
      ),
    );
  }

  Widget _itemFor(
      AgentMessage m, List<AgentMessage> msgs, Map<String, SwarmRunStatus> swarmRuns) {
    switch (m.type) {
      case AgentMessageType.runComplete:
        return RunCompleteCard(message: m);
      case AgentMessageType.swarmStatus:
        return SwarmStatusCard(status: swarmRuns[m.swarmRunId] ?? m.swarmStatus);
      case AgentMessageType.liveAction:
        return LiveActionChip(message: m);
      case AgentMessageType.error:
        // Retry: re-send the user message that preceded this error.
        final idx = msgs.indexOf(m);
        String? prevUser;
        for (var j = idx - 1; j >= 0; j--) {
          if (msgs[j].type == AgentMessageType.user) {
            prevUser = msgs[j].content;
            break;
          }
        }
        return MessageBubble(
          message: m,
          onRetry: prevUser != null ? () => _send(prevUser!) : null,
        );
      case AgentMessageType.user:
      case AgentMessageType.answer:
      default:
        return MessageBubble(message: m);
    }
  }

  Widget _liveToolsStrip() {
    final liveAsync = ref.watch(liveToolsProvider);
    final tools = liveAsync.maybeWhen(
        data: (m) => m.values.toList(), orElse: () => const []);
    if (tools.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          for (final t in tools)
            Padding(padding: const EdgeInsets.only(bottom: 4), child: ToolProgressIndicator(tool: t)),
        ],
      ),
    );
  }

  /// Persistent "running" pulse bar shown while streaming (React parity):
  /// spinner + label + an indeterminate progress segment gliding across.
  Widget _streamingPulseBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      child: Row(children: [
        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 8),
        Text('Running', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
        const SizedBox(width: 12),
        const Expanded(child: LinearProgressIndicator()),
      ]),
    );
  }

  Widget _unconfigured(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppLocalizations.of(context)!.agentSetBackend,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );

  // --- actions -----------------------------------------------------------

  /// Put an example prompt into the input field (don't send — let the user
  /// edit before sending).
  void _pickExample(String prompt) {
    _inputCtrl.text = prompt;
    _inputCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: prompt.length));
    _inputFocus.requestFocus();
  }

  Future<void> _send(String content) async {
    if (content.trim().isEmpty) return;
    await ref.read(agentProvider.notifier).sendMessage(content);
    _jumpToBottom();
  }

  Future<void> _editObjective() async {
    final notifier = ref.read(agentProvider.notifier);
    final goal = ref.read(agentProvider).goal;
    if (goal == null) return;
    final ctrl = TextEditingController(text: goal.objective);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit goal objective'),
        content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return;
    if (!mounted) return;
    final sid = ref.read(agentProvider).sessionId;
    if (sid == null) return;
    final api = ref.read(apiProvider);
    try {
      final updated = await api.updateGoal(sid, {'objective': result});
      if (mounted) notifier.setGoal(updated);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _cancelGoal() async {
    final sid = ref.read(agentProvider).sessionId;
    if (sid == null) return;
    final api = ref.read(apiProvider);
    try {
      await api.updateGoalStatus(sid, 'cancelled');
      final g = await api.getGoal(sid);
      if (mounted) ref.read(agentProvider.notifier).setGoal(g);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  void _showSessions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Consumer(builder: (ctx, ref, _) {
        final s = ref.watch(agentProvider);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(AppLocalizations.of(context)!.newSession),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(agentProvider.notifier).resetToWelcome();
                },
              ),
              const Divider(height: 1),
              for (final sess in s.sessions)
                Dismissible(
                  key: ValueKey(sess.id),
                  direction: DismissDirection.horizontal,
                  // Right-to-left: delete
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  // Left-to-right: rename
                  secondaryBackground: Container(
                    color: Colors.blue,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 20),
                    child: const Icon(Icons.edit, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      // Rename
                      final ctrl = TextEditingController(text: sess.title);
                      final result = await showDialog<String>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: const Text('重命名会话'),
                          content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: '会话名称')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d), child: Text(AppLocalizations.of(ctx)!.commonCancel)),
                            FilledButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), child: Text(AppLocalizations.of(ctx)!.commonSave)),
                          ],
                        ),
                      );
                      if (result != null && result.isNotEmpty) {
                        ref.read(agentProvider.notifier).renameSession(sess.id, result);
                      }
                      return false; // snap back
                    }
                    // Delete
                    return await showDialog<bool>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: const Text('删除此会话？'),
                        content: Text(sess.title.isEmpty ? sess.id : sess.title),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(d, false),
                              child: Text(AppLocalizations.of(ctx)!.commonCancel)),
                          FilledButton(
                              onPressed: () => Navigator.pop(d, true),
                              child: const Text('删除')),
                        ],
                      ),
                    );
                  },
                  onDismissed: (_) {
                    ref.read(agentProvider.notifier).deleteSession(sess.id);
                  },
                  child: ListTile(
                    leading: Icon(sess.id == s.sessionId
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline),
                    title: Text(sess.title.isEmpty ? sess.id : sess.title),
                    subtitle: Text(sess.id,
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref.read(agentProvider.notifier).loadSession(sess.id);
                    },
                  ),
                ),
              if (s.sessions.isEmpty)
                ListTile(title: Text(AppLocalizations.of(context)!.noSessions)),
            ],
          ),
        );
      }),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Export the current chat as Markdown (React parity — downloads
  /// `chat_YYYY-MM-DD.md`). On mobile we share the text with that filename.
  Future<void> _exportChat() async {
    final state = ref.read(agentProvider);
    final buf = StringBuffer()
      // Product name, not the internal repo name — the shared file is
      // user-facing.
      ..writeln('# ${AppLocalizations.of(context)!.appTitle} chat — ${state.sessionId ?? ""}\n');
    for (final m in state.messages) {
      switch (m.type) {
        case AgentMessageType.user:
          buf.writeln('**You:** ${m.content}\n');
        case AgentMessageType.answer:
          buf.writeln('**Assistant:** ${m.content}\n');
        case AgentMessageType.error:
          buf.writeln('> ⚠️ ${m.content}\n');
        case AgentMessageType.runComplete:
          buf.writeln('**Backtest complete:** run ${m.runId ?? "?"}\n');
        case AgentMessageType.toolCall:
        case AgentMessageType.toolResult:
          buf.writeln('- tool: ${m.tool ?? ""} (${m.status ?? ""})');
        case AgentMessageType.liveAction:
          buf.writeln('- runtime: ${m.liveAction?['kind']}');
        default:
          break;
      }
    }
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await shareFile(buf.toString(), 'chat_$date.md');
  }

  Future<void> _uploadFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.path == null) return;
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    _toast(l.uploading);
    try {
      final r = await ref.read(apiProvider).uploadFile(f.path!, f.name);
      final fp = r['path'] ?? r['file_path'] ?? '';
      if (!mounted) return;
      await _send('[Uploaded file: ${f.name}, path: $fp]');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (e) {
      if (mounted) _toast('$e');
    }
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.status});
  final SseStatus status;
  @override
  Widget build(BuildContext context) {
    final color = status == SseStatus.connected
        ? Colors.green
        : status == SseStatus.reconnecting
            ? Colors.amber
            : Colors.grey;
    return Tooltip(
      message: status.name,
      child: Container(
        width: 9, height: 9,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

/// Trailing timeline slot: the "thinking…" spinner and the live streamed
/// assistant text. Subscribes to `streamingText` on its own so every
/// text_delta rebuilds exactly this subtree — the history above, the composer,
/// and the app bar are untouched while tokens stream in.
class _TrailingStreamSlot extends ConsumerWidget {
  const _TrailingStreamSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streamingText =
        ref.watch(agentProvider.select((s) => s.streamingText));
    final reasoningActive =
        ref.watch(agentProvider.select((s) => s.reasoningActive));
    if (streamingText.isEmpty) {
      if (!reasoningActive) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(left: 22, top: 8, bottom: 8),
        child: Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(AppLocalizations.of(context)!.agentThinking,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
        ]),
      );
    }
    // Streamed assistant text lives INSIDE the scrollable timeline so a long
    // reply scrolls instead of overflowing the column.
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome, size: 16,
                color: Theme.of(context).colorScheme.primary),
          ),
          Expanded(
            // Render the stream as markdown like the web client does (GFM on,
            // math deferred until the reply completes) with a pulsing caret.
            child: MarkdownContent(
              content: streamingText,
              streaming: true,
              showCursor: true,
            ),
          ),
        ],
      ),
    );
  }
}

