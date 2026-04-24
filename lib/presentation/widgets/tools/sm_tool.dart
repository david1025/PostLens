import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:dart_sm/dart_sm.dart' as sm;
import 'package:post_lens/core/utils/toast_utils.dart';
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// SM Tool
class SmTool extends ConsumerStatefulWidget {
  const SmTool({super.key});
  @override
  ConsumerState<SmTool> createState() => _SmToolState();
}

class _SmToolState extends ConsumerState<SmTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  String _selectedAlgo = 'SM3 (Hash)';
  String _sm2PubKey = '';
  String _sm2PrivKey = '';

  void _generateSm2Keys() {
    try {
      final keypair = sm.SM2.generateKeyPair();
      setState(() {
        _sm2PubKey = keypair.publicKey;
        _sm2PrivKey = keypair.privateKey;
        _keyController.text =
            'Pub: ${_sm2PubKey.substring(0, 16)}...\nPriv: ${_sm2PrivKey.substring(0, 16)}...';
      });
      ToastUtils.showInfo(context, 'Generated SM2 Key Pair');
    } catch (e) {
      ToastUtils.showInfo(context, 'Error generating keys: $e');
    }
  }

  void _compute() {
    setState(() {
      try {
        if (_selectedAlgo == 'SM3 (Hash)') {
          final hash = sm.SM3.hash(_leftController.text);
          _rightController.text = hash;
        } else if (_selectedAlgo == 'SM4 (Encrypt)') {
          final keyStr = _keyController.text.replaceAll('\n', '').trim();
          if (keyStr.length != 32) {
            _rightController.text =
                'SM4 Key must be exactly 32 hex characters (16 bytes).';
            return;
          }
          final encrypted = sm.SM4.encrypt(
            _leftController.text,
            key: keyStr,
            mode: sm.SM4CryptoMode.ECB,
          );
          _rightController.text = encrypted;
        } else if (_selectedAlgo == 'SM4 (Decrypt)') {
          final keyStr = _keyController.text.replaceAll('\n', '').trim();
          if (keyStr.length != 32) {
            _rightController.text =
                'SM4 Key must be exactly 32 hex characters (16 bytes).';
            return;
          }
          final decrypted = sm.SM4.decrypt(
            _leftController.text.trim(),
            key: keyStr,
            mode: sm.SM4CryptoMode.ECB,
          );
          _rightController.text = decrypted.toString();
        } else if (_selectedAlgo == 'SM2 (Encrypt)') {
          if (_sm2PubKey.isEmpty) {
            _rightController.text = 'Please generate SM2 keys first.';
            return;
          }
          final encrypted = sm.SM2.encrypt(
            _leftController.text,
            _sm2PubKey,
            cipherMode: sm.C1C3C2,
          );
          _rightController.text = encrypted;
        } else if (_selectedAlgo == 'SM2 (Decrypt)') {
          if (_sm2PrivKey.isEmpty) {
            _rightController.text = 'Please generate SM2 keys first.';
            return;
          }
          final decrypted = sm.SM2.decrypt(
            _leftController.text.trim(),
            _sm2PrivKey,
            cipherMode: sm.C1C3C2,
          );
          _rightController.text = decrypted;
        }
      } catch (e) {
        _rightController.text = 'Error: $e';
      }
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
              Text(t['key_config'] ?? 'Key / Config:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _keyController,
                  maxLines: 2,
                  minLines: 1,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                    fontFamily: 'Consolas',
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Enter 32-char Hex key for SM4, or click generate for SM2',
                    hintStyle:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                    border: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor)),
                    enabledBorder: OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Theme.of(context).dividerColor)),
                    focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _generateSm2Keys,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: Text(t['generate_sm2_keys'] ?? 'Generate SM2 Keys'),
              ),
            ],
          ),
        ),
        Expanded(
          child: DualPaneToolWidget(
            title: t['sm_algorithms'] ?? 'SM (SM2/SM3/SM4) Algorithms',
            leftPane:
                ToolTextField(label: 'Input Data', controller: _leftController),
            rightPane: ToolTextField(
                label: 'Output Result',
                controller: _rightController,
                readOnly: true),
            centerControls: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PopupMenuButton<String>(
                  tooltip: 'Algorithm',
                  position: PopupMenuPosition.under,
                  padding: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.surface,
                  constraints: const BoxConstraints(minWidth: 130, maxWidth: 130),
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
                  },
                  itemBuilder: (context) => [
                    'SM3 (Hash)',
                    'SM4 (Encrypt)',
                    'SM4 (Decrypt)',
                    'SM2 (Encrypt)',
                    'SM2 (Decrypt)',
                  ].map((String value) {
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
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    width: 130,
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
                              fontSize: 11),
                        ),
                        const FaIcon(FontAwesomeIcons.chevronDown,
                            size: 10, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ToolButton(onPressed: _compute, icon: Icons.arrow_downward, label: 'Compute'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
