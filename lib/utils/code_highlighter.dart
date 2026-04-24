import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:flutter_highlight/themes/github.dart';

class CodeHighlighterController extends TextEditingController {
  String? language;
  Map<String, TextStyle> theme;

  CodeHighlighterController({
    super.text,
    this.language,
    this.theme = githubTheme,
  });

  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    if (language == null || language!.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    try {
      final effectiveTheme = _getEffectiveTheme(context);
      final parsed = highlight.parse(text, language: language);
      final nodes = parsed.nodes;
      if (nodes == null) return TextSpan(style: style, text: text);

      return TextSpan(
        style: style,
        children: _convert(nodes, effectiveTheme),
      );
    } catch (e) {
      return TextSpan(style: style, text: text);
    }
  }

  static Map<String, TextStyle> getEffectiveTheme(
      BuildContext context, String? language, Map<String, TextStyle> theme) {
    if ((language ?? '').toLowerCase() != 'json') {
      return theme;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = Map<String, TextStyle>.from(theme);

    final keyStyle = TextStyle(
      color: isDark ? const Color(0xFFE06C75) : const Color(0xFFB31D28),
    );
    base['attr'] = base['attr']?.merge(keyStyle) ?? keyStyle;
    base['attribute'] = base['attribute']?.merge(keyStyle) ?? keyStyle;

    final stringStyle = TextStyle(
      color: isDark ? const Color(0xFF61AFEF) : const Color(0xFF0969DA),
    );
    base['string'] = base['string']?.merge(stringStyle) ?? stringStyle;

    return base;
  }

  static List<TextSpan> convert(
      List<Node> nodes, Map<String, TextStyle> effectiveTheme) {
    List<TextSpan> spans = [];
    var currentSpans = spans;
    List<List<TextSpan>> stack = [];

    void traverse(Node node) {
      if (node.value != null) {
        currentSpans.add(node.className == null
            ? TextSpan(text: node.value)
            : TextSpan(
                text: node.value, style: effectiveTheme[node.className!]));
      } else if (node.children != null) {
        List<TextSpan> tmp = [];
        currentSpans.add(
            TextSpan(children: tmp, style: effectiveTheme[node.className!]));
        stack.add(currentSpans);
        currentSpans = tmp;

        for (var n in node.children!) {
          traverse(n);
        }
        currentSpans = stack.removeLast();
      }
    }

    for (var node in nodes) {
      traverse(node);
    }
    return spans;
  }

  Map<String, TextStyle> _getEffectiveTheme(BuildContext context) {
    return getEffectiveTheme(context, language, theme);
  }

  List<TextSpan> _convert(
      List<Node> nodes, Map<String, TextStyle> effectiveTheme) {
    return convert(nodes, effectiveTheme);
  }
}
