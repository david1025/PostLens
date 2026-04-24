import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:post_lens/core/utils/toast_utils.dart';
import '../../providers/settings_provider.dart';

class FileHashTool extends ConsumerStatefulWidget {
  const FileHashTool({super.key});
  @override
  ConsumerState<FileHashTool> createState() => _FileHashToolState();
}

class _FileHashToolState extends ConsumerState<FileHashTool> {
  String? _filePath;
  String _md5Result = '';
  bool _isCalculating = false;

  Future<void> _selectAndCalculate() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        setState(() {
          _filePath = result.files.single.path!;
          _isCalculating = true;
          _md5Result = 'Calculating...';
        });

        // Use Isolate or compute if file is large, but for simplicity we'll just read stream
        final file = File(_filePath!);
        final stream = file.openRead();
        final hash = await md5.bind(stream).first;

        setState(() {
          _isCalculating = false;
          _md5Result = hash.toString();
        });
      }
    } catch (e) {
      setState(() {
        _isCalculating = false;
        _md5Result = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['file_md5_calc'] ?? 'File MD5 Calculation', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isCalculating ? null : _selectAndCalculate,
            icon: const Icon(Icons.file_upload, size: 18),
            label: Text(t['select_file'] ?? 'Select File'),
          ),
          const SizedBox(height: 24),
          if (_filePath != null) ...[
            Text('${t['file_path_label'] ?? 'File Path: '}$_filePath', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Text(t['md5_result_label'] ?? 'MD5 Result:', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(_md5Result, style: const TextStyle(fontFamily: 'Consolas', fontSize: 14)),
                  ),
                  if (!_isCalculating && _md5Result.isNotEmpty && !_md5Result.startsWith('Error'))
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: t['copy'] ?? 'Copy',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _md5Result));
                        ToastUtils.showInfo(context, t['copied'] ?? 'Copied');
                      },
                    ),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
