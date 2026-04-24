import 'dart:convert';

String formatCode(String code, String type) {
  if (code.trim().isEmpty) return code;

  try {
    if (type == 'JSON' || type == 'GraphQL') {
      final parsed = jsonDecode(code);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } else if (type == 'XML' || type == 'HTML') {
      return formatXml(code);
    } else if (type == 'JavaScript') {
      return formatJs(code);
    }
  } catch (e) {
    return code;
  }
  return code;
}

String formatXml(String xml) {
  var formatted = xml.replaceAll(RegExp(r'>\s*<'), '><').trim();
  int indent = 0;
  final buffer = StringBuffer();
  final tags = formatted.split(RegExp(r'(?=<)|(?<=>)'));
  bool lastWasText = false;
  bool lastWasOpening = false;

  for (int i = 0; i < tags.length; i++) {
    var tag = tags[i].trim();
    if (tag.isEmpty) continue;

    if (tag.startsWith('</')) {
      indent = indent > 0 ? indent - 1 : 0;
      if (!lastWasText && !lastWasOpening) {
        if (buffer.isNotEmpty) buffer.write('\n${'  ' * indent}');
      }
      buffer.write(tag);
      lastWasText = false;
      lastWasOpening = false;
    } else if (tag.startsWith('<') &&
        !tag.startsWith('<?') &&
        !tag.startsWith('<!') &&
        !tag.endsWith('/>')) {
      if (buffer.isNotEmpty) buffer.write('\n${'  ' * indent}');
      buffer.write(tag);
      indent++;
      lastWasOpening = true;
      lastWasText = false;
    } else if (tag.startsWith('<')) {
      if (buffer.isNotEmpty) buffer.write('\n${'  ' * indent}');
      buffer.write(tag);
      lastWasOpening = false;
      lastWasText = false;
    } else {
      buffer.write(tag);
      lastWasText = true;
      lastWasOpening = false;
    }
  }
  return buffer.toString().trim();
}

String formatJs(String js) {
  int indent = 0;
  final buffer = StringBuffer();
  bool inString = false;
  String stringChar = '';

  for (int i = 0; i < js.length; i++) {
    final char = js[i];
    if ((char == '"' || char == "'" || char == '`') &&
        (i == 0 || js[i - 1] != '\\')) {
      if (!inString) {
        inString = true;
        stringChar = char;
      } else if (char == stringChar) {
        inString = false;
      }
    }

    if (inString) {
      buffer.write(char);
      continue;
    }

    if (char == '{' || char == '[') {
      indent++;
      buffer.write('$char\n${'  ' * indent}');
    } else if (char == '}' || char == ']') {
      indent = indent > 0 ? indent - 1 : 0;
      buffer.write('\n${'  ' * indent}$char');
    } else if (char == ';') {
      buffer.write(';\n${'  ' * indent}');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\n\s*\n'), '\n').trim();
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024.0;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024.0;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
  final gb = mb / 1024.0;
  return '${gb.toStringAsFixed(1)} GB';
}

Map<String, dynamic> inferJsonSchema(dynamic value) {
  if (value == null) {
    return {'type': 'null'};
  }
  if (value is bool) {
    return {'type': 'boolean'};
  }
  if (value is int) {
    return {'type': 'integer'};
  }
  if (value is double || value is num) {
    return {'type': 'number'};
  }
  if (value is String) {
    return {'type': 'string'};
  }
  if (value is List) {
    if (value.isEmpty) {
      return {'type': 'array', 'items': {}};
    }

    final itemSchemas = value.map(inferJsonSchema).toList();
    final types = itemSchemas
        .map((s) => s['type'])
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();

    if (types.length <= 1) {
      return {'type': 'array', 'items': itemSchemas.first};
    }

    final unique = <String, Map<String, dynamic>>{};
    for (final s in itemSchemas) {
      unique[jsonEncode(s)] = s;
    }
    return {
      'type': 'array',
      'items': {'oneOf': unique.values.toList()}
    };
  }
  if (value is Map) {
    final props = <String, dynamic>{};
    final required = <String>[];
    value.forEach((k, v) {
      final key = k.toString();
      props[key] = inferJsonSchema(v);
      required.add(key);
    });
    return {
      'type': 'object',
      'properties': props,
      'required': required,
      'additionalProperties': false,
    };
  }
  return {'type': 'string'};
}

String generateJsonSchemaText(String jsonText) {
  if (jsonText.trim().isEmpty) return '';
  try {
    final decoded = jsonDecode(jsonText);
    final schema = <String, dynamic>{
      r'$schema': 'http://json-schema.org/draft-07/schema#',
      ...inferJsonSchema(decoded),
    };
    return const JsonEncoder.withIndent('  ').convert(schema);
  } catch (_) {
    return '';
  }
}
