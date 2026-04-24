import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// Base64 Tool
class Base64Tool extends ConsumerStatefulWidget {
  const Base64Tool({super.key});
  @override
  ConsumerState<Base64Tool> createState() => _Base64ToolState();
}

class _Base64ToolState extends ConsumerState<Base64Tool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();

  void _encode() {
    setState(() {
      try {
        final text = _leftController.text;
        if (text.isEmpty) {
          _rightController.text = '';
          return;
        }
        final bytes = utf8.encode(text);
        _rightController.text = base64.encode(bytes);
      } catch (e) {
        _rightController.text = 'Error encoding: $e';
      }
    });
  }

  void _decode() {
    setState(() {
      try {
        final text = _rightController.text.trim();
        if (text.isEmpty) {
          _leftController.text = '';
          return;
        }
        final bytes = base64.decode(text);
        _leftController.text = utf8.decode(bytes);
      } catch (e) {
        _leftController.text = 'Error decoding: $e';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['base64_encode_decode'] ?? 'Base64 Encode/Decode',
      leftPane: ToolTextField(
          label: 'Text (UTF-8)',
          controller: _leftController,
          hintText: 'Enter text here...'),
      rightPane: ToolTextField(
          label: 'Base64',
          controller: _rightController,
          hintText: 'Enter Base64 here...'),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolButton(onPressed: _encode, icon: Icons.arrow_downward, label: 'Encode'),
          const SizedBox(width: 16),
          ToolButton(onPressed: _decode, icon: Icons.arrow_upward, label: 'Decode'),
        ],
      ),
    );
  }
}
