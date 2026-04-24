import 'package:flutter/material.dart';
import '../../utils/code_highlighter.dart';
import 'package:flutter_highlight/themes/darcula.dart';
import 'package:flutter_highlight/themes/github.dart';

class CodeEditorWithLineNumbers extends StatefulWidget {
  final String text;
  final String hint;
  final Function(String)? onChanged;
  final String? language;
  final bool readOnly;

  const CodeEditorWithLineNumbers({
    super.key,
    required this.text,
    this.hint = '',
    this.onChanged,
    this.language,
    this.readOnly = false,
  });

  @override
  State<CodeEditorWithLineNumbers> createState() =>
      _CodeEditorWithLineNumbersState();
}

class _CodeEditorWithLineNumbersState extends State<CodeEditorWithLineNumbers> {
  late CodeHighlighterController _controller;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _lineNumbersScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller =
        CodeHighlighterController(text: widget.text, language: widget.language);
    _scrollController.addListener(() {
      if (_lineNumbersScrollController.hasClients) {
        _lineNumbersScrollController.jumpTo(_scrollController.offset);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.theme = Theme.of(context).brightness == Brightness.dark
        ? darculaTheme
        : githubTheme;
  }

  @override
  void didUpdateWidget(CodeEditorWithLineNumbers oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.language != oldWidget.language) {
      _controller.language = widget.language;
    }
    if (widget.text != _controller.text && widget.text != oldWidget.text) {
      final oldSelection = _controller.selection;
      _controller.text = widget.text;
      if (oldSelection.isValid &&
          oldSelection.baseOffset <= widget.text.length &&
          oldSelection.extentOffset <= widget.text.length) {
        _controller.selection = oldSelection;
      } else {
        _controller.selection =
            TextSelection.collapsed(offset: widget.text.length);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _lineNumbersScrollController.dispose();
    super.dispose();
  }

  Widget _buildLineNumbers(String text) {
    final lineCount = '\n'.allMatches(text).length + 1;
    final numbers =
        List.generate(lineCount, (index) => '${index + 1}').join('\n');
    return Container(
      width: 40,
      padding: const EdgeInsets.only(top: 10, right: 6, bottom: 10),
      color: Theme.of(context).colorScheme.surface,
      child: Text(
        numbers,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Colors.blue,
          fontFamily: 'Consolas',
          fontSize: 12,
          height: 1.2,
        ),
        strutStyle: const StrutStyle(
          fontFamily: 'Consolas',
          fontSize: 12,
          height: 1.2,
          forceStrutHeight: true,
        ),
      ),
    );
  }

  double _calculateTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: 'Consolas',
      fontSize: 12,
      height: 1.2,
      color: Theme.of(context).textTheme.bodyMedium?.color,
    );
    const strutStyle = StrutStyle(
      fontFamily: 'Consolas',
      fontSize: 12,
      height: 1.2,
      forceStrutHeight: true,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Line numbers
        SizedBox(
          width: 40,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              return ScrollConfiguration(
                behavior:
                    ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: SingleChildScrollView(
                  controller: _lineNumbersScrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: _buildLineNumbers(value.text),
                ),
              );
            },
          ),
        ),
        // Editor
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, child) {
                  double maxLineWidth = 0;
                  final lines = value.text.split('\n');
                  for (var line in lines) {
                    final width = _calculateTextWidth(line, textStyle);
                    if (width > maxLineWidth) maxLineWidth = width;
                  }
                  final containerWidth =
                      maxLineWidth + 32; // add padding and cursor width

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: containerWidth > constraints.maxWidth
                          ? containerWidth
                          : constraints.maxWidth,
                      child: TextField(
                        controller: _controller,
                        scrollController: _scrollController,
                        onChanged: widget.readOnly ? null : widget.onChanged,
                        readOnly: widget.readOnly,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: textStyle,
                        strutStyle: strutStyle,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          hintText: widget.hint.isEmpty ? null : widget.hint,
                          hintStyle: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
