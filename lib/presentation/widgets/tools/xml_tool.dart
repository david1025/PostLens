import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// XML Tool (Simple Formatter)
class XmlTool extends ConsumerStatefulWidget {
  const XmlTool({super.key});
  @override
  ConsumerState<XmlTool> createState() => _XmlToolState();
}

class _XmlToolState extends ConsumerState<XmlTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();

  void _format() {
    setState(() {
      try {
        String xml = _leftController.text.trim();
        if (xml.isEmpty) {
          _rightController.text = '';
          return;
        }
        xml = xml.replaceAll(RegExp(r'>\s*<'), '><');
        int pad = 0;
        String formatted = '';
        xml.split(RegExp(r'(?=<)|(?<=>)')).forEach((node) {
          if (node.trim().isEmpty) return;
          int indent = 0;
          if (node.startsWith('</')) {
            pad -= 1;
          } else if (node.startsWith('<') &&
              !node.startsWith('<?') &&
              !node.startsWith('<!') &&
              !node.endsWith('/>')) {
            indent = 1;
          }
          if (pad < 0) pad = 0;
          formatted += '${'  ' * pad}$node\n';
          pad += indent;
        });
        _rightController.text = formatted.trim();
      } catch (e) {
        final t = ref.read(translationsProvider);
        _rightController.text = '${t['error_formatting_xml'] ?? 'Error formatting XML: '}$e';
      }
    });
  }

  @override
  void dispose() {
    _leftController.dispose();
    _rightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['xml_format'] ?? 'XML Format (Simple)',
      leftPane: ToolTextField(
          label: t['raw_xml'] ?? 'Raw XML',
          controller: _leftController,
          hintText: '<root><item>text</item></root>'),
      rightPane:
          ToolTextField(label: t['formatted_xml'] ?? 'Formatted XML', controller: _rightController),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolButton(onPressed: _format, icon: Icons.format_indent_increase, label: t['format'] ?? 'Format'),
        ],
      ),
    );
  }
}
