import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:url_launcher/url_launcher.dart';

/// Markdown renderer for agent replies — the Flutter counterpart of the web
/// `MarkdownContent` (frontend/src/components/chat/MessageBubble.tsx):
///
/// - GitHub-flavored markdown (tables, strikethrough, task lists) via
///   [ExtensionSet.gitHubFlavored].
/// - GFM pipe tables are pulled out of the markdown stream and rendered by a
///   mobile-friendly table widget: columns sized to their widest cell (cells
///   never wrap), horizontal scrolling for wide tables, and a tap on any data
///   row opens a bottom sheet with the full row as label → value pairs.
/// - LaTeX display math (`$$…$$`) rendered with flutter_math_fork; LLM
///   `\(...\)` / `\[...\]` delimiters are normalized to `$$` first (port of
///   the web `normalizeMathDelimiters`). Code spans/blocks are untouched.
/// - Single-dollar math is deliberately NOT rendered ("from $150 to $120"
///   must stay text) — same `singleDollarTextMath: false` choice as the web.
/// - Links open externally via url_launcher.
/// - While [streaming], math extraction is skipped (web parity: katex off
///   during streaming — half-delivered `$$` pairs must not flicker), and
///   [showCursor] appends a pulsing caret. Tables ARE extracted while
///   streaming — rows arrive line-by-line and a partial table renders fine.

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

/// One renderable chunk of a reply: markdown text XOR a LaTeX expression XOR
/// a GFM pipe table.
class MdChunk {
  const MdChunk.md(String this.md)
      : tex = null,
        table = null;
  const MdChunk.tex(String this.tex)
      : md = null,
        table = null;
  const MdChunk.table(MdTable this.table)
      : md = null,
        tex = null;
  final String? md;
  final String? tex;
  final MdTable? table;
}

/// A GFM pipe table parsed out of a reply — rendered by the mobile table
/// block at the bottom of this file (no-wrap cells, horizontal scroll,
/// tap-a-row detail sheet).
class MdTable {
  const MdTable({
    required this.headers,
    required this.aligns,
    required this.rows,
  });

  /// Header cell texts (blank `<th></th>` stays an empty string).
  final List<String> headers;

  /// Per-column [TextAlign] parsed from the delimiter row
  /// (`:--` left, `:-:` center, `--:` right).
  final List<TextAlign> aligns;

  /// Data rows, each padded / truncated to [headers].length (GFM
  /// ragged-row rule).
  final List<List<String>> rows;
}

/// Split into markdown / table / math chunks. Code segments stay glued to
/// the surrounding markdown (math and tables inside code are not extracted).
///
/// While [streaming], math extraction is skipped but table extraction is
/// not — rows arrive one line at a time and a partial table renders fine.
List<MdChunk> splitSegments(String content, {bool streaming = false}) {
  final out = <MdChunk>[];
  var last = 0;
  for (final m in _codeSegment.allMatches(content)) {
    _appendPlain(out, content.substring(last, m.start), streaming);
    out.add(MdChunk.md(m.group(0)!)); // code — verbatim
    last = m.end;
  }
  _appendPlain(out, content.substring(last), streaming);
  return out;
}

/// Legacy math-only entry point kept for existing call sites — now simply
/// delegates to [splitSegments] (so tables are lifted too).
List<MdChunk> splitMathSegments(String content) => splitSegments(content);

void _appendPlain(List<MdChunk> out, String part, bool streaming) {
  if (part.isEmpty) return;
  var last = 0;
  for (final t in _scanTables(part)) {
    _appendMath(out, part.substring(last, t.start), streaming);
    out.add(MdChunk.table(t.table));
    last = t.end;
  }
  _appendMath(out, part.substring(last), streaming);
}

void _appendMath(List<MdChunk> out, String part, bool streaming) {
  if (part.isEmpty) return;
  if (streaming) {
    out.add(MdChunk.md(part));
    return;
  }
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

// --- GFM pipe-table scan ---------------------------------------------------

/// A table found inside a plain (non-code) text run: [start]/[end] are byte
/// offsets into that run, [table] the parsed result.
class _TableMatch {
  const _TableMatch(this.start, this.end, this.table);
  final int start;
  final int end;
  final MdTable table;
}

/// GFM delimiter-row cell: `:?-+:?` — one or more dashes with optional
/// alignment colons, anchored so prose never matches.
final RegExp _delimCell = RegExp(r'^:?-+:?$');

/// Scan a plain text run for GFM pipe tables (header row + delimiter row +
/// body rows). Line-based: a delimiter-shaped line whose previous line
/// contains a pipe and has the same cell count opens a table.
List<_TableMatch> _scanTables(String part) {
  final out = <_TableMatch>[];
  if (!part.contains('|')) return out;
  final lines = part.split('\n');
  // Start offset of each line, for slicing the chunk out of `part`.
  final starts = List<int>.filled(lines.length, 0);
  var o = 0;
  for (var i = 0; i < lines.length; i++) {
    starts[i] = o;
    o += lines[i].length + 1;
  }
  var i = 0;
  while (i < lines.length) {
    final headerCells = _splitRow(lines[i]);
    final isTable = i + 1 < lines.length &&
        lines[i].contains('|') &&
        lines[i + 1].contains('|') &&
        _isDelimiterRow(_splitRow(lines[i + 1]), headerCells.length);
    if (!isTable) {
      i++;
      continue;
    }
    var j = i + 2;
    while (j < lines.length && _isBodyLine(lines[j])) {
      j++;
    }
    final nCols = headerCells.length;
    out.add(_TableMatch(
      starts[i],
      j < lines.length ? starts[j] : part.length,
      MdTable(
        headers: headerCells,
        aligns: [
          for (final c in _splitRow(lines[i + 1]))
            c.startsWith(':') && c.endsWith(':')
                ? TextAlign.center
                : c.endsWith(':')
                    ? TextAlign.right
                    : TextAlign.left,
        ],
        rows: [
          for (var k = i + 2; k < j; k++) _fitRow(_splitRow(lines[k]), nCols),
        ],
      ),
    ));
    i = j;
  }
  return out;
}

bool _isDelimiterRow(List<String> cells, int colCount) =>
    cells.length == colCount && cells.every(_delimCell.hasMatch);

/// GFM continues the body until a blank line or another block-level element.
/// Chat replies always blank-line-separate tables, so a following paragraph
/// must NOT be swallowed as a row — require a pipe and stop at obvious
/// block openers (headings, blockquotes).
bool _isBodyLine(String line) {
  final t = line.trim();
  if (t.isEmpty || !line.contains('|')) return false;
  return !t.startsWith('#') && !t.startsWith('>');
}

/// Split a GFM table row into cells on unescaped pipes; surrounding pipes
/// are dropped, `\|` is unescaped, each cell is trimmed.
List<String> _splitRow(String line) {
  var s = line.trim();
  if (s.startsWith('|')) s = s.substring(1);
  if (s.endsWith('|') && !s.endsWith('\\|')) s = s.substring(0, s.length - 1);
  final cells = <String>[];
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final ch = s[i];
    if (ch == '\\' && i + 1 < s.length && s[i + 1] == '|') {
      buf.write('|');
      i++;
    } else if (ch == '|') {
      cells.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  cells.add(buf.toString().trim());
  return cells;
}

/// Pad with empty cells / truncate extras so every row matches the header
/// width (GFM ragged-row rule).
List<String> _fitRow(List<String> cells, int colCount) => [
      for (var i = 0; i < colCount; i++) i < cells.length ? cells[i] : '',
    ];

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
    final segments = splitSegments(normalized, streaming: streaming);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in segments)
          if (s.tex != null)
            _MathBlock(tex: s.tex!)
          else if (s.table != null)
            _TableBlock(table: s.table!)
          else
            _md(context, s.md!),
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
        // Fallback for tables that still go through MarkdownBody (edge
        // cases the chunk scanner misses): content-sized columns + the
        // package's built-in horizontal scrollbar instead of wrapped cells.
        tableColumnWidth: const IntrinsicColumnWidth(),
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

/// A GFM table with mobile-friendly formatting: columns sized to their
/// widest cell (cells never wrap), horizontal scrolling for wide tables, and
/// a tap on any data row opening a bottom sheet that lists the full row as
/// label → value pairs (long values wrap and are copyable there).
class _TableBlock extends StatefulWidget {
  const _TableBlock({required this.table});
  final MdTable table;

  @override
  State<_TableBlock> createState() => _TableBlockState();
}

class _TableBlockState extends State<_TableBlock> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nCols = widget.table.headers.length;
    if (nCols == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Scrollbar(
        controller: _scroll,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: Table(
            // Intrinsic width = each column as wide as its widest cell, so
            // cell text keeps to one line; the scroll view takes overflow.
            defaultColumnWidth: const IntrinsicColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            border: TableBorder.all(
              color: theme.colorScheme.outlineVariant,
              width: 0.5,
              borderRadius: BorderRadius.circular(6),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.6),
                ),
                children: [
                  for (var c = 0; c < nCols; c++)
                    _cell(
                      widget.table.headers[c],
                      align: widget.table.aligns[c],
                      bold: true,
                    ),
                ],
              ),
              for (var r = 0; r < widget.table.rows.length; r++)
                TableRow(
                  decoration: r.isOdd
                      ? BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.25),
                        )
                      : null,
                  children: [
                    for (var c = 0; c < nCols; c++)
                      // TableRow has no onTap — make every cell of the row
                      // hit-testable so the whole row opens the detail.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showRowDetail(context, r),
                        child: _cell(
                          widget.table.rows[r][c],
                          align: widget.table.aligns[c],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(String text, {TextAlign align = TextAlign.left, bool bold = false}) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Text(
        text.isEmpty ? ' ' : text, // keep empty cells one line high
        textAlign: align,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: bold
            ? style?.copyWith(fontWeight: FontWeight.w600)
            : style?.copyWith(height: 1.3),
      ),
    );
  }

  void _showRowDetail(BuildContext context, int rowIndex) {
    final table = widget.table;
    final row = table.rows[rowIndex];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final theme = Theme.of(sheetCtx);
        final title = row.isNotEmpty ? row.first : '';
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? 'Row ${rowIndex + 1}' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Row ${rowIndex + 1} of ${table.rows.length}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Detail view is where long cell content belongs — values
                // wrap fully and are selectable for copying.
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 12),
                    children: [
                      for (var c = 0; c < table.headers.length; c++)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                table.headers[c].isEmpty
                                    ? 'Column ${c + 1}'
                                    : table.headers[c],
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SelectableText(
                                row[c].isEmpty ? '-' : row[c],
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(height: 1.4),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
