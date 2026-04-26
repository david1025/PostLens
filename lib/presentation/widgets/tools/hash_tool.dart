import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:crypto/crypto.dart';
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// Hash Tool
class HashTool extends ConsumerStatefulWidget {
  const HashTool({super.key});
  @override
  ConsumerState<HashTool> createState() => _HashToolState();
}

class _HashToolState extends ConsumerState<HashTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();
  String _selectedAlgo = 'MD5';

  void _compute() {
    setState(() {
      final bytes = utf8.encode(_leftController.text);
      Digest digest;
      switch (_selectedAlgo) {
        case 'MD5':
          digest = md5.convert(bytes);
          break;
        case 'SHA-1':
          digest = sha1.convert(bytes);
          break;
        case 'SHA-256':
          digest = sha256.convert(bytes);
          break;
        case 'SHA-512':
          digest = sha512.convert(bytes);
          break;
        default:
          digest = md5.convert(bytes);
      }
      _rightController.text = digest.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['hash'] ?? 'Hash',
      leftPane: ToolTextField(
          label: t['text_utf8'] ?? 'Text (UTF-8)',
          controller: _leftController,
          hintText: t['enter_text_to_hash'] ?? 'Enter text to hash...'),
      rightPane: ToolTextField(
          label: '$_selectedAlgo ${t['hex'] ?? 'Hex'}',
          controller: _rightController,
          readOnly: true),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PopupMenuButton<String>(
            tooltip: t['algorithm'] ?? 'Algorithm',
            position: PopupMenuPosition.under,
            padding: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.surface,
            constraints: const BoxConstraints(minWidth: 100, maxWidth: 100),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
              side: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1.0,
              ),
            ),
            splashRadius: 16,
            onSelected: (String value) {
              setState(() => _selectedAlgo = value);
              _compute();
            },
            itemBuilder: (context) => ['MD5', 'SHA-1', 'SHA-256', 'SHA-512']
                .map((String value) {
              return PopupMenuItem<String>(
                value: value,
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    if (value == _selectedAlgo)
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: FaIcon(FontAwesomeIcons.check,
                            size: 12, color: Colors.grey),
                      )
                    else
                      const SizedBox(width: 20),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
            child: Container(
              width: 100,
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedAlgo,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 12),
                  ),
                  const FaIcon(FontAwesomeIcons.chevronDown,
                      size: 10, color: Colors.grey),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          ToolButton(onPressed: _compute, icon: Icons.arrow_downward, label: t['hash'] ?? 'Hash'),
        ],
      ),
    );
  }
}
