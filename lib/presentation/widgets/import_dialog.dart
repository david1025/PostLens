import 'package:post_lens/core/utils/toast_utils.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';

import '../../domain/models/collection_model.dart';
import '../../domain/models/http_request_model.dart';
import '../providers/collection_provider.dart';
import '../providers/request_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/settings_provider.dart';
import '../../utils/import_helper.dart';

class ImportDialog extends ConsumerStatefulWidget {
  const ImportDialog({super.key});

  @override
  ConsumerState<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<ImportDialog> {
  final TextEditingController _urlController = TextEditingController();
  bool _isDragging = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _processContent(String content) async {
    try {
      final workspaceId = ref.read(activeWorkspaceProvider).id;
      CollectionModel? collection;
      bool isSwagger = false;

      if (content.contains('"info"') && content.contains('"item"')) {
        collection = ImportHelper.parsePostLensCollection(content, workspaceId);
      } else if (content.contains('"swagger"') ||
          content.contains('"openapi"') ||
          content.contains('swagger:') ||
          content.contains('openapi:')) {
        isSwagger = true;
        collection = ImportHelper.parseSwagger(content, workspaceId);
      }

      if (collection != null) {
        if (isSwagger && collection.children.isEmpty) {
          throw const FormatException('No endpoints found in the API spec');
        }
        await ref.read(collectionsProvider.notifier).addCollection(collection);
        if (mounted) {
          ToastUtils.showSuccess(context, 'Import successful');
          Navigator.of(context).pop();
        }
      } else {
        throw Exception(
            'Unrecognized format. Please provide a valid PostLens or Swagger JSON/YAML content.');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Import failed: $e');
      }
    }
  }

  Future<void> _importFromFile(String filePath) async {
    setState(() => _isLoading = true);
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      await _processContent(content);
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Failed to read file: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'postlens_collection', 'yaml', 'yml'],
    );

    if (result != null && result.files.single.path != null) {
      await _importFromFile(result.files.single.path!);
    }
  }

  Future<void> _pickFolders() async {
    final result = await FilePicker.platform.getDirectoryPath();

    if (result != null) {
      // Typically we'd look for specific files inside, or process a whole folder.
      // For now, let's just pick a single file from the folder, or you can implement folder processing.
      // Because post_lens's import helper expects a single swagger/postlens string.
      // A quick fallback to pick files if the user chose folder.
      ToastUtils.showInfo(context, 'Folder import not fully supported yet, please select a file.');
      await _pickFiles();
    }
  }

  Future<void> _importFromInput(String input) async {
    if (input.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      if (input.startsWith('http://') || input.startsWith('https://')) {
        final request = HttpRequestModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Fetch API Spec',
          method: 'GET',
          url: input,
          protocol: 'http',
        );

        final networkClient = ref.read(networkClientProvider);
        final response = await networkClient.sendRequest(request);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _processContent(response.body);
        } else {
          throw Exception('Failed to fetch URL: ${response.statusCode}');
        }
      } else {
        // Assume it's raw text (JSON/YAML) or cURL.
        // If it's cURL, you might need a cURL parser, but currently the system supports Swagger/PostLens JSON.
        // Let's just pass it to processContent.
        await _processContent(input);
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Import failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return Dialog(
      child: Container(
        width: 700,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t['import_your_api_or_connec'] ?? 'Import your API or connect your local repo',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Input field
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _urlController,
                        onSubmitted: _importFromInput,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          hintText: 'Paste cURL, gRPCurl, Raw text or URL...',
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => _importFromInput(_urlController.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        child: Text(t['import'] ?? 'Import',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Drop zone
            Expanded(
              child: DropTarget(
                onDragDone: (detail) async {
                  if (detail.files.isNotEmpty) {
                    await _importFromFile(detail.files.first.path);
                  }
                },
                onDragEntered: (detail) {
                  setState(() => _isDragging = true);
                },
                onDragExited: (detail) {
                  setState(() => _isDragging = false);
                },
                child: DottedBorder(
                  options: RoundedRectDottedBorderOptions(
                    radius: const Radius.circular(8),
                    color: _isDragging
                        ? Theme.of(context).primaryColor
                        : Colors.grey.withOpacity(0.3),
                    strokeWidth: 2,
                    dashPattern: const [8, 4],
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? Theme.of(context).primaryColor.withOpacity(0.05)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoading)
                          const CircularProgressIndicator()
                        else ...[
                          Icon(
                            FontAwesomeIcons.fileArrowDown,
                            size: 32,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(t['drop_anywhere_to_import'] ?? 'Drop anywhere to import',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(t['or_select'] ?? 'Or select ',
                                style: TextStyle(color: Colors.grey),
                              ),
                              InkWell(
                                onTap: _pickFiles,
                                child: Text(t['files'] ?? 'files',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                              Text(t['or'] ?? ' or ',
                                style: TextStyle(color: Colors.grey),
                              ),
                              InkWell(
                                onTap: _pickFolders,
                                child: Text(t['folders'] ?? 'folders',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
