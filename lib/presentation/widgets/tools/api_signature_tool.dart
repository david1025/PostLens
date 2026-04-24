import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/asymmetric/api.dart' as pc;
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';
import 'package:post_lens/presentation/widgets/common/custom_controls.dart';

enum KeySource { certificate, text }
enum SignType { rsa, rsa2 }
enum Charset { utf8 }

class ApiSignatureTool extends ConsumerStatefulWidget {
  const ApiSignatureTool({super.key});
  @override
  ConsumerState<ApiSignatureTool> createState() => _ApiSignatureToolState();
}

class _ApiSignatureToolState extends ConsumerState<ApiSignatureTool> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign Tab
  KeySource _signKeySource = KeySource.text;
  String? _signCertPath;
  final TextEditingController _signCertPasswordController = TextEditingController();
  final TextEditingController _signKeyTextController = TextEditingController();
  final TextEditingController _signParamsController = TextEditingController();
  final TextEditingController _signOutputController = TextEditingController();
  SignType _signType = SignType.rsa2;

  // Verify Tab
  KeySource _verifyKeySource = KeySource.text;
  String? _verifyCertPath;
  final TextEditingController _verifyKeyTextController = TextEditingController();
  final TextEditingController _verifyParamsController = TextEditingController();
  final TextEditingController _verifySignController = TextEditingController();
  final TextEditingController _verifyOutputController = TextEditingController();
  SignType _verifyType = SignType.rsa2;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatParams(String input) {
    try {
      final Map<String, dynamic> params = json.decode(input);
      final sortedKeys = params.keys.toList()..sort();
      final buffer = StringBuffer();
      for (var key in sortedKeys) {
        if (key == 'sign') continue; // exclude sign field if present
        buffer.write('$key=${params[key]}&');
      }
      String signStr = buffer.toString();
      if (signStr.isNotEmpty) {
        signStr = signStr.substring(0, signStr.length - 1);
      }
      return signStr;
    } catch (e) {
      // Not JSON, return as is
      return input;
    }
  }

  pc.RSAPrivateKey? _getPrivateKey(KeySource source, String? path, String password, String text) {
    final t = ref.read(translationsProvider);
    if (source == KeySource.text) {
      if (text.isEmpty) throw Exception(t['api_sign_error_private_key_empty'] ?? 'Private key text is empty');
      return CryptoUtils.rsaPrivateKeyFromPem(text);
    } else {
      if (path == null || path.isEmpty) throw Exception(t['api_sign_error_cert_not_selected'] ?? 'Certificate file not selected');
      final file = File(path);
      final bytes = file.readAsBytesSync();
      if (path.toLowerCase().endsWith('.p12')) {
        final p12 = Pkcs12Utils.parsePkcs12(bytes, password: password.isEmpty ? null : password);
        if (p12.isNotEmpty) {
          return CryptoUtils.rsaPrivateKeyFromPem(p12[0]);
        }
        throw Exception(t['api_sign_error_no_private_key_p12'] ?? 'No private key found in P12');
      } else {
        final pem = String.fromCharCodes(bytes);
        return CryptoUtils.rsaPrivateKeyFromPem(pem);
      }
    }
  }

  pc.RSAPublicKey? _getPublicKey(KeySource source, String? path, String text) {
    final t = ref.read(translationsProvider);
    if (source == KeySource.text) {
      if (text.isEmpty) throw Exception(t['api_sign_error_public_key_empty'] ?? 'Public key text is empty');
      return CryptoUtils.rsaPublicKeyFromPem(text);
    } else {
      if (path == null || path.isEmpty) throw Exception(t['api_sign_error_cert_not_selected'] ?? 'Certificate file not selected');
      final file = File(path);
      final bytes = file.readAsBytesSync();
      if (path.toLowerCase().endsWith('.p12')) {
        // usually p12 is for private key, but if they want public key from it we can try to extract from cert
        final p12 = Pkcs12Utils.parsePkcs12(bytes);
        if (p12.isNotEmpty) {
          final privKey = CryptoUtils.rsaPrivateKeyFromPem(p12[0]);
          if (privKey.publicExponent != null) {
            return pc.RSAPublicKey(privKey.modulus!, privKey.publicExponent!);
          }
        }
        throw Exception(t['api_sign_error_no_public_key_p12'] ?? 'No valid public key found in P12');
      } else {
        final pem = String.fromCharCodes(bytes);
        return CryptoUtils.rsaPublicKeyFromPem(pem);
      }
    }
  }

  void _sign() {
    setState(() {
      try {
        final plainText = _formatParams(_signParamsController.text);
        final privateKey = _getPrivateKey(_signKeySource, _signCertPath, _signCertPasswordController.text, _signKeyTextController.text);
        
        final algorithm = _signType == SignType.rsa2 ? 'SHA-256/RSA' : 'SHA-1/RSA';
        final signatureBytes = CryptoUtils.rsaSign(privateKey!, Uint8List.fromList(utf8.encode(plainText)), algorithmName: algorithm);
        _signOutputController.text = base64Encode(signatureBytes);
      } catch (e) {
        _signOutputController.text = 'Error: $e';
      }
    });
  }

  void _verify() {
    final t = ref.read(translationsProvider);
    setState(() {
      try {
        String plainText;
        String signToVerify = _verifySignController.text;
        
        try {
          final Map<String, dynamic> params = json.decode(_verifyParamsController.text);
          if (params.containsKey('sign') && signToVerify.isEmpty) {
            signToVerify = params['sign'].toString();
          }
          plainText = _formatParams(_verifyParamsController.text);
        } catch (_) {
          plainText = _verifyParamsController.text;
        }

        if (signToVerify.isEmpty) {
          throw Exception(t['api_sign_error_signature_empty'] ?? 'Signature to verify is empty');
        }

        final publicKey = _getPublicKey(_verifyKeySource, _verifyCertPath, _verifyKeyTextController.text);
        final algorithm = _verifyType == SignType.rsa2 ? 'SHA-256/RSA' : 'SHA-1/RSA';
        
        final signatureBytes = base64Decode(signToVerify);
        final isValid = CryptoUtils.rsaVerify(publicKey!, Uint8List.fromList(utf8.encode(plainText)), signatureBytes, algorithm: algorithm);
        
        _verifyOutputController.text = isValid ? (t['api_sign_verify_success'] ?? 'Verify Success (验签成功)') : (t['api_sign_verify_failed'] ?? 'Verify Failed (验签失败)');
      } catch (e) {
        _verifyOutputController.text = 'Error: $e';
      }
    });
  }

  Future<void> _pickSignFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['p12', 'pem', 'crt', 'key'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _signCertPath = result.files.single.path;
      });
    }
  }

  Future<void> _pickVerifyFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['p12', 'pem', 'crt', 'key'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _verifyCertPath = result.files.single.path;
      });
    }
  }

  Widget _buildPrimaryButton({required VoidCallback onPressed, required IconData icon, required String label}) {
    return SizedBox(
      height: 28,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.normal)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.secondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({required VoidCallback onPressed, required IconData icon, required String label}) {
    return SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
          side: BorderSide(color: Theme.of(context).dividerColor),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildKeySourceSection({
    required KeySource source,
    required ValueChanged<KeySource?> onChanged,
    required String? certPath,
    required VoidCallback onPickFile,
    required TextEditingController textController,
    required String textLabel,
    TextEditingController? passwordController,
  }) {
    final t = ref.watch(translationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CustomRadio<KeySource>(
              value: KeySource.certificate,
              groupValue: source,
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            Text(t['api_sign_cert_file'] ?? 'Certificate File', style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 16),
            CustomRadio<KeySource>(
              value: KeySource.text,
              groupValue: source,
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            Text(t['api_sign_key_text'] ?? 'Key Text', style: const TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        if (source == KeySource.certificate)
          Row(
            children: [
              SizedBox(
                height: 28,
                child: ElevatedButton(
                  onPressed: onPickFile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 0,
                  ),
                  child: Text(t['api_sign_choose_file'] ?? 'Choose File', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.normal)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(certPath ?? (t['api_sign_no_file_selected'] ?? 'No file selected'), style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (passwordController != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  height: 28,
                  child: TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: t['api_sign_password'] ?? 'Password',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4.0),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.5), width: 1.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4.0),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.5), width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4.0),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.5), width: 1.0),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                    ),
                  ),
                ),
              ],
            ],
          )
        else
          SizedBox(
            height: 100,
            child: ToolTextField(
              label: textLabel,
              controller: textController,
            ),
          ),
      ],
    );
  }

  Widget _buildSignTab() {
    final t = ref.watch(translationsProvider);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKeySourceSection(
            source: _signKeySource,
            onChanged: (v) => setState(() => _signKeySource = v!),
            certPath: _signCertPath,
            onPickFile: _pickSignFile,
            textController: _signKeyTextController,
            textLabel: t['api_sign_app_private_key'] ?? 'Application Private Key (PEM)',
            passwordController: _signCertPasswordController,
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: ToolTextField(
              label: t['api_sign_params'] ?? 'Parameters (JSON) / Plaintext',
              controller: _signParamsController,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(t['api_sign_charset'] ?? 'Charset: ', style: const TextStyle(fontSize: 12)),
              CustomRadio<Charset>(value: Charset.utf8, groupValue: Charset.utf8, onChanged: (v) {}),
              const SizedBox(width: 8),
              const Text('UTF-8', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 24),
              Text(t['api_sign_type'] ?? 'Sign Type: ', style: const TextStyle(fontSize: 12)),
              CustomRadio<SignType>(value: SignType.rsa2, groupValue: _signType, onChanged: (v) => setState(() => _signType = v!)),
              const SizedBox(width: 8),
              const Text('RSA2', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              CustomRadio<SignType>(value: SignType.rsa, groupValue: _signType, onChanged: (v) => setState(() => _signType = v!)),
              const SizedBox(width: 8),
              const Text('RSA', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPrimaryButton(onPressed: _sign, icon: Icons.edit_document, label: t['api_sign_start_sign'] ?? 'Sign'),
              const SizedBox(width: 16),
              _buildSecondaryButton(
                onPressed: () {
                  _signParamsController.clear();
                  _signOutputController.clear();
                },
                icon: Icons.refresh,
                label: t['reset'] ?? 'Reset'
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: ToolTextField(
              label: t['api_sign_signature_result'] ?? 'Signature Result',
              controller: _signOutputController,
              readOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerifyTab() {
    final t = ref.watch(translationsProvider);
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKeySourceSection(
            source: _verifyKeySource,
            onChanged: (v) => setState(() => _verifyKeySource = v!),
            certPath: _verifyCertPath,
            onPickFile: _pickVerifyFile,
            textController: _verifyKeyTextController,
            textLabel: t['api_sign_platform_public_key'] ?? 'Platform Public Key (PEM)',
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: ToolTextField(
              label: t['api_sign_notify_params'] ?? 'Notification Params (JSON) / Plaintext',
              controller: _verifyParamsController,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 1,
            child: ToolTextField(
              label: t['api_sign_signature_to_verify'] ?? 'Signature to Verify',
              controller: _verifySignController,
              hintText: t['api_sign_signature_to_verify_hint'] ?? 'If JSON contains "sign", this can be empty.',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(t['api_sign_charset'] ?? 'Charset: ', style: const TextStyle(fontSize: 12)),
              CustomRadio<Charset>(value: Charset.utf8, groupValue: Charset.utf8, onChanged: (v) {}),
              const SizedBox(width: 8),
              const Text('UTF-8', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 24),
              Text(t['api_sign_type'] ?? 'Sign Type: ', style: const TextStyle(fontSize: 12)),
              CustomRadio<SignType>(value: SignType.rsa2, groupValue: _verifyType, onChanged: (v) => setState(() => _verifyType = v!)),
              const SizedBox(width: 8),
              const Text('RSA2', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              CustomRadio<SignType>(value: SignType.rsa, groupValue: _verifyType, onChanged: (v) => setState(() => _verifyType = v!)),
              const SizedBox(width: 8),
              const Text('RSA', style: TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPrimaryButton(onPressed: _verify, icon: Icons.verified_user, label: t['api_sign_start_verify'] ?? 'Verify'),
              const SizedBox(width: 16),
              _buildSecondaryButton(
                onPressed: () {
                  _verifyParamsController.clear();
                  _verifySignController.clear();
                  _verifyOutputController.clear();
                },
                icon: Icons.refresh,
                label: t['reset'] ?? 'Reset'
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: ToolTextField(
              label: t['api_sign_verification_result'] ?? 'Verification Result',
              controller: _verifyOutputController,
              readOnly: true,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return Column(
      children: [
        SizedBox(
          height: 32,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Theme.of(context).colorScheme.secondary,
            labelColor: Theme.of(context).textTheme.bodyMedium!.color!,
            unselectedLabelColor: Colors.grey,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            dividerColor: Theme.of(context).dividerColor,
            tabs: [
              Tab(text: t['api_sign_tab_sign'] ?? 'Sign'),
              Tab(text: t['api_sign_tab_verify'] ?? 'Verify'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSignTab(),
              _buildVerifyTab(),
            ],
          ),
        ),
      ],
    );
  }
}
