import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// AES Tool
class AesTool extends ConsumerStatefulWidget {
  const AesTool({super.key});
  @override
  ConsumerState<AesTool> createState() => _AesToolState();
}

class _AesToolState extends ConsumerState<AesTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _ivController = TextEditingController();

  encrypt.Encrypter _getEncrypter() {
    final keyStr = _keyController.text
        .padRight(32, '0')
        .substring(0, 32); // Use 256 bit key by padding/truncating
    final key = encrypt.Key.fromUtf8(keyStr);
    return encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));
  }

  encrypt.IV _getIV() {
    final ivStr = _ivController.text.padRight(16, '0').substring(0, 16);
    return encrypt.IV.fromUtf8(ivStr);
  }

  void _encrypt() {
    setState(() {
      try {
        final encrypter = _getEncrypter();
        final iv = _getIV();
        final encrypted = encrypter.encrypt(_leftController.text, iv: iv);
        _rightController.text = encrypted.base64;
      } catch (e) {
        final t = ref.read(translationsProvider);
        _rightController.text = '${t['error'] ?? 'Error: '}$e';
      }
    });
  }

  void _decrypt() {
    setState(() {
      try {
        final encrypter = _getEncrypter();
        final iv = _getIV();
        final decrypted =
            encrypter.decrypt64(_rightController.text.trim(), iv: iv);
        _leftController.text = decrypted;
      } catch (e) {
        final t = ref.read(translationsProvider);
        _leftController.text = '${t['error'] ?? 'Error: '}$e';
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
              Text(t['key'] ?? 'Key:',
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
                      hintText: t['aes_key_hint'] ?? 'AES Key (auto padded to 32 chars)',
                      hintStyle:
                          const TextStyle(color: Colors.grey, fontSize: 12),
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
              const SizedBox(width: 16),
              Text(t['iv'] ?? 'IV:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _ivController,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: t['iv_hint'] ?? 'IV (auto padded to 16 chars)',
                      hintStyle:
                          const TextStyle(color: Colors.grey, fontSize: 12),
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
            title: t['aes_cbc_pkcs7'] ?? 'AES (CBC/PKCS7)',
            leftPane: ToolTextField(
                label: t['plaintext'] ?? 'Plaintext',
                controller: _leftController,
                hintText: t['text_to_encrypt'] ?? 'Text to encrypt'),
            rightPane: ToolTextField(
                label: t['ciphertext_base64'] ?? 'Ciphertext (Base64)',
                controller: _rightController,
                hintText: t['base64_ciphertext'] ?? 'Base64 ciphertext'),
            centerControls: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToolButton(onPressed: _encrypt, icon: Icons.arrow_downward, label: t['encrypt'] ?? 'Encrypt'),
                const SizedBox(width: 16),
                ToolButton(onPressed: _decrypt, icon: Icons.arrow_upward, label: t['decrypt'] ?? 'Decrypt'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
