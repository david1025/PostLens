import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// Hex Tool
class HexTool extends ConsumerStatefulWidget {
  const HexTool({super.key});
  @override
  ConsumerState<HexTool> createState() => _HexToolState();
}

class _HexToolState extends ConsumerState<HexTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();

  void _toHex() {
    setState(() {
      try {
        final bytes = utf8.encode(_leftController.text);
        _rightController.text =
            bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      } catch (e) {
        _rightController.text = 'Error: $e';
      }
    });
  }

  void _toText() {
    setState(() {
      try {
        final hexStr = _rightController.text.replaceAll(RegExp(r'\s+'), '');
        if (hexStr.length % 2 != 0)
          throw const FormatException('Invalid hex string length');
        final bytes = <int>[];
        for (int i = 0; i < hexStr.length; i += 2) {
          bytes.add(int.parse(hexStr.substring(i, i + 2), radix: 16));
        }
        _leftController.text = utf8.decode(bytes);
      } catch (e) {
        _leftController.text = 'Error decoding Hex: $e';
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
      title: t['text_hex_dump'] ?? 'Text <-> Hex Dump',
      leftPane: ToolTextField(label: 'Text', controller: _leftController),
      rightPane: ToolTextField(label: 'Hex Dump', controller: _rightController),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolButton(onPressed: _toHex, icon: Icons.arrow_downward, label: 'Text -> Hex'),
          const SizedBox(width: 16),
          ToolButton(onPressed: _toText, icon: Icons.arrow_upward, label: 'Hex -> Text'),
        ],
      ),
    );
  }
}
