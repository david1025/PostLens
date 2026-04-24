import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// JWT Tool
class JwtTool extends ConsumerStatefulWidget {
  const JwtTool({super.key});
  @override
  ConsumerState<JwtTool> createState() => _JwtToolState();
}

class _JwtToolState extends ConsumerState<JwtTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();

  void _decode() {
    setState(() {
      final token = _leftController.text.trim();
      if (token.isEmpty) {
        _rightController.text = '';
        return;
      }
      final parts = token.split('.');
      if (parts.length != 3) {
        _rightController.text =
            'Invalid JWT token (must have 3 parts separated by dots)';
        return;
      }
      try {
        String decodePart(String part) {
          String normalized = base64Url.normalize(part);
          return utf8.decode(base64Url.decode(normalized));
        }

        final header = json.decode(decodePart(parts[0]));
        final payload = json.decode(decodePart(parts[1]));
        final prettyString = const JsonEncoder.withIndent('  ').convert({
          'header': header,
          'payload': payload,
        });
        _rightController.text = prettyString;
      } catch (e) {
        _rightController.text = 'Error decoding JWT: $e';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['jwt_decode'] ?? 'JWT Decode',
      leftPane: ToolTextField(
          label: 'JWT Token',
          controller: _leftController,
          hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'),
      rightPane: ToolTextField(
          label: 'Decoded Payload',
          controller: _rightController,
          readOnly: true),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolButton(onPressed: _decode, icon: Icons.arrow_downward, label: 'Decode'),
        ],
      ),
    );
  }
}
