import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:url_launcher/url_launcher.dart';

/// Markdown renderer for agent replies — the Flutter counterpart of the web
/// `MarkdownContent` (frontend/src/components/chat/MessageBubble.tsx):
///
/// - GitHub-flavored markdown (tables, strikethrough, task lists) via
///   [ExtensionSet.gitHubFlavored].
/// - LaTeX display math (`$$…$$`) rendered with flutter_math_fork; LLM
///   `\(...\)` / `\[...\]` delimiters are normalized to `$$` first (port of
///   the web `normalizeMathDelimiters`). Code spans/blocks are untouched.
/// - Single-dollar math is deliberately NOT rendered ("from $150 to $120"
///   must stay text) — same `singleDollarTextMath: false` choice as the web.
/// - Links open externally via url_launcher.
/// - While [streaming], math extraction is skipped (web parity: katex off
///   during streaming — half-delivered `$$` pairs must not flicker), and
///   [showCursor] appends a pulsing caret.

/// Fenced / inline code segments — normalized math must never rewrite code,
/// including a fence left unclosed mid-stream.
final RegExp _codeSegment =
    RegExp(r'(```[\s\S]*?(?:```|$)|~~~[\s\S]*?(?:~~~|$)|`[^`\n]*`)');

/// `$$…$$` math, both inline and display-block forms.
final RegExp _mathSegment = RegExp(r'\$\$([\s\S]+?)\$\$');

/// Port of the web `normalizeMathDelimiters`: `\(x\)` → inline `$$x$$`,
/// `\[x\]` → display block, code untouched.
String normalizeMathDelimiters(String content) {
  final buf = StringBuffer();
  var last = 0;
  // NOTE: iterate matches explicitly — Dart's String.split(RegExp), unlike
  // JS, does NOT include capture groups in the result.
  for (final m in _codeSegment.allMatches(content)) {
    buf.write(_normalizePlain(content.substring(last, m.start)));
    buf.write(m.group(0)!); // code — verbatim
    last = m.end;
  }
  buf.write(_normalizePlain(content.substring(last)));
  return buf.toString();
}

String _normalizePlain(String s) => s
    .replaceAllMapped(RegExp(r'\\\[([\s\S]+?)\\\]'),
        (m) => '\n\n\$\$\n${m.group(1)!.trim()}\n\$\$\n\n')
    .replaceAllMapped(RegExp(r'\\\(([\s\S]+?)\\\)'),
        (m) => '\$\$${m.group(1)!.trim()}\$\$');

/// One renderable chunk of a reply: markdown text XOR a LaTeX expression.
class MdChunk {
  const MdChunk.md(String this.md) : tex = null;
  const MdChunk.tex(String this.tex) : md = null;
  final String? md;
  final String? tex;
}

/// Split into markdown / math chunks. Code segments stay glued to the
/// surrounding markdown (math inside code is not extracted).
List<MdChunk> splitMathSegments(String content) {
  final out = <MdChunk>[];
  var last = 0;
  for (final m in _codeSegment.allMatches(content)) {
    _appendPlain(out, content.substring(last, m.start));
    out.add(MdChunk.md(m.group(0)!)); // code — verbatim
    last = m.end;
  }
  _appendPlain(out, content.substring(last));
  return out;
}

void _appendPlain(List<MdChunk> out, String part) {
  if (part.isEmpty) return;
  var last = 0;
  for (final m in _mathSegment.allMatches(part)) {
    final before = part.substring(last, m.start);
    if (before.isNotEmpty) out.add(MdChunk.md(before));
    final tex = m.group(1)!.trim();
    if (tex.isNotEmpty) out.add(MdChunk.tex(tex));
    last = m.end;
  }
  if (last < part.length) out.add(MdChunk.md(part.substring(last)));
}

class MarkdownContent extends StatelessWidget {
  const MarkdownContent({
    super.key,
    required this.content,
    this.streaming = false,
    this.showCursor = false,
  });

  final String content;
  final bool streaming;
  final bool showCursor;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeMathDelimiters(content);
    final segments =
        streaming ? [MdChunk.md(normalized)] : splitMathSegments(normalized);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in segments)
          s.tex != null ? _MathBlock(tex: s.tex!) : _md(context, s.md!),
        if (showCursor) const _PulsingCursor(),
      ],
    );
  }

  Widget _md(BuildContext context, String text) => MarkdownBody(
        data: text,
        selectable: true,
        // flutter_markdown 0.7.x defaults its extension set to
        // ExtensionSet.gitHubFlavored (tables / strikethrough / task lists),
        // matching the web client's remark-gfm.
        onTapLink: (text, href, title) => _openLink(href),
        styleSheet: _sheet(Theme.of(context)),
      );

  static MarkdownStyleSheet _sheet(ThemeData theme) =>
      MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
        h1: theme.textTheme.titleLarge?.copyWith(height: 1.4),
        h2: theme.textTheme.titleMedium?.copyWith(height: 1.4),
        h3: theme.textTheme.titleSmall?.copyWith(height: 1.4),
        a: TextStyle(color: theme.colorScheme.primary),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.4,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
        ),
        tableHead: const TextStyle(fontWeight: FontWeight.w600),
        tableBorder: TableBorder.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.5,
          borderRadius: BorderRadius.circular(6),
        ),
        listIndent: 24,
      );

  static void _openLink(String? href) {
    final uri = Uri.tryParse(href ?? '');
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return;
    try {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

/// Display-math block with the same plain-text fallback the Alpha detail page
/// uses — an unsupported macro must never blank the whole message.
class _MathBlock extends StatelessWidget {
  const _MathBlock({required this.tex});
  final String tex;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _tryMath(context),
      ),
    );
  }

  Widget _tryMath(BuildContext context) {
    try {
      return Math.tex(tex);
    } catch (_) {
      return SelectableText(
        tex,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      );
    }
  }
}

/// Blinking caret shown while the assistant streams. Self-animating so token
/// rebuilds of the surrounding content don't restart it.
class _PulsingCursor extends StatefulWidget {
  const _PulsingCursor();

  @override
  State<_PulsingCursor> createState() => _PulsingCursorState();
}

class _PulsingCursorState extends State<_PulsingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctl,
      child: Container(
        width: 2,
        height: 16,
        margin: const EdgeInsets.only(top: 2),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
