part of re_editor;

enum CodeDiagnosticSeverity { error, warning, info }

class CodeDiagnostic {
  final int offset;
  final int length;
  final String message;
  final CodeDiagnosticSeverity severity;
  final String? code;

  const CodeDiagnostic({
    required this.offset,
    required this.length,
    required this.message,
    this.severity = CodeDiagnosticSeverity.error,
    this.code,
  });
}

class CodeDiagnosticsController extends ValueNotifier<List<CodeDiagnostic>> {
  CodeDiagnosticsController([super.value = const []]);

  void setDiagnostics(List<CodeDiagnostic> diagnostics) {
    value = diagnostics;
  }
}

class DiagnosticTooltip {
  static OverlayEntry? _overlayEntry;

  static void show(
      BuildContext context, PointerEnterEvent event, String message) {
    hide();
    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: event.position.dx,
          top: event.position.dy + 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.red.withOpacity(0.5),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
    overlayState.insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _DiagnosticRange {
  final int start;
  final int end;
  final CodeDiagnostic diagnostic;
  _DiagnosticRange(this.start, this.end, this.diagnostic);
}

TextSpan applyDiagnosticsToTextSpan({
  required BuildContext context,
  required CodeLineEditingController controller,
  required int index,
  required TextSpan textSpan,
  required TextStyle style,
}) {
  final dc = controller.diagnosticsController;
  if (dc == null || dc.value.isEmpty) return textSpan;

  final line = controller.codeLines[index];
  int lineStart = 0;
  if (index > 0) {
    lineStart = controller.codeLines
            .sublines(0, index)
            .asString(controller.options.lineBreak)
            .length +
        controller.options.lineBreak.value.length;
  }

  final lineEnd = lineStart + line.length;

  final diagnostics = dc.value
      .where((d) => d.offset < lineEnd && (d.offset + d.length) > lineStart)
      .toList();

  if (diagnostics.isEmpty) return textSpan;

  List<_DiagnosticRange> ranges = [];
  for (var d in diagnostics) {
    int start = d.offset - lineStart;
    if (start < 0) start = 0;
    int end = d.offset + d.length - lineStart;
    if (end > line.length) end = line.length;
    if (start < end) {
      ranges.add(_DiagnosticRange(start, end, d));
    }
  }

  if (ranges.isEmpty) return textSpan;

  int currentOffset = 0;

  InlineSpan buildDecoratedSpan(InlineSpan span) {
    if (span is TextSpan) {
      List<InlineSpan> newChildren = [];

      if (span.text != null && span.text!.isNotEmpty) {
        String text = span.text!;
        int textStart = currentOffset;
        int textEnd = currentOffset + text.length;
        currentOffset = textEnd;

        int localOffset = 0;
        while (localOffset < text.length) {
          int absoluteOffset = textStart + localOffset;
          _DiagnosticRange? activeRange;
          for (var r in ranges) {
            if (absoluteOffset >= r.start && absoluteOffset < r.end) {
              activeRange = r;
              break;
            }
          }

          if (activeRange != null) {
            int endLocalOffset = text.length;
            if (activeRange.end - textStart < endLocalOffset) {
              endLocalOffset = activeRange.end - textStart;
            }

            String part = text.substring(localOffset, endLocalOffset);

            if (part.trim().isEmpty) {
              newChildren.add(TextSpan(
                text: part,
                style: span.style,
              ));
            } else {
              newChildren.add(MouseTrackerAnnotationTextSpan(
                text: part,
                style: span.style?.copyWith(
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.wavy,
                      decorationColor: activeRange.diagnostic.severity ==
                              CodeDiagnosticSeverity.error
                          ? Colors.red
                          : Colors.orange,
                      decorationThickness: 2.0,
                    ) ??
                    TextStyle(
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.wavy,
                      decorationColor: activeRange.diagnostic.severity ==
                              CodeDiagnosticSeverity.error
                          ? Colors.red
                          : Colors.orange,
                      decorationThickness: 2.0,
                    ),
                onEnterWithRect: (event, id, rects) {
                  DiagnosticTooltip.show(
                      context, event, activeRange!.diagnostic.message);
                },
                onExitWithRect: (event, id, rects) {
                  DiagnosticTooltip.hide();
                },
              ));
            }
            localOffset = endLocalOffset;
          } else {
            int endLocalOffset = text.length;
            for (var r in ranges) {
              if (r.start > absoluteOffset &&
                  r.start - textStart < endLocalOffset) {
                endLocalOffset = r.start - textStart;
              }
            }
            newChildren.add(TextSpan(
              text: text.substring(localOffset, endLocalOffset),
              style: span.style,
            ));
            localOffset = endLocalOffset;
          }
        }
      }

      if (span.children != null) {
        for (var child in span.children!) {
          newChildren.add(buildDecoratedSpan(child));
        }
      }

      return TextSpan(
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
        children: newChildren,
      );
    }
    return span;
  }

  return buildDecoratedSpan(textSpan) as TextSpan;
}
