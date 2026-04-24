import 'dart:convert';

class Formatter {
  static String formatJson(String text) {
    try {
      final object = jsonDecode(text);
      return const JsonEncoder.withIndent('  ').convert(object);
    } catch (e) {
      return text;
    }
  }

  static String formatXml(String text) {
    // Basic formatting for XML
    try {
      var formatted = '';
      var indent = 0;
      final lines = text.split(RegExp(r'>\s*<'));
      for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (i > 0) line = '<$line';
        if (i < lines.length - 1) line = '$line>';

        if (line.startsWith('</')) {
          indent--;
        }
        formatted += '${'  ' * (indent > 0 ? indent : 0)}$line\n';
        if (line.startsWith('<') &&
            !line.startsWith('</') &&
            !line.startsWith('<?') &&
            !line.endsWith('/>')) {
          indent++;
        }
      }
      return formatted.trim();
    } catch (e) {
      return text;
    }
  }
}
