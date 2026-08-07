import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_app/l10n_gen/app_localizations.dart';
import 'package:go_router/go_router.dart';
import '../../core/util/share_file.dart';

import '../../core/config/app_config.dart';
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
    final notifier = ref.read(agentProvider.notifier);
    await notifier.refreshSessions();
    notifier.pollLiveStatus();
    // Land in the most recent session if none is active yet, so the Agent
    // opens to an existing chat rather than an empty welcome screen.
    final sessions = ref.read(agentProvider).sessions;
    if (sessions.isNotEmpty && ref.read(agentProvider).sessionId == null) {
      notifier.loadSession(sessions.first.id);
    }
  }

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentProvider);
    final cfg = ref.watch(appConfigProvider);
    ref.listen<AgentState>(agentProvider, (prev, next) {
      final grew = prev == null ||
          next.messages.length != prev.messages.length ||
          next.streamingText != prev.streamingText;
      if (grew && _nearBottom) _jumpToBottom();
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
          onPressed: () => _showSessions(context, state),
        ),
        title: Text(AppLocalizations.of(context)!.agentTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: AppLocalizations.of(context)!.newSession,
            onPressed: () => ref.read(agentProvider.notifier).resetToWelcome(),
          ),
          if (state.messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: AppLocalizations.of(context)!.exportChat,
              onPressed: _exportChat,
            ),
          if (state.streaming)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _Dot(status: state.sseStatus)),
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
                  child: (state.messages.isEmpty && state.streamingText.isEmpty)
                      ? WelcomeScreen(onPick: _pickExample)
                      : _timeline(context, state),
                ),
                if (state.goal != null)
                  GoalPanel(
                    goal: state.goal!,
                    onContinue: () => _send('Continue the active research goal.'),
                    onEditObjective: _editObjective,
                    onCancel: _cancelGoal,
                  ),
                _liveToolsStrip(),
                if (state.streaming) _streamingPulseBar(context),
                Composer(
                  controller: _inputCtrl,
                  onSend: _send,
                  onMenuUpload: _uploadFile,
                  onMenuGoal: () => _send('Help me define a research goal.'),
                  onMenuSwarm: () => _send(
                      '[Swarm Team Mode] Use the swarm tool to assemble the best '
                      'specialist team. Auto-select the most appropriate preset.'),
                  onMenuConnector: () => _send(
                      'Check my broker connector status and report authorization, '
                      'mandate, and runner state for each broker.'),
                  isStreaming: state.streaming,
                  onStop: () => ref.read(agentProvider.notifier).cancelGeneration(),
                  onHalt: () => ref.read(agentProvider.notifier).haltLive(),
                  liveActive: state.liveActive,
                ),
              ],
            ),
    );
  }

  Widget _timeline(BuildContext context, AgentState state) {
    final items = <Widget>[];
    final msgs = state.messages;
    int i = 0;
    while (i < msgs.length) {
      final m = msgs[i];
      if (m.type == AgentMessageType.thinking ||
          m.type == AgentMessageType.toolCall ||
          m.type == AgentMessageType.toolResult ||
          m.type == AgentMessageType.compact) {
        final group = <AgentMessage>[];
        while (i < msgs.length &&
            (msgs[i].type == AgentMessageType.thinking ||
                msgs[i].type == AgentMessageType.toolCall ||
                msgs[i].type == AgentMessageType.toolResult ||
                msgs[i].type == AgentMessageType.compact)) {
          group.add(msgs[i]);
          i++;
        }
        items.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ThinkingTimeline(steps: group),
        ));
      } else {
        items.add(Padding(
          padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 4),
          child: _itemFor(m, state),
        ));
        i++;
      }
    }
    if (state.reasoningActive && state.streamingText.isEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(left: 22, top: 8, bottom: 8),
        child: Row(children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Text(AppLocalizations.of(context)!.agentThinking,
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.outline)),
        ]),
      ));
    }
    // Streamed assistant text lives INSIDE the scrollable timeline (as the last
    // item) so a long reply scrolls instead of overflowing the column.
    if (state.streamingText.isNotEmpty) {
      items.add(Padding(
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
              child: SelectableText(
                '${state.streamingText}▌',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ),
          ],
        ),
      ));
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: items.length,
      itemBuilder: (_, idx) => items[idx],
    );
  }

  Widget _itemFor(AgentMessage m, AgentState state) {
    switch (m.type) {
      case AgentMessageType.runComplete:
        return RunCompleteCard(message: m);
      case AgentMessageType.swarmStatus:
        return SwarmStatusCard(
            status: state.swarmRuns[m.swarmRunId] ?? m.swarmStatus);
      case AgentMessageType.liveAction:
        return LiveActionChip(message: m);
      case AgentMessageType.error:
        // Retry: re-send the user message that preceded this error.
        final idx = state.messages.indexOf(m);
        String? prevUser;
        for (var j = idx - 1; j >= 0; j--) {
          if (state.messages[j].type == AgentMessageType.user) {
            prevUser = state.messages[j].content;
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
    if (result == null || result.isEmpty) return;
    final sid = ref.read(agentProvider).sessionId;
    if (sid == null) return;
    final api = ref.read(apiProvider);
    try {
      final updated = await api.updateGoal(sid, {'objective': result});
      notifier.setGoal(updated);
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _cancelGoal() async {
    final sid = ref.read(agentProvider).sessionId;
    if (sid == null) return;
    final api = ref.read(apiProvider);
    try {
      await api.updateGoalStatus(sid, 'cancelled');
      final g = await api.getGoal(sid);
      ref.read(agentProvider.notifier).setGoal(g);
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _showSessions(BuildContext context, AgentState state) {
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Export the current chat as Markdown (React parity — downloads
  /// `chat_YYYY-MM-DD.md`). On mobile we share the text with that filename.
  Future<void> _exportChat() async {
    final state = ref.read(agentProvider);
    final buf = StringBuffer()
      ..writeln('# Vibe-Trading chat — ${state.sessionId ?? ""}\n');
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
      await _send('[Uploaded file: ${f.name}, path: $fp]');
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('$e');
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

