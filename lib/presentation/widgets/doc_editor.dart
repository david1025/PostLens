import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../utils/markdown_quill_converter.dart';
import 'app_code_editor.dart';

enum DocEditorMode { richText, markdown }

class DocEditor extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const DocEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<DocEditor> createState() => _DocEditorState();
}

class _DocEditorState extends State<DocEditor> {
  static const _debounceDuration = Duration(milliseconds: 350);

  DocEditorMode _mode = DocEditorMode.richText;
  late String _markdown;
  late QuillController _quillController;
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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SegmentedButton<DocEditorMode>(
              segments: const [
                ButtonSegment(
                  value: DocEditorMode.richText,
                  label: Text('Rich Text'),
                ),
                ButtonSegment(
                  value: DocEditorMode.markdown,
                  label: Text('Markdown'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _switchMode(s.first),
              showSelectedIcon: false,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 360,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: _mode == DocEditorMode.markdown
              ? AppCodeEditor(
                  key: ValueKey(_mode),
                  text: _markdown,
                  hint: '',
                  language: 'markdown',
                  onChanged: (v) {
                    if (v == _markdown) return;
                    setState(() => _markdown = v);
                    _scheduleEmit(v);
                  },
                )
              : Column(
                  children: [
                    QuillSimpleToolbar(
                      controller: _quillController,
                      config: const QuillSimpleToolbarConfig(),
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    Expanded(
                      child: QuillEditor.basic(
                        controller: _quillController,
                        config: const QuillEditorConfig(
                          autoFocus: false,
                          expands: true,
                          padding: EdgeInsets.all(12),
                          scrollable: true,
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
