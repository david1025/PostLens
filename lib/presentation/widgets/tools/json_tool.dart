import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// JSON Tool
class JsonTool extends ConsumerStatefulWidget {
  const JsonTool({super.key});
  @override
  ConsumerState<JsonTool> createState() => _JsonToolState();
}

class _JsonToolState extends ConsumerState<JsonTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();

  void _format() {
    setState(() {
      try {
        final text = _leftController.text.trim();
        if (text.isEmpty) {
          _rightController.text = '';
          return;
        }
        final parsed = json.decode(text);
        final pretty = const JsonEncoder.withIndent('  ').convert(parsed);
        _rightController.text = pretty;
      } catch (e) {
        _rightController.text = 'Invalid JSON: $e';
      }
    });
  }

  void _minify() {
    setState(() {
      try {
        final text = _leftController.text.trim();
        if (text.isEmpty) {
          _rightController.text = '';
          return;
        }
        final parsed = json.decode(text);
        final minified = json.encode(parsed);
        _rightController.text = minified;
      } catch (e) {
        _rightController.text = 'Invalid JSON: $e';
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
      title: t['json_format_minify'] ?? 'JSON Format/Minify',
      leftPane: ToolTextField(
          label: 'Raw JSON', controller: _leftController, hintText: '{"a":1}'),
      rightPane:
          ToolTextField(label: 'Formatted JSON', controller: _rightController),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolButton(onPressed: _format, icon: Icons.format_indent_increase, label: 'Format'),
          const SizedBox(width: 16),
          ToolButton(onPressed: _minify, icon: Icons.compress, label: 'Minify'),
        ],
      ),
    );
  }
}
