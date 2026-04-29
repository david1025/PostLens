import 'package:flutter_quill/flutter_quill.dart';

Delta markdownToQuillDelta(String markdown) {
  final delta = Delta();
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  var inCodeBlock = false;

  for (final rawLine in lines) {
    final line = rawLine;
    if (line.trim().startsWith('```')) {
      inCodeBlock = !inCodeBlock;
      continue;
    }

    if (inCodeBlock) {
      delta.insert(line);
      delta.insert('\n', {'code-block': true});
      continue;
    }

    final headerMatch = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (headerMatch != null) {
      final level = headerMatch.group(1)!.length;
      final text = headerMatch.group(2)!;
      _insertInline(delta, text);
      delta.insert('\n', {'header': level});
      continue;
    }

    final bulletMatch = RegExp(r'^[-*]\s+(.*)$').firstMatch(line);
    if (bulletMatch != null) {
      final text = bulletMatch.group(1)!;
      _insertInline(delta, text);
      delta.insert('\n', {'list': 'bullet'});
      continue;
    }

    final orderedMatch = RegExp(r'^\d+\.\s+(.*)$').firstMatch(line);
    if (orderedMatch != null) {
      final text = orderedMatch.group(1)!;
      _insertInline(delta, text);
      delta.insert('\n', {'list': 'ordered'});
      continue;
    }

    _insertInline(delta, line);
    delta.insert('\n');
  }

  if (delta.isNotEmpty) {
    final last = delta.last;
    if (last.data is String && (last.data as String).isEmpty) {
      delta.pop();
    }
  }

  return delta;
}

String quillDeltaToMarkdown(Delta delta) {
  final buffer = StringBuffer();
  var lineBuffer = StringBuffer();
  var inCodeBlock = false;
  var orderedIndex = 1;
  String? activeListType;

  void flushLine(Map<String, dynamic>? newlineAttrs) {
    final attrs = newlineAttrs ?? const <String, dynamic>{};
    final text = lineBuffer.toString();
    lineBuffer = StringBuffer();

    final isCode = attrs['code-block'] == true;
    if (isCode && !inCodeBlock) {
      buffer.writeln('```');
      inCodeBlock = true;
    } else if (!isCode && inCodeBlock) {
      buffer.writeln('```');
      inCodeBlock = false;
    }

    if (isCode) {
      buffer.writeln(text);
      return;
    }

    final header = attrs['header'];
    final list = attrs['list'];

    if (list is String) {
      if (activeListType != list) {
        orderedIndex = 1;
        activeListType = list;
      }
    } else {
      activeListType = null;
      orderedIndex = 1;
    }

    if (header is int) {
      buffer.writeln('${'#' * header} $text');
      return;
    }

    if (list == 'bullet') {
      buffer.writeln('- $text');
      return;
    }

    if (list == 'ordered') {
      buffer.writeln('${orderedIndex++}. $text');
      return;
    }

    buffer.writeln(text);
  }

  for (final op in delta.toList()) {
    final data = op.data;
    final attrs = op.attributes;
    if (data is! String) continue;

    var remaining = data;
    while (remaining.isNotEmpty) {
      final newlineIndex = remaining.indexOf('\n');
      if (newlineIndex == -1) {
        lineBuffer.write(_applyInlineMarkdown(remaining, attrs));
        remaining = '';
      } else {
        final before = remaining.substring(0, newlineIndex);
        lineBuffer.write(_applyInlineMarkdown(before, attrs));
        flushLine(attrs);
        remaining = remaining.substring(newlineIndex + 1);
      }
    }
  }

  if (lineBuffer.isNotEmpty) {
    flushLine(null);
  }

  if (inCodeBlock) {
    buffer.writeln('```');
  }

  return buffer.toString().replaceAll(RegExp(r'\n{3,}$'), '\n\n').trimRight();
}

void _insertInline(Delta delta, String text) {
  if (text.isEmpty) return;

  var remaining = text;
  final patterns = <RegExp, Map<String, dynamic> Function(RegExpMatch)>{
    RegExp(r'\[([^\]]+)\]\(([^)]+)\)'): (m) => {'link': m.group(2)!},
    RegExp(r'\*\*([^*]+)\*\*'): (m) => {'bold': true},
    RegExp(r'\*([^*]+)\*'): (m) => {'italic': true},
    RegExp(r'`([^`]+)`'): (m) => {'code': true},
  };

  while (remaining.isNotEmpty) {
    RegExpMatch? bestMatch;
    RegExp? bestReg;
    for (final reg in patterns.keys) {
      final m = reg.firstMatch(remaining);
      if (m == null) continue;
      if (bestMatch == null || m.start < bestMatch.start) {
        bestMatch = m;
        bestReg = reg;
      }
    }

    if (bestMatch == null || bestReg == null) {
      delta.insert(remaining);
      break;
    }

    if (bestMatch.start > 0) {
      delta.insert(remaining.substring(0, bestMatch.start));
    }

    final attrs = patterns[bestReg]!(bestMatch);
    final content = bestMatch.group(1) ?? '';
    delta.insert(content, attrs);
    remaining = remaining.substring(bestMatch.end);
  }
}

String _applyInlineMarkdown(String text, Map<String, dynamic>? attrs) {
  if (text.isEmpty) return '';
  final a = attrs ?? const <String, dynamic>{};

  final link = a['link'];
  if (link is String && link.isNotEmpty) {
    return '[${_escapeMarkdownText(text)}]($link)';
  }

  final code = a['code'] == true;
  final bold = a['bold'] == true;
  final italic = a['italic'] == true;

  var result = _escapeMarkdownText(text);
  if (code) {
    return '`${result.replaceAll('`', r'\`')}`';
  }
  if (bold && italic) {
    return '***$result***';
  }
  if (bold) {
    return '**$result**';
  }
  if (italic) {
    return '*$result*';
  }
  return result;
}

String _escapeMarkdownText(String text) {
  return text.replaceAllMapped(
    RegExp(r'([\\`*_{}\[\]()#+\-.!|>])'),
    (m) => '\\${m.group(1)}',
  );
}

