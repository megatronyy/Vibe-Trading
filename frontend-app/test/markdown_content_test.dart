// Tests for the markdown/math preprocessing ported from the web
// `normalizeMathDelimiters` + the md/tex segment split.

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
      final chunks = splitMathSegments('# Heading\n\n| a | b |\n|---|---|\n');
      expect(chunks.length, 1);
      expect(chunks.single.tex, isNull);
    });
  });
}
