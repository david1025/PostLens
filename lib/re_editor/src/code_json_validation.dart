part of re_editor;

class JsonValidator {
  final String source;
  int pos = 0;
  List<CodeDiagnostic> diagnostics = [];

  JsonValidator(this.source);

  void addError(String message, int offset, int length) {
    diagnostics.add(CodeDiagnostic(
      offset: offset,
      length: length,
      message: message,
      severity: CodeDiagnosticSeverity.error,
    ));
  }

  void addWarning(String message, int offset, int length) {
    diagnostics.add(CodeDiagnostic(
      offset: offset,
      length: length,
      message: message,
      severity: CodeDiagnosticSeverity.warning,
    ));
  }

  void validate() {
    skipWhitespace();
    if (pos >= source.length) return;
    parseValue();
    skipWhitespace();
    if (pos < source.length) {
      addError('Unexpected trailing characters', pos, source.length - pos);
    }
  }

  void skipWhitespace() {
    while (pos < source.length) {
      int c = source.codeUnitAt(pos);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        pos++;
      } else {
        break;
      }
    }
  }

  String? parseString() {
    int start = pos;
    pos++; // skip "
    while (pos < source.length) {
      int c = source.codeUnitAt(pos);
      if (c == 0x22) {
        // "
        String s = source.substring(start + 1, pos);
        pos++;
        return s;
      } else if (c == 0x5C) {
        // \
        pos += 2;
      } else {
        pos++;
      }
    }
    addError('Unterminated string', start, pos - start);
    return null;
  }

  void parseValue() {
    skipWhitespace();
    if (pos >= source.length) {
      addError('Unexpected end of input', pos, 1);
      return;
    }
    int c = source.codeUnitAt(pos);
    if (c == 0x7B) {
      // {
      pos++;
      Map<String, int> keys = {};
      bool expectErrorOnNextKey = false;
      skipWhitespace();
      if (pos < source.length && source.codeUnitAt(pos) == 0x7D) {
        pos++;
        return;
      }
      while (pos < source.length) {
        skipWhitespace();
        if (pos >= source.length) break;
        int c2 = source.codeUnitAt(pos);
        if (c2 != 0x22) {
          int errPos = pos;
          addError('Expected string key', pos, 1);
          while (pos < source.length) {
            int ch = source.codeUnitAt(pos);
            if (ch == 0x22 || ch == 0x7D) break;
            pos++;
          }
          if (pos == errPos) pos++;
          if (pos >= source.length || source.codeUnitAt(pos) == 0x7D) break;
        }

        int keyStart = pos;
        String? key = parseString();
        if (key != null) {
          if (expectErrorOnNextKey) {
            addError(
                'Unexpected key after invalid comma', keyStart, key.length + 2);
            expectErrorOnNextKey = false;
          }
          if (keys.containsKey(key)) {
            addWarning('Duplicate key "$key"', keyStart, key.length + 2);
            int prevPos = keys[key]!;
            if (!diagnostics.any((d) =>
                d.offset == prevPos &&
                d.severity == CodeDiagnosticSeverity.warning)) {
              addWarning('Duplicate key "$key"', prevPos, key.length + 2);
            }
          } else {
            keys[key] = keyStart;
          }
        }

        skipWhitespace();
        if (pos >= source.length) break;
        if (source.codeUnitAt(pos) != 0x3A) {
          // :
          addError('Expected ":"', pos, 1);
          while (pos < source.length) {
            int ch = source.codeUnitAt(pos);
            if (ch == 0x3A || ch == 0x22 || ch == 0x2C || ch == 0x7D) break;
            pos++;
          }
          if (pos < source.length && source.codeUnitAt(pos) == 0x3A) pos++;
        } else {
          pos++;
        }

        parseValue();

        skipWhitespace();
        if (pos >= source.length) break;

        int next = source.codeUnitAt(pos);
        if (next == 0x7D) {
          // }
          pos++;
          return;
        } else if (next == 0x2C) {
          // ,
          pos++;
        } else {
          int errPos = pos;
          if (next == 0xFF0C) {
            // ，
            addError('Invalid character "，", expected ","', pos, 1);
            pos++;
            expectErrorOnNextKey = true;
          } else {
            addError('Expected "," or "}"', pos, 1);
            while (pos < source.length) {
              int ch = source.codeUnitAt(pos);
              if (ch == 0x2C || ch == 0x22 || ch == 0x7D) break;
              pos++;
            }
            if (pos == errPos) pos++;
          }
        }
      }
    } else if (c == 0x5B) {
      // [
      pos++;
      skipWhitespace();
      if (pos < source.length && source.codeUnitAt(pos) == 0x5D) {
        pos++;
        return;
      }
      while (pos < source.length) {
        parseValue();
        skipWhitespace();
        if (pos >= source.length) {
          addError('Unterminated array', pos, 1);
          break;
        }
        int next = source.codeUnitAt(pos);
        if (next == 0x5D) {
          pos++;
          return;
        } else if (next == 0x2C) {
          pos++;
        } else {
          int errPos = pos;
          if (next == 0xFF0C) {
            addError('Invalid character "，", expected ","', pos, 1);
            pos++;
          } else {
            addError('Expected "," or "]"', pos, 1);
            while (pos < source.length) {
              int ch = source.codeUnitAt(pos);
              if (ch == 0x2C ||
                  ch == 0x5D ||
                  ch == 0x22 ||
                  ch == 0x7B ||
                  ch == 0x5B) break;
              pos++;
            }
            if (pos == errPos) pos++;
          }
        }
      }
    } else if (c == 0x22) {
      // "
      parseString();
    } else {
      // primitive value
      int start = pos;
      while (pos < source.length) {
        int cc = source.codeUnitAt(pos);
        if (cc == 0x20 ||
            cc == 0x09 ||
            cc == 0x0A ||
            cc == 0x0D ||
            cc == 0x2C ||
            cc == 0x5D ||
            cc == 0x7D ||
            cc == 0xFF0C) {
          break;
        }
        pos++;
      }
      if (start == pos) {
        addError('Expected value', pos, 1);
        pos++;
      } else {
        String val = source.substring(start, pos);
        if (val != 'true' &&
            val != 'false' &&
            val != 'null' &&
            double.tryParse(val) == null) {
          addError('Invalid value "$val"', start, pos - start);
        }
      }
    }
  }
}

class CodeJsonValidationController {
  final CodeLineEditingController controller;
  final CodeDiagnosticsController diagnosticsController;

  CodeJsonValidationController({
    required this.controller,
    required this.diagnosticsController,
  }) {
    controller.addListener(_validate);
    _validate();
  }

  void _validate() {
    final text = controller.text;
    if (text.trim().isEmpty) {
      diagnosticsController.setDiagnostics([]);
      return;
    }

    final validator = JsonValidator(text);
    validator.validate();
    diagnosticsController.setDiagnostics(validator.diagnostics);
  }

  void dispose() {
    controller.removeListener(_validate);
  }
}
