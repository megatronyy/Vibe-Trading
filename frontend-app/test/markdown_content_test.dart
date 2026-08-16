// Tests for the markdown/math preprocessing ported from the web
// `normalizeMathDelimiters` + the md/tex segment split.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_app/core/util/markdown_content.dart';

void main() {
  group('normalizeMathDelimiters', () {
    test(r'rewrites \(..\) to inline $$..$$', () {
      expect(
        normalizeMathDelimiters(r'The ratio \(x/y\) matters'),
        contains(r'$$x/y$$'),
      );
    });

    test('rewrites \\[..\\] to a display block', () {
      final out = normalizeMathDelimiters(r'Beta:\[\beta = \frac{Cov}{Var}\]done');
      expect(out, contains('Beta:'));
      expect(out, contains('\n\n\$\$\n'));
      expect(out, contains(r'\beta = \frac{Cov}{Var}'));
      expect(out, contains('done'));
    });

    test('leaves code segments untouched (fenced + inline + unclosed fence)', () {
      const fenced = '```dart\nfinal x = r"\\(not math\\)";\n```';
      expect(normalizeMathDelimiters(fenced), fenced);
      const inline = 'run `\\(p\\)` locally';
      expect(normalizeMathDelimiters(inline), inline);
      const unclosed = '```\n\\(streaming\\)';
      expect(normalizeMathDelimiters(unclosed), unclosed);
    });

    test('normalizes math around code without touching the code', () {
      final out = normalizeMathDelimiters(
          r'before \(a\) mid ```py\n# \(nope\)\n``` after \(b\)');
      expect(out, contains(r'$$a$$'));
      expect(out, contains(r'$$b$$'));
      expect(out, contains(r'# \(nope\)'));
    });

    test('plain dollar amounts stay plain', () {
      const s = 'from \$150 to \$120 — no math here';
      expect(normalizeMathDelimiters(s), s);
    });
  });

  group('splitMathSegments', () {
    test('alternates markdown and math chunks', () {
      final chunks = splitMathSegments('before\n\$\$x^2\$\$\nafter');
      expect(chunks.length, 3);
      expect(chunks[0].md, 'before\n');
      expect(chunks[1].tex, r'x^2');
      expect(chunks[2].md, '\nafter');
    });

    test('math inside code stays code', () {
      final chunks =
          splitMathSegments('a `\$\$not math\$\$` b');
      // One merged md chunk is fine; the point is no tex chunk appears.
      expect(chunks.any((c) => c.tex != null), isFalse);
      expect(chunks.map((c) => c.md).join(), contains(r'$$not math$$'));
    });

    test('existing display math blocks are extracted', () {
      final chunks = splitMathSegments('text\n\n\$\$\n\\beta = 1\n\$\$\n\nmore');
      final tex = chunks.where((c) => c.tex != null).toList();
      expect(tex.length, 1);
      expect(tex.single.tex, r'\beta = 1');
    });

    test('content without math is a single md chunk', () {
      final chunks = splitMathSegments('# Heading\n\nplain paragraph\n');
      expect(chunks.length, 1);
      expect(chunks.single.tex, isNull);
    });

    test('splitMathSegments delegates — tables are lifted too', () {
      final chunks = splitMathSegments('| a |\n|---|\n| 1 |');
      expect(chunks.single.table, isNotNull);
    });
  });

  group('splitSegments — GFM table extraction', () {
    test('basic table becomes a table chunk between md chunks', () {
      final chunks = splitSegments(
          'Intro\n\n| Sym | Price | Chg |\n|---|---|---|\n'
          '| AAPL | 123.45 | +1.2% |\n| MSFT | 234.56 | -0.3% |\n\nOutro');
      expect(chunks.length, 3);
      expect(chunks[0].md, 'Intro\n\n');
      expect(chunks[2].md, '\nOutro');
      final t = chunks[1].table!;
      expect(t.headers, ['Sym', 'Price', 'Chg']);
      expect(t.rows.length, 2);
      expect(t.rows[0], ['AAPL', '123.45', '+1.2%']);
      expect(t.rows[1][2], '-0.3%');
    });

    test('parses per-column alignment from the delimiter row', () {
      final chunks = splitSegments('| a | b | c |\n|:--|:-:|--:|\n| 1 | 2 | 3 |');
      final t = chunks.single.table!;
      expect(t.aligns, [TextAlign.left, TextAlign.center, TextAlign.right]);
    });

    test('header-only table (mid-stream, no body yet)', () {
      final chunks = splitSegments('| a | b |\n|---|---|', streaming: true);
      final t = chunks.single.table!;
      expect(t.headers, ['a', 'b']);
      expect(t.rows, isEmpty);
    });

    test('tables are extracted while streaming too', () {
      final chunks =
          splitSegments('math \$\$x^2\$\$ then\n\n| a |\n|---|\n| 1 |',
              streaming: true);
      // Math stays inline while streaming; the table is still lifted.
      expect(chunks.any((c) => c.tex != null), isFalse);
      expect(chunks.any((c) => c.table != null), isTrue);
    });

    test('ragged rows are padded and truncated', () {
      final chunks =
          splitSegments('| a | b | c |\n|---|---|---|\n| x |\n| 1 | 2 | 3 | 4 |');
      final t = chunks.single.table!;
      expect(t.rows[0], ['x', '', '']);
      expect(t.rows[1], ['1', '2', '3']);
    });

    test('escaped pipes stay inside the cell', () {
      final chunks = splitSegments('| a | b |\n|---|---|\n| x\\|y | 2 |');
      final t = chunks.single.table!;
      expect(t.rows[0][0], 'x|y');
    });

    test('blank cells are preserved as empty strings', () {
      final chunks = splitSegments('| a | b |\n|---|---|\n|  | 2 |');
      final t = chunks.single.table!;
      expect(t.rows[0], ['', '2']);
    });

    test('delimiter-looking lines inside a code fence are not a table', () {
      const md = 'text\n\n```\n| a | b |\n|---|---|\n| 1 | 2 |\n```\nafter';
      final chunks = splitSegments(md);
      expect(chunks.any((c) => c.table != null), isFalse);
      // md chunks concatenate back to the original text, code untouched.
      expect(chunks.map((c) => c.md).join(), md);
    });

    test('setext-style dash line after prose is not a table', () {
      final chunks = splitSegments('Heading\n---\n\nparagraph');
      expect(chunks.any((c) => c.table != null), isFalse);
    });

    test('column-count mismatch between header and delimiter is not a table',
        () {
      final chunks = splitSegments('| a | b |\n|---|\n| 1 | 2 |');
      expect(chunks.any((c) => c.table != null), isFalse);
    });

    test('paragraph after a table is not swallowed as a row', () {
      final chunks =
          splitSegments('| a | b |\n|---|---|\n| 1 | 2 |\nplain line');
      expect(chunks.length, 2);
      expect(chunks[0].table!.rows.length, 1);
      expect(chunks[1].md, contains('plain line'));
    });

    test('math, table and code coexist', () {
      final chunks = splitSegments('pre \$\$x^2\$\$ mid\n\n'
          '| a | b |\n|---|---|\n| 1 | 2 |\n\n'
          '```\ncode\n```\n'
          'after');
      expect(chunks.any((c) => c.tex != null), isTrue);
      expect(chunks.any((c) => c.table != null), isTrue);
      expect(chunks.any((c) => c.md != null && c.md!.contains('code')), isTrue);
    });

    test('multiple tables in one reply', () {
      final chunks = splitSegments(
          '| a |\n|---|\n| 1 |\n\ntext between\n\n| b |\n|---|\n| 2 |');
      final tables = chunks.where((c) => c.table != null).toList();
      expect(tables.length, 2);
      expect(tables[0].table!.rows.single.single, '1');
      expect(tables[1].table!.rows.single.single, '2');
    });
  });

  group('MarkdownContent table rendering', () {
    testWidgets('wide table renders in a horizontal scroller and a row tap '
        'opens the detail sheet', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320, // narrow phone-ish viewport, table is much wider
            child: MarkdownContent(
              content: '| Symbol | Entry | Target | Stop | Confidence | Rationale |\n'
                  '|---|---|---|---|---|---|\n'
                  '| AAPL | 150.25 | 165.00 | 144.00 | 0.82 | earnings momentum |\n'
                  '| MSFT | 234.50 | 260.00 | 225.00 | 0.64 | cloud growth |\n',
            ),
          ),
        ),
      ));

      // The custom table block: a Table inside a horizontal scroll view.
      expect(find.byType(Table), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.text('AAPL'), findsOneWidget);

      // Tapping any cell of a data row opens the bottom-sheet detail with
      // the row's label → value pairs.
      await tester.tap(find.text('MSFT'));
      await tester.pumpAndSettle();
      expect(find.text('Row 2 of 2'), findsOneWidget);
      // 'Rationale' appears once as the table header, once as a sheet label.
      expect(find.text('Rationale'), findsNWidgets(2));
    });
  });
}
