import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/asymmetric/api.dart' as pc;
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// RSA Tool
class RsaTool extends ConsumerStatefulWidget {
  const RsaTool({super.key});
  @override
  ConsumerState<RsaTool> createState() => _RsaToolState();
}

class _RsaToolState extends ConsumerState<RsaTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();
  final TextEditingController _publicKeyController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController();

  void _encrypt() {
    setState(() {
      try {
        final parser = encrypt.RSAKeyParser();
        final publicKey =
            parser.parse(_publicKeyController.text) as pc.RSAPublicKey;
        final encrypter = encrypt.Encrypter(encrypt.RSA(publicKey: publicKey));
        final encrypted = encrypter.encrypt(_leftController.text);
        _rightController.text = encrypted.base64;
      } catch (e) {
        _rightController.text = 'Encryption Error: $e';
      }
    });
  }

  void _decrypt() {
    setState(() {
      try {
        final parser = encrypt.RSAKeyParser();
        final privateKey =
            parser.parse(_privateKeyController.text) as pc.RSAPrivateKey;
        final encrypter =
            encrypt.Encrypter(encrypt.RSA(privateKey: privateKey));
        final decrypted = encrypter.decrypt64(_rightController.text.trim());
        _leftController.text = decrypted;
      } catch (e) {
        _leftController.text = 'Decryption Error: $e';
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['public_key_pem'] ?? 'Public Key (PEM):',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 100,
                      child: TextField(
                        controller: _publicKeyController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: '-----BEGIN PUBLIC KEY-----\n...',
                          hintStyle:
                              const TextStyle(color: Colors.grey, fontSize: 11),
                          border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).dividerColor)),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).dividerColor)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['private_key_pem'] ?? 'Private Key (PEM):',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 100,
                      child: TextField(
                        controller: _privateKeyController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                        decoration: InputDecoration(
                          hintText: '-----BEGIN PRIVATE KEY-----\n...',
                          hintStyle:
                              const TextStyle(color: Colors.grey, fontSize: 11),
                          border: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).dividerColor)),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color: Theme.of(context).dividerColor)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: DualPaneToolWidget(
            title: t['rsa_encrypt_decrypt'] ?? 'RSA Encrypt/Decrypt',
            leftPane:
                ToolTextField(label: 'Plaintext', controller: _leftController),
            rightPane: ToolTextField(
                label: 'Ciphertext (Base64)', controller: _rightController),
            centerControls: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToolButton(onPressed: _encrypt, icon: Icons.arrow_downward, label: 'Encrypt (with Public Key)'),
                const SizedBox(width: 16),
                ToolButton(onPressed: _decrypt, icon: Icons.arrow_upward, label: 'Decrypt (with Private Key)'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
