import 'package:flutter/material.dart';
import 'package:post_lens/re_editor/re_editor.dart';
import 'package:post_lens/re_highlight/languages/json.dart';
import 'package:post_lens/re_highlight/languages/javascript.dart';
import 'package:post_lens/re_highlight/languages/graphql.dart';
import 'package:post_lens/re_highlight/languages/xml.dart';
import 'package:post_lens/re_highlight/languages/css.dart';
import 'package:post_lens/re_highlight/languages/markdown.dart';
import 'package:post_lens/re_highlight/styles/github.dart';
import 'package:post_lens/re_highlight/styles/atom-one-dark.dart';

PreferredSizeWidget _buildSearchWidget(
    BuildContext context, CodeFindController controller, bool readOnly) {
  if (controller.value == null) {
    return const PreferredSize(
        preferredSize: Size.zero, child: SizedBox.shrink());
  }
  return PreferredSize(
    preferredSize: const Size.fromHeight(40),
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller.findInputController,
              focusNode: controller.findInputFocusNode,
              decoration: const InputDecoration(
                hintText: 'Find',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (controller.value?.replaceMode == true && !readOnly)
            Expanded(
              child: TextField(
                controller: controller.replaceInputController,
                focusNode: controller.replaceInputFocusNode,
                decoration: const InputDecoration(
                  hintText: 'Replace',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (controller.value?.result != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${controller.value!.result!.matches.isEmpty ? 0 : controller.value!.result!.index + 1} / ${controller.value!.result!.matches.length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 16),
            onPressed: () => controller.previousMatch(),
            tooltip: 'Previous Match',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 16),
            onPressed: () => controller.nextMatch(),
            tooltip: 'Next Match',
          ),
          if (!readOnly)
            IconButton(
              icon: const Icon(Icons.find_replace, size: 16),
              onPressed: () => controller.toggleMode(),
              tooltip: 'Toggle Replace',
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => controller.close(),
            tooltip: 'Close',
          ),
        ],
      ),
    ),
  );
}

class AppCodeEditor extends StatefulWidget {
  final String text;
  final String hint;
  final Function(String)? onChanged;
  final bool readOnly;
  final String? language;
  final bool wrapLines;

  const AppCodeEditor({
    super.key,
    required this.text,
    this.hint = '',
    this.onChanged,
    this.readOnly = false,
    this.language,
    this.wrapLines = true,
  });

  @override
  State<AppCodeEditor> createState() => AppCodeEditorState();
}

class AppCodeEditorState extends State<AppCodeEditor> {
  late CodeLineEditingController _controller;
  late CodeDiagnosticsController _diagnosticsController;
  CodeJsonValidationController? _jsonValidationController;
  late CodeFindController _findController;

  void showSearch() {
    _findController.findMode();
  }

  void insertText(String text) {
    _controller.replaceSelection(text);
  }

  @override
  void initState() {
    super.initState();
    _diagnosticsController = CodeDiagnosticsController();
    _controller = CodeLineEditingController(
      codeLines: widget.text.codeLines,
      diagnosticsController: _diagnosticsController,
    );
    _findController = CodeFindController(_controller);
    _controller.addListener(_onTextChanged);
    _syncJsonValidation();
  }

  void _onTextChanged() {
    if (widget.onChanged != null && _controller.text != widget.text) {
      Future.microtask(() {
        if (mounted) {
          widget.onChanged!(_controller.text);
        }
      });
    }
  }

  void _syncJsonValidation() {
    _jsonValidationController?.dispose();
    _jsonValidationController = null;
    if (widget.language == 'json') {
      _jsonValidationController = CodeJsonValidationController(
        controller: _controller,
        diagnosticsController: _diagnosticsController,
      );
    } else {
      _diagnosticsController.setDiagnostics(const <CodeDiagnostic>[]);
    }
  }

  @override
  void didUpdateWidget(AppCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && widget.text != _controller.text) {
      _controller.text = widget.text;
    }
    if (widget.language != oldWidget.language) {
      _syncJsonValidation();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _jsonValidationController?.dispose();
    _diagnosticsController.dispose();
    _findController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Map<String, CodeHighlightThemeMode> _getLanguages() {
    if (widget.language == 'javascript') {
      return {'javascript': CodeHighlightThemeMode(mode: langJavascript)};
    } else if (widget.language == 'graphql') {
      return {'graphql': CodeHighlightThemeMode(mode: langGraphql)};
    } else if (widget.language == 'markdown') {
      return {'markdown': CodeHighlightThemeMode(mode: langMarkdown)};
    } else if (widget.language == 'xml' || widget.language == 'html') {
      return {'xml': CodeHighlightThemeMode(mode: langXml)};
    } else if (widget.language == 'css') {
      return {'css': CodeHighlightThemeMode(mode: langCss)};
    }
    return {'json': CodeHighlightThemeMode(mode: langJson)};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final customLightTheme = Map<String, TextStyle>.from(githubTheme);
    customLightTheme['attr'] =
        const TextStyle(color: Color(0xFF312E81), fontWeight: FontWeight.w600);
    customLightTheme['string'] = const TextStyle(color: Color(0xFF059669));
    customLightTheme['number'] = const TextStyle(color: Color(0xFFB45309));

    final customDarkTheme = Map<String, TextStyle>.from(atomOneDarkTheme);
    customDarkTheme['attr'] = const TextStyle(color: Color(0xFF38BDF8));
    customDarkTheme['string'] = const TextStyle(color: Color(0xFF4ADE80));
    customDarkTheme['number'] = const TextStyle(color: Color(0xFFFBBF24));
    customDarkTheme['punctuation'] = const TextStyle(color: Color(0xFF94A3B8));

    final Widget editor = CodeEditor(
      controller: _controller,
      findController: _findController,
      findBuilder: _buildSearchWidget,
      readOnly: widget.readOnly,
      wordWrap: widget.wrapLines,
      style: CodeEditorStyle(
        fontSize: 12,
        fontFamily: 'IBMPlexMono',
        fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
        selectionColor: isDark
            ? const Color(0xFF264F78)
            : const Color(
                0xFFBCE0FF), // Updated to the light blue selection color from the image
        codeTheme: CodeHighlightTheme(
          languages: _getLanguages(),
          theme: isDark ? customDarkTheme : customLightTheme,
        ),
      ),
      indicatorBuilder:
          (context, editingController, chunkController, notifier) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
            ),
            DefaultCodeChunkIndicator(
              width: 20,
              controller: chunkController,
              notifier: notifier,
            ),
          ],
        );
      },
    );
    return editor;
  }
}
