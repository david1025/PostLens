import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// JSON Escape Tool
class JsonEscapeTool extends ConsumerStatefulWidget {
  const JsonEscapeTool({super.key});
  @override
  ConsumerState<JsonEscapeTool> createState() => _JsonEscapeToolState();
}

class _JsonEscapeToolState extends ConsumerState<JsonEscapeTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();

  void _escape() {
    setState(() {
      try {
        final text = _leftController.text;
        if (text.isEmpty) {
          _rightController.text = '';
          return;
        }
        _rightController.text = json.encode(text);
      } catch (e) {
        final t = ref.read(translationsProvider);
        _rightController.text = '${t['error_escaping'] ?? 'Error escaping: '}$e';
      }
    });
  }

  void _unescape() {
    setState(() {
      try {
        final text = _rightController.text.trim();
        if (text.isEmpty) {
          _leftController.text = '';
          return;
        }
        final decoded = json.decode(text);
        _leftController.text = decoded.toString();
      } catch (e) {
        final t = ref.read(translationsProvider);
        _leftController.text = '${t['error_unescaping'] ?? 'Error unescaping: '}$e';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['json_escape'] ?? 'JSON Escape',
      leftPane: ToolTextField(
          label: t['unescaped_string'] ?? 'Unescaped String',
          controller: _leftController,
          hintText: '{"key": "value"}'),
      rightPane: ToolTextField(
          label: t['escaped_string'] ?? 'Escaped String',
          controller: _rightController,
          hintText: '"{\\"key\\": \\"value\\"}"'),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolButton(onPressed: _escape, icon: Icons.arrow_downward, label: t['escape'] ?? 'Escape'),
          const SizedBox(width: 16),
          ToolButton(onPressed: _unescape, icon: Icons.arrow_upward, label: t['unescape'] ?? 'Unescape'),
        ],
      ),
    );
  }
}
