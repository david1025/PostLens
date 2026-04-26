import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// HMAC Tool
class HmacTool extends ConsumerStatefulWidget {
  const HmacTool({super.key});
  @override
  ConsumerState<HmacTool> createState() => _HmacToolState();
}

class _HmacToolState extends ConsumerState<HmacTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  String _selectedAlgo = 'SHA-256';

  void _compute() {
    setState(() {
      final keyBytes = utf8.encode(_keyController.text);
      final dataBytes = utf8.encode(_leftController.text);
      Hmac hmac;
      switch (_selectedAlgo) {
        case 'MD5':
          hmac = Hmac(md5, keyBytes);
          break;
        case 'SHA-1':
          hmac = Hmac(sha1, keyBytes);
          break;
        case 'SHA-256':
          hmac = Hmac(sha256, keyBytes);
          break;
        case 'SHA-512':
          hmac = Hmac(sha512, keyBytes);
          break;
        default:
          hmac = Hmac(sha256, keyBytes);
      }
      final digest = hmac.convert(dataBytes);
      _rightController.text = digest.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Text(t['secret_key'] ?? 'Secret Key:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _keyController,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).dividerColor)),
                      enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).dividerColor)),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: DualPaneToolWidget(
            title: t['hmac'] ?? 'HMAC',
            leftPane: ToolTextField(
                label: t['text_utf8'] ?? 'Text (UTF-8)',
                controller: _leftController,
                hintText: t['enter_text_to_sign'] ?? 'Enter text to sign...'),
            rightPane: ToolTextField(
                label: t['hmac_hex'] ?? 'HMAC Hex',
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
                ToolButton(onPressed: _compute, icon: Icons.arrow_downward, label: t['compute_hmac'] ?? 'Compute HMAC'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
