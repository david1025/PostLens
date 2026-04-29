import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../utils/markdown_quill_converter.dart';
import 'app_code_editor.dart';

enum DocEditorMode { richText, markdown }
enum MarkdownViewMode { edit, preview }

class DocEditor extends StatefulWidget {
  final String? title;
  final String value;
  final ValueChanged<String> onChanged;
  final String richTextLabel;
  final String markdownLabel;
  final String editLabel;
  final String previewLabel;
  final bool hideToolbarWhenUnfocused;

  const DocEditor({
    super.key,
    this.title,
    required this.value,
    required this.onChanged,
    this.richTextLabel = 'Rich Text',
    this.markdownLabel = 'Markdown',
    this.editLabel = 'Edit',
    this.previewLabel = 'Preview',
    this.hideToolbarWhenUnfocused = true,
  });

  @override
  State<DocEditor> createState() => _DocEditorState();
}

class _DocEditorState extends State<DocEditor> {
  static const _debounceDuration = Duration(milliseconds: 350);
  static const _contentFontSize = 12.0;

  DocEditorMode _mode = DocEditorMode.richText;
  MarkdownViewMode _markdownViewMode = MarkdownViewMode.edit;
  late String _markdown;
  late QuillController _quillController;
  late FocusNode _richFocusNode;
  var _toolbarHovering = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _markdown = widget.value;
    _quillController = QuillController(
      document: Document.fromDelta(markdownToQuillDelta(_markdown)),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillController.addListener(_onQuillChanged);
    _richFocusNode = FocusNode();
    _richFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(DocEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _markdown) {
      _markdown = widget.value;
      if (_mode == DocEditorMode.richText) {
        _resetQuillFromMarkdown();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _quillController.removeListener(_onQuillChanged);
    _quillController.dispose();
    _richFocusNode.dispose();
    super.dispose();
  }

  void _scheduleEmit(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () => widget.onChanged(value));
  }

  void _resetQuillFromMarkdown() {
    final nextDelta = markdownToQuillDelta(_markdown);
    _quillController.removeListener(_onQuillChanged);
    _quillController = QuillController(
      document: Document.fromDelta(nextDelta),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillController.addListener(_onQuillChanged);
  }

  void _onQuillChanged() {
    if (_mode != DocEditorMode.richText) return;
    final nextMarkdown = quillDeltaToMarkdown(_quillController.document.toDelta());
    if (nextMarkdown == _markdown) return;
    _markdown = nextMarkdown;
    _scheduleEmit(_markdown);
  }

  void _switchMode(DocEditorMode mode) {
    if (mode == _mode) return;

    if (_mode == DocEditorMode.richText) {
      _markdown = quillDeltaToMarkdown(_quillController.document.toDelta());
      _scheduleEmit(_markdown);
    }

    setState(() {
      _mode = mode;
      if (_mode == DocEditorMode.richText) {
        _resetQuillFromMarkdown();
      } else {
        _markdownViewMode = MarkdownViewMode.edit;
      }
    });
  }

  void _switchMarkdownViewMode(MarkdownViewMode mode) {
    if (mode == _markdownViewMode) return;
    setState(() => _markdownViewMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final baseStyles = DefaultStyles.getInstance(context);
    final paragraph = baseStyles.paragraph;
    final placeholder = baseStyles.placeHolder;
    final customStyles = baseStyles.merge(
      DefaultStyles(
        paragraph: paragraph == null
            ? null
            : paragraph.copyWith(
                style: paragraph.style.copyWith(fontSize: _contentFontSize),
              ),
        placeHolder: placeholder == null
            ? null
            : placeholder.copyWith(
                style: placeholder.style.copyWith(fontSize: _contentFontSize),
              ),
      ),
    );

    final segmentedStyle = ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12),
      ),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    final showToolbar = _mode == DocEditorMode.richText &&
        (!widget.hideToolbarWhenUnfocused ||
            _richFocusNode.hasFocus ||
            _toolbarHovering);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SegmentedButton<DocEditorMode>(
                      style: segmentedStyle,
                      segments: [
                        ButtonSegment(
                          value: DocEditorMode.richText,
                          label: Text(widget.richTextLabel),
                        ),
                        ButtonSegment(
                          value: DocEditorMode.markdown,
                          label: Text(widget.markdownLabel),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (s) => _switchMode(s.first),
                      showSelectedIcon: false,
                    ),
                    if (_mode == DocEditorMode.markdown)
                      SegmentedButton<MarkdownViewMode>(
                        style: segmentedStyle,
                        segments: [
                          ButtonSegment(
                            value: MarkdownViewMode.edit,
                            label: Text(widget.editLabel),
                          ),
                          ButtonSegment(
                            value: MarkdownViewMode.preview,
                            label: Text(widget.previewLabel),
                          ),
                        ],
                        selected: {_markdownViewMode},
                        onSelectionChanged: (s) =>
                            _switchMarkdownViewMode(s.first),
                        showSelectedIcon: false,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 360,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: _mode == DocEditorMode.markdown
              ? _markdownViewMode == MarkdownViewMode.edit
                  ? AppCodeEditor(
                      key: ValueKey('${_mode}-${_markdownViewMode}'),
                      text: _markdown,
                      hint: '',
                      language: 'markdown',
                      onChanged: (v) {
                        if (v == _markdown) return;
                        setState(() => _markdown = v);
                        _scheduleEmit(v);
                      },
                    )
                  : QuillEditor.basic(
                      key: ValueKey('${_mode}-${_markdownViewMode}'),
                      controller: QuillController(
                        document:
                            Document.fromDelta(markdownToQuillDelta(_markdown)),
                        selection: const TextSelection.collapsed(offset: 0),
                        readOnly: true,
                      ),
                      config: QuillEditorConfig(
                        autoFocus: false,
                        expands: true,
                        padding: const EdgeInsets.all(12),
                        scrollable: true,
                        customStyles: customStyles,
                      ),
                    )
              : Column(
                  children: [
                    if (showToolbar) ...[
                      DefaultTextStyle.merge(
                        style: const TextStyle(fontSize: _contentFontSize),
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _toolbarHovering = true),
                          onExit: (_) =>
                              setState(() => _toolbarHovering = false),
                          child: QuillSimpleToolbar(
                            controller: _quillController,
                            config: const QuillSimpleToolbarConfig(
                              toolbarSize: 32,
                              iconTheme: QuillIconTheme(
                                iconButtonUnselectedData: IconButtonData(
                                  iconSize: 18,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints.tightFor(
                                      width: 32, height: 32),
                                ),
                                iconButtonSelectedData: IconButtonData(
                                  iconSize: 18,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints.tightFor(
                                      width: 32, height: 32),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                    ],
                    Expanded(
                      child: QuillEditor.basic(
                        controller: _quillController,
                        focusNode: _richFocusNode,
                        config: QuillEditorConfig(
                          autoFocus: false,
                          expands: true,
                          padding: const EdgeInsets.all(12),
                          scrollable: true,
                          customStyles: customStyles,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
