import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

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

  Widget _buildTab(String text, MarkdownViewMode mode) {
    final isActive = _markdownViewMode == mode;
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7);

    return InkWell(
      onTap: () => _switchMarkdownViewMode(mode),
      child: Container(
        height: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: color,
          ),
        ),
      ),
    );
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 8),
        ],
        Container(
          height: 360,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _mode == DocEditorMode.richText
                          ? Theme(
                              data: Theme.of(context).copyWith(
                                canvasColor: Theme.of(context).colorScheme.surface,
                              ),
                              child: QuillSimpleToolbar(
                                controller: _quillController,
                                config: QuillSimpleToolbarConfig(
                                  toolbarSize: 28,
                                  multiRowsDisplay: false,
                                  showFontFamily: false,
                                  showFontSize: false,
                                  showHeaderStyle: true,
                                  showUndo: false,
                                  showRedo: false,
                                  showSearchButton: false,
                                  showSubscript: false,
                                  showSuperscript: false,
                                  showColorButton: false,
                                  showBackgroundColorButton: false,
                                  showClearFormat: false,
                                  showAlignmentButtons: false,
                                  showDirection: false,
                                  showIndent: false,
                                  buttonOptions: QuillSimpleToolbarButtonOptions(
                                    base: QuillToolbarBaseButtonOptions(
                                      iconSize: 14,
                                      iconButtonFactor: 1.0,
                                      iconTheme: QuillIconTheme(
                                        iconButtonUnselectedData: IconButtonData(
                                          padding: const EdgeInsets.all(4),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        iconButtonSelectedData: IconButtonData(
                                          padding: const EdgeInsets.all(4),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ),
                                    ),
                                    selectHeaderStyleDropdownButton: const QuillToolbarSelectHeaderStyleDropdownButtonOptions(
                                      attributes: [
                                        Attribute.header,
                                        Attribute.h1,
                                        Attribute.h2,
                                        Attribute.h3,
                                        Attribute.h4,
                                        Attribute.h5,
                                        Attribute.h6,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                const SizedBox(width: 8),
                                _buildTab(widget.markdownLabel, MarkdownViewMode.edit),
                                const SizedBox(width: 16),
                                _buildTab(widget.previewLabel, MarkdownViewMode.preview),
                              ],
                            ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 24,
                      width: 1,
                      color: Theme.of(context).dividerColor,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    PopupMenuButton<DocEditorMode>(
                      tooltip: 'Select Editor Mode',
                      position: PopupMenuPosition.under,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onSelected: _switchMode,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: DocEditorMode.richText,
                          height: 32,
                          child: Text(widget.richTextLabel, style: const TextStyle(fontSize: 12)),
                        ),
                        PopupMenuItem(
                          value: DocEditorMode.markdown,
                          height: 32,
                          child: Text(widget.markdownLabel, style: const TextStyle(fontSize: 12)),
                        ),
                      ],
                      child: SizedBox(
                        height: 20,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _mode == DocEditorMode.richText ? widget.richTextLabel : widget.markdownLabel,
                              style: const TextStyle(color: Colors.blue, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            const FaIcon(FontAwesomeIcons.chevronDown, size: 10, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
              // Content Area
              Expanded(
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
                              document: Document.fromDelta(markdownToQuillDelta(_markdown)),
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
                    : QuillEditor.basic(
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
