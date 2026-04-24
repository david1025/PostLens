import 'package:post_lens/core/utils/toast_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/database_helper.dart';
import '../../data/network/certificate_manager.dart';
import '../providers/settings_provider.dart';
import 'certificate_install_dialog.dart';

class CertificateManagementDialog extends ConsumerStatefulWidget {
  const CertificateManagementDialog({super.key});

  @override
  ConsumerState<CertificateManagementDialog> createState() =>
      _CertificateManagementDialogState();
}

class _CertificateManagementDialogState
    extends ConsumerState<CertificateManagementDialog> {
  ManagedCertificateInfo? _info;
  bool _loading = true;
  bool _changed = false;
  bool _isCertInstalled = false;

  Map<String, String> get t => ref.read(translationsProvider);

  @override
  void initState() {
    super.initState();
    _checkCertInstalled();
    _reloadInfo();
  }

  Future<void> _checkCertInstalled() async {
    final val = await DatabaseHelper.instance.getKeyValue('cert_installed');
    if (mounted) {
      setState(() {
        _isCertInstalled = val == 'true';
      });
    }
  }

  Future<void> _reloadInfo() async {
    setState(() {
      _loading = true;
    });
    try {
      final info = await CertificateManager.instance.getCertificateInfo();
      if (!mounted) return;
      setState(() {
        _info = info;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      ToastUtils.showInfo(context, (t['failed_to_load_cert_info'] ?? 'Failed to load certificate info: ') + e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t['install_mitm_root_cert'] ?? '证书管理'),
      content: SizedBox(
        width: 720,
        child: _loading
            ? const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              )
            : _info == null
                ? SizedBox(
                    height: 280,
                    child: Center(child: Text(t['no_certificate_info'] ?? 'No certificate info')),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildAction(
                            label: t['import_certificate'] ?? 'Import Certificate',
                            icon: Icons.download_for_offline_outlined,
                            onPressed: _installCertificate,
                          ),
                          _buildAction(
                            label: t['regenerate_certificate'] ?? 'Regenerate Certificate',
                            icon: Icons.refresh,
                            onPressed: _regenerateCertificate,
                          ),
                          PopupMenuButton<CertificateExportFormat>(
                            tooltip: t['export_certificate'] ?? 'Export Certificate',
                            onSelected: _exportCertificate,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: CertificateExportFormat.crt,
                                child: Text(t['crt'] ?? '导出根公钥证书 (.crt)'),
                              ),
                              PopupMenuItem(
                                value: CertificateExportFormat.pem,
                                child: Text(t['pem'] ?? '导出根公钥证书 (.pem)'),
                              ),
                              PopupMenuItem(
                                value: CertificateExportFormat.zero,
                                child: Text(t['0'] ?? '导出根公钥证书 (.0)'),
                              ),
                              PopupMenuItem(
                                value: CertificateExportFormat.p12,
                                child: Text(t['p12'] ?? '导出根证书 (.p12)'),
                              ),
                            ],
                            child: _buildAction(
                              label: t['export_certificate'] ?? 'Export Certificate',
                              icon: Icons.upload_file_outlined,
                              onPressed: null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoCard(
                                Row(
                                  children: [
                                    Text(t['certificate_info'] ?? 'Certificate Info',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_isCertInstalled)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border:
                                              Border.all(color: Colors.green),
                                        ),
                                        child: Text(t['installed'] ?? 'Installed',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border:
                                              Border.all(color: Colors.orange),
                                        ),
                                        child: Text(t['not_installed'] ?? 'Not Installed',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange),
                                        ),
                                      ),
                                  ],
                                ),
                                [
                                  _infoRow(t['certificate_path'] ?? 'Certificate Path', _info!.certPath),
                                  _infoRow(t['private_key_path'] ?? 'Private Key Path', _info!.keyPath),
                                _infoRow(
                                    t['subject'] ?? 'Subject',
                                    _formatDistinguishedName(
                                        _info!.subject)),
                                _infoRow(
                                    t['issuer'] ?? 'Issuer',
                                    _formatDistinguishedName(
                                        _info!.issuer)),
                                _infoRow(
                                  t['validity'] ?? 'Validity',
                                  '${_formatDate(_info!.notBefore)} - ${_formatDate(_info!.notAfter)}',
                                ),
                                _infoRow('SHA-256', _info!.sha256),
                              ]),
                              const SizedBox(height: 12),
                              _buildPemPreview(_info!.pem),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_changed),
          child: Text(t['close'] ?? '关闭'),
        ),
      ],
    );
  }

  Widget _buildAction({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }

  Widget _buildInfoCard(Widget titleWidget, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPemPreview(String pem) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['pem'] ?? t['pem_preview'] ?? 'PEM Preview',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SelectableText(
            pem,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'IBMPlexMono',
              fontFamilyFallback: ['Monaco', 'Courier New', 'monospace'],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistinguishedName(Map<String, String?> values) {
    return values.entries
        .where((entry) => (entry.value ?? '').isNotEmpty)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(', ');
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return value.toLocal().toString();
  }

  Future<void> _installCertificate() async {
    final info = _info;
    if (info == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CertificateInstallDialog(certPath: info.certPath),
    );
    if (result == true) {
      await DatabaseHelper.instance.setKeyValue('cert_installed', 'true');
      _changed = true;
      if (!mounted) return;
      ToastUtils.showInfo(context, t['certificate_imported_plea'] ?? 'Certificate imported. Please restart your browser.');
    }
  }

  Future<void> _regenerateCertificate() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t['regenerate_root_certifica'] ?? 'Regenerate Root Certificate'),
            content: Text(t['after_regeneration_the_ol'] ?? 'After regeneration, the old certificate will be invalid. Continue?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(t['cancel'] ?? '取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(t['continue'] ?? 'Continue'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      await CertificateManager.instance.regenerateCaCertificate();
      await DatabaseHelper.instance.setKeyValue('cert_installed', 'false');
      _changed = true;
      await _reloadInfo();
      if (!mounted) return;
      ToastUtils.showInfo(context, t['root_certificate_regenera'] ?? 'Root certificate regenerated. Please install and trust it.');
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showInfo(context, (t['failed_to_regenerate_cert'] ?? 'Failed to regenerate certificate: ') + e.toString());
    }
  }

  Future<void> _exportCertificate(CertificateExportFormat format) async {
    final password =
        format == CertificateExportFormat.p12 ? await _askP12Password() : null;
    if (format == CertificateExportFormat.p12 && password == null) {
      return;
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: t['export_root_certificate'] ?? 'Export Root Certificate',
      fileName: _defaultFileName(format),
    );
    if (outputPath == null) {
      return;
    }

    try {
      await CertificateManager.instance.exportCertificate(
        outputPath: outputPath,
        format: format,
        password: password,
      );
      if (!mounted) return;
      ToastUtils.showInfo(context, (t['cert_exported_to'] ?? 'Certificate exported to ') + outputPath);
    } catch (e) {
      if (!mounted) return;
      ToastUtils.showInfo(context, (t['failed_to_export_cert'] ?? 'Failed to export certificate: ') + e.toString());
    }
  }

  Future<String?> _askP12Password() async {
    final t = ref.read(translationsProvider);
    final controller = TextEditingController();
    final password = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t['p12'] ?? '导出 .p12'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(
            labelText: t['export_password'] ?? 'Export Password',
            hintText: t['can_be_empty'] ?? 'Can be empty',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(t['cancel'] ?? '取消'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(controller.text),
            child: Text(t['key_0'] ?? '导出'),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  String _defaultFileName(CertificateExportFormat format) {
    switch (format) {
      case CertificateExportFormat.crt:
        return 'postlens_ca.crt';
      case CertificateExportFormat.pem:
        return 'postlens_ca.pem';
      case CertificateExportFormat.zero:
        return 'postlens_ca.0';
      case CertificateExportFormat.p12:
        return 'postlens_ca.p12';
    }
  }
}
