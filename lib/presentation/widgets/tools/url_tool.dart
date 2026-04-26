import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// URL Tool
class UrlTool extends ConsumerStatefulWidget {
  const UrlTool({super.key});
  @override
  ConsumerState<UrlTool> createState() => _UrlToolState();
}

class _UrlToolState extends ConsumerState<UrlTool> {
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
        _rightController.text = Uri.encodeComponent(text);
      } catch (e) {
        final t = ref.read(translationsProvider);
        _rightController.text = '${t['error_encoding'] ?? 'Error encoding: '}$e';
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
        _leftController.text = Uri.decodeComponent(text);
      } catch (e) {
        final t = ref.read(translationsProvider);
        _leftController.text = '${t['error_decoding'] ?? 'Error decoding: '}$e';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['url_encode_decode'] ?? 'URL Encode/Decode',
      leftPane: ToolTextField(
          label: t['decoded_text'] ?? 'Decoded Text',
          controller: _leftController,
          hintText: t['url_encode_hint_1'] ?? 'https://example.com/?q=test'),
      rightPane: ToolTextField(
          label: t['encoded_url'] ?? 'Encoded URL',
          controller: _rightController,
          hintText: t['url_encode_hint_2'] ?? 'https%3A%2F%2Fexample.com%2F%3Fq%3Dtest'),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolButton(onPressed: _encode, icon: Icons.arrow_downward, label: t['encode'] ?? 'Encode'),
          const SizedBox(width: 16),
          ToolButton(onPressed: _decode, icon: Icons.arrow_upward, label: t['decode'] ?? 'Decode'),
        ],
      ),
    );
  }
}
