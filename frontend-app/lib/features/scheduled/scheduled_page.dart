import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/api.dart';
import '../../core/net/api_error.dart';

/// Scheduled research — list / create / delete recurring research jobs.
/// Mobile port of the React `/scheduled` page. Polls `/scheduled-runs` every
/// 30s; a bottom-sheet composer builds the schedule (cron expression or
/// interval in minutes, sent to the backend as interval-ms) and posts it with
/// a fixed `Asia/Shanghai` timezone.
class ScheduledPage extends ConsumerStatefulWidget {
  const ScheduledPage({super.key});

  @override
  ConsumerState<ScheduledPage> createState() => _ScheduledPageState();
}

class _ScheduledPageState extends ConsumerState<ScheduledPage> {
  List<Map<String, dynamic>> _runs = const [];
  bool _loading = true;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _fetch();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetch();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final runs = await ref.read(apiProvider).listScheduledRuns();
      if (!mounted) return;
      setState(() {
        _runs = runs;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _CreateJobSheet(),
    );
    if (created == true) _fetch();
  }

  Future<bool> _confirmDelete(Map<String, dynamic> run) async {
    final id = (run['id'] ?? '').toString();
    final prompt = (run['prompt'] ?? '').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text(prompt.isEmpty ? '确认删除此定时研究任务？' : '确认删除「$prompt」？',
            maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      await ref.read(apiProvider).deleteScheduledRun(id);
      await _fetch();
      return true;
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (e) {
      _toast('$e');
    }
    return false;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('定时研究'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
          IconButton(icon: const Icon(Icons.add), onPressed: _openCreate),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _runs.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)));
    }
    if (_runs.isEmpty) {
      return const Center(child: Text('暂无定时研究任务'));
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _runs.length + (_error != null ? 1 : 0),
        itemBuilder: (_, i) {
          if (_error != null && i == _runs.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            );
          }
          final run = _runs[i];
          return _jobCard(run);
        },
      ),
    );
  }

  Widget _jobCard(Map<String, dynamic> run) {
    final prompt = (run['prompt'] ?? '').toString();
    final schedule = (run['schedule'] ?? '').toString();
    final status = (run['status'] ?? '').toString();
    final nextRunAt = run['next_run_at'] as int?;
    final lastError = run['last_error']?.toString();
    final (statusLabel, statusColor) = _statusStyle(status);
    return Dismissible(
      key: ValueKey((run['id'] ?? '').toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withValues(alpha: 0.12),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      confirmDismiss: (_) => _confirmDelete(run),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          title: Text(
            prompt.isEmpty ? '(无研究目标)' : prompt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              _pill(_fmtSchedule(schedule), Theme.of(context).colorScheme.primary),
              _pill(statusLabel, statusColor),
              _pill('下次 ${_fmtEpoch(nextRunAt)}', Colors.grey),
              if (lastError != null && lastError.isNotEmpty)
                _pill('错误: $lastError', Colors.red),
            ]),
          ),
          onLongPress: () => _confirmDelete(run),
        ),
      ),
    );
  }

  Widget _pill(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      );

  // --- helpers -----------------------------------------------------------

  (String, Color) _statusStyle(String status) {
    switch (status) {
      case 'completed':
        return ('已完成', Colors.green);
      case 'failed':
        return ('失败', Colors.red);
      case 'running':
        return ('运行中', Colors.orange);
      case 'cancelled':
        return ('已取消', Colors.grey);
      default:
        return ('待运行', Colors.blue);
    }
  }
}

String _fmtSchedule(String schedule) {
  final s = schedule.trim();
  if (RegExp(r'^\d+$').hasMatch(s)) {
    final ms = int.tryParse(s) ?? 0;
    if (ms <= 0) return s;
    final mins = ms ~/ 60000;
    if (mins >= 1) return '每 $mins 分钟';
    return s;
  }
  return s;
}

String _fmtEpoch(int? epochMs) {
  if (epochMs == null || epochMs == 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

/// Bottom-sheet composer for a new scheduled research job.
class _CreateJobSheet extends ConsumerStatefulWidget {
  const _CreateJobSheet();

  @override
  ConsumerState<_CreateJobSheet> createState() => _CreateJobSheetState();
}

class _CreateJobSheetState extends ConsumerState<_CreateJobSheet> {
  final _promptCtrl = TextEditingController();
  final _valueCtrl = TextEditingController(text: '0 9 * * 1-5');
  String _type = 'cron';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _promptCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final prompt = _promptCtrl.text.trim();
    final value = _valueCtrl.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = '请输入研究目标');
      return;
    }
    if (value.isEmpty) {
      setState(() => _error = '请输入调度值');
      return;
    }
    String schedule;
    if (_type == 'interval_minutes') {
      final mins = int.tryParse(value);
      if (mins == null || mins <= 0) {
        setState(() => _error = '请输入有效的分钟数');
        return;
      }
      schedule = (mins * 60000).toString();
    } else {
      schedule = value;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).createScheduledRun({
        'prompt': prompt,
        'schedule_type': _type,
        'schedule': schedule,
        'timezone': 'Asia/Shanghai',
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('新建定时研究', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _promptCtrl,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '研究目标',
              hintText: '例如：扫描今日A股异动板块',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: '调度类型', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'cron', child: Text('Cron 表达式')),
              DropdownMenuItem(value: 'interval_minutes', child: Text('间隔分钟')),
            ],
            onChanged: (v) => setState(() {
              _type = v ?? 'cron';
              _valueCtrl.text = _type == 'cron' ? '0 9 * * 1-5' : '60';
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _valueCtrl,
            decoration: InputDecoration(
              labelText: '调度值',
              hintText: _type == 'cron' ? '例如：0 9 * * 1-5' : '例如：60（每 60 分钟）',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _type == 'cron'
                ? '标准 5 字段 Cron：分 时 日 月 周（如 0 9 * * 1-5 = 工作日 9 点）'
                : '每隔多少分钟运行一次',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_alt),
            label: const Text('保存'),
          ),
        ]),
      ),
    );
  }
}
