import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:highlight/highlight.dart' show highlight;
import 'package:flutter_highlight/themes/darcula.dart';
import 'package:flutter_highlight/themes/github.dart';
import '../../utils/code_highlighter.dart';

class FoldableCodeView extends StatefulWidget {
  final String text;
  final bool wrapLines;
  final TextStyle? textStyle;
  final double gutterWidth;
  final EdgeInsets contentPadding;
  final String? language;

  const FoldableCodeView({
    super.key,
    required this.text,
    this.wrapLines = true,
    this.textStyle,
    this.gutterWidth = 64,
    this.contentPadding =
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    this.language,
  });

  @override
  State<FoldableCodeView> createState() => _FoldableCodeViewState();
}

class _FoldRow {
  final int? lineNumber;
  final String text;
  final int sourceLineIndex;
  final bool isFoldable;
  final bool isFolded;
  final int? foldStart;

  const _FoldRow({
    required this.lineNumber,
    required this.text,
    required this.sourceLineIndex,
    required this.isFoldable,
    required this.isFolded,
    required this.foldStart,
  });
}

class _StackEntry {
  final String kind;
  final int line;

  const _StackEntry({required this.kind, required this.line});
}

class _FoldableCodeViewState extends State<FoldableCodeView> {
  final Set<int> _foldedStarts = {};

  static const _openBrace = '{';
  static const _openBracket = '[';
  static const _closeBrace = '}';
  static const _closeBracket = ']';

  Map<int, int> _computeFoldRanges(List<String> lines) {
    final ranges = <int, int>{};
    final stack = <_StackEntry>[];
    var inString = false;
    var escaping = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      for (var cIndex = 0; cIndex < line.length; cIndex++) {
        final c = line[cIndex];

        if (inString) {
          if (escaping) {
            escaping = false;
            continue;
          }
          if (c == '\\\\') {
            escaping = true;
            continue;
          }
          if (c == '"') {
            inString = false;
          }
          continue;
        }

        if (c == '"') {
          inString = true;
          continue;
        }

        if (c == _openBrace || c == _openBracket) {
          stack.add(_StackEntry(kind: c, line: i));
          continue;
        }

        if (c == _closeBrace || c == _closeBracket) {
          if (stack.isEmpty) continue;
          final last = stack.removeLast();
          final expected =
              last.kind == _openBrace ? _closeBrace : _closeBracket;
          if (c != expected) continue;
          if (i > last.line) {
            ranges[last.line] = i;
          }
        }
      }
    }

    return ranges;
  }

  List<_FoldRow> _buildRows(List<String> lines, Map<int, int> foldRanges) {
    final rows = <_FoldRow>[];

    var i = 0;
    while (i < lines.length) {
      final end = foldRanges[i];
      final isFoldable = end != null;
      final isFolded = isFoldable && _foldedStarts.contains(i);

      rows.add(_FoldRow(
        lineNumber: i + 1,
        text: lines[i],
        sourceLineIndex: i,
        isFoldable: isFoldable,
        isFolded: isFolded,
        foldStart: isFoldable ? i : null,
      ));

      if (isFolded) {
        final indent = RegExp(r'^\s*').firstMatch(lines[i])?.group(0) ?? '';
        final placeholderIndent = '$indent  ';
        rows.add(_FoldRow(
          lineNumber: null,
          text: '$placeholderIndent...',
          sourceLineIndex: i,
          isFoldable: false,
          isFolded: false,
          foldStart: i,
        ));
        rows.add(_FoldRow(
          lineNumber: end + 1,
          text: lines[end],
          sourceLineIndex: end,
          isFoldable: false,
          isFolded: false,
          foldStart: null,
        ));
        i = end + 1;
        continue;
      }

      i++;
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.textStyle ??
        TextStyle(
          fontFamily: 'Consolas',
          fontSize: 12,
          height: 1.2,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        );

    final lines = widget.text.split('\n');
    final foldRanges = _computeFoldRanges(lines);
    final rows = _buildRows(lines, foldRanges);

    Widget buildRow(_FoldRow row) {
      final gutter = Container(
        width: widget.gutterWidth,
        padding: const EdgeInsets.only(left: 8, right: 8),
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                row.lineNumber?.toString() ?? '',
                textAlign: TextAlign.right,
                style: style.copyWith(color: Colors.blue),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 12,
              child: row.isFoldable
                  ? InkWell(
                      onTap: () {
                        setState(() {
                          if (row.foldStart == null) return;
                          if (_foldedStarts.contains(row.foldStart)) {
                            _foldedStarts.remove(row.foldStart);
                          } else {
                            _foldedStarts.add(row.foldStart!);
                          }
                        });
                      },
                      child: Center(
                        child: FaIcon(
                          row.isFolded
                              ? FontAwesomeIcons.chevronRight
                              : FontAwesomeIcons.chevronDown,
                          size: 10,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      );

      TextSpan? span;
      if (widget.language != null && widget.language!.isNotEmpty) {
        try {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final theme = isDark ? darculaTheme : githubTheme;
          final effectiveTheme = CodeHighlighterController.getEffectiveTheme(
              context, widget.language, theme);

          final parsed = highlight.parse(row.text, language: widget.language);
          final nodes = parsed.nodes;
          if (nodes != null) {
            span = TextSpan(
                style: style,
                children:
                    CodeHighlighterController.convert(nodes, effectiveTheme));
          }
        } catch (_) {}
      }

      final codeLine = Padding(
        padding: const EdgeInsets.symmetric(vertical: 0),
        child: span != null
            ? SelectableText.rich(span)
            : SelectableText(row.text, style: style),
      );

      final code = widget.wrapLines
          ? codeLine
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: codeLine,
            );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          gutter,
          Expanded(child: code),
        ],
      );
    }

    return Container(
      padding: widget.contentPadding.copyWith(right: 0),
      child: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (context, index) => buildRow(rows[index]),
      ),
    );
  }
}
