import 'package:post_lens/core/utils/toast_utils.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/network/certificate_manager.dart';
import '../providers/settings_provider.dart';

class CertificateInstallDialog extends ConsumerWidget {
  // Use the login keychain instead of System keychain. Writing to login keychain
  // doesn't require root (avoids Write permissions error), but marking it as
  // trustRoot will automatically trigger the native macOS Touch ID authorization dialog.
  static String get _macOsLoginKeychainPath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/Keychains/login.keychain-db';
  }

  final String certPath;

  const CertificateInstallDialog({super.key, required this.certPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    String command = _getInstallCommand(t);

    return AlertDialog(
      title: Text(t['install_mitm_root_cert'] ?? 'Install MITM Root Certificate'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t['install_cert_desc'] ?? 'To decrypt HTTPS requests, you need to install and trust our root certificate in the system. Please perform the following steps:',
            ),
            const SizedBox(height: 16),
            Text(t['cert_path'] ?? 'Certificate Path:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(certPath,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            const SizedBox(height: 16),
            Text(t['install_trust_command'] ?? 'Install and Trust Command:',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      command,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: command));
                      ToastUtils.showInfo(context, t['command_copied'] ?? 'Command copied to clipboard');
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t['install_cert_hint'] ?? 'Hint: After completion, you may need to restart the browser or related applications for the certificate to take effect.',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t['close'] ?? 'Close'),
        ),
        ElevatedButton(
          onPressed: () => _executeInstallCommand(context, command, t),
          child: Text(t['auto_execute_command'] ?? 'Auto Execute (Requires privileges)'),
        ),
      ],
    );
  }

  String _getInstallCommand(Map<String, String> t) {
    if (Platform.isMacOS) {
      return _buildMacOsInstallCommand(forShell: true);
    } else if (Platform.isWindows) {
      return 'certutil -addstore -f root "$certPath"';
    } else if (Platform.isLinux) {
      return 'sudo cp "$certPath" /usr/local/share/ca-certificates/mitm_proxy.crt && sudo update-ca-certificates';
    }
    return t['auto_command_not_supported'] ?? 'Auto command generation is not supported for this OS currently';
  }

  Future<void> _executeInstallCommand(
      BuildContext context, String command, Map<String, String> t) async {
    Directory? tempDir;
    try {
      ProcessResult result;
      if (Platform.isMacOS) {
        tempDir = await Directory.systemTemp.createTemp('postlens-ca-');
        final tempCertPath = '${tempDir.path}/ca.crt';
        var sourceCertPath = certPath;
        if (!await File(sourceCertPath).exists()) {
          sourceCertPath = await CertificateManager.instance.localCertPath;
        }
        await File(sourceCertPath).copy(tempCertPath);

        // Use the native `security` tool directly so macOS shows the
        // system authorization sheet for certificate trust changes.
        result = await Process.run('security', [
            'add-trusted-cert',
            '-r',
            'trustRoot',
            '-k',
            _macOsLoginKeychainPath,
            tempCertPath,
          ]);
      } else if (Platform.isWindows) {
        final args = '-addstore -f root "$certPath"';
        result = await Process.run('powershell', [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-Command',
          'Start-Process',
          '-FilePath',
          'certutil',
          '-ArgumentList',
          "'$args'",
          '-Verb',
          'RunAs',
          '-Wait'
        ]);
      } else {
        ToastUtils.showInfo(context, t['linux_manual_execute'] ?? 'For Linux, please execute the above command manually in the terminal');
        return;
      }

      if (!context.mounted) return;
      if (result.exitCode == 0) {
        ToastUtils.showInfo(context, t['cert_install_success'] ?? 'Certificate installed successfully!');
        Navigator.of(context).pop(true);
      } else {
        final errorMessage = '${result.stderr}\n${result.stdout}'.trim();
        throw Exception(errorMessage.isEmpty ? 'security add-trusted-cert failed' : errorMessage);
      }
    } catch (e) {
      if (!context.mounted) return;
      ToastUtils.showInfo(context, '${t['install_failed'] ?? 'Installation failed:'} $e');
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  String _buildMacOsInstallCommand({required bool forShell}) {
    final home = Platform.environment['HOME'] ?? '~';
    final keychainPath = '$home/Library/Keychains/login.keychain-db';
    return 'security add-trusted-cert -r trustRoot -k '
        '"$keychainPath" "$certPath"';
  }
}
