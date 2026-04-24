import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:post_lens/core/utils/toast_utils.dart';

import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

// Image Tool
class ImageTool extends ConsumerStatefulWidget {
  const ImageTool({super.key});
  @override
  ConsumerState<ImageTool> createState() => _ImageToolState();
}

class _ImageToolState extends ConsumerState<ImageTool> {
  final TextEditingController _leftController = TextEditingController();
  Image? _image;
  Uint8List? _imageBytes;

  void _render() {
    try {
      String base64Str = _leftController.text.trim();
      if (base64Str.isEmpty) return;
      if (base64Str.contains(',')) {
        base64Str = base64Str.split(',').last;
      }
      final bytes = base64.decode(base64Str.replaceAll(RegExp(r'\s+'), ''));
      setState(() {
        _imageBytes = bytes;
        _image = Image.memory(bytes);
      });
    } catch (e) {
      setState(() {
        _imageBytes = null;
        _image = null;
      });
      ToastUtils.showInfo(context, 'Invalid Image Base64: $e');
    }
  }

  Future<void> _exportImage() async {
    if (_imageBytes == null) return;
    try {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Image',
        fileName: 'image.png',
        type: FileType.image,
      );
      if (outputFile != null) {
        if (!outputFile.toLowerCase().endsWith('.png') && 
            !outputFile.toLowerCase().endsWith('.jpg') && 
            !outputFile.toLowerCase().endsWith('.jpeg')) {
          outputFile += '.png';
        }
        await File(outputFile).writeAsBytes(_imageBytes!);
        if (mounted) {
          ToastUtils.showInfo(context, 'Image exported successfully!');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showInfo(context, 'Failed to export image: $e');
      }
    }
  }

  Future<void> _selectImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final bytes = await File(path).readAsBytes();
        final base64Str = base64Encode(bytes);
        String ext = path.split('.').last.toLowerCase();
        if (ext == 'jpg') ext = 'jpeg';
        final mimeType = 'image/$ext';
        
        setState(() {
          _leftController.text = 'data:$mimeType;base64,$base64Str';
          _imageBytes = bytes;
          _image = Image.memory(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showInfo(context, 'Failed to select image: $e');
      }
    }
  }

  @override
  void dispose() {
    _leftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['image_base64'] ?? 'Image <-> Base64',
      leftPane: ToolTextField(
          label: 'Image Base64',
          controller: _leftController,
          hintText: 'data:image/png;base64,iVBORw0KG...'),
      rightPane: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['preview'] ?? 'Preview',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              TextButton.icon(
                onPressed: _imageBytes != null ? _exportImage : null,
                icon: const Icon(Icons.download, size: 16),
                label: Text(t['export_image'] ?? 'Export Image', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
                color: Colors.black12,
              ),
              child: _image != null
                  ? InteractiveViewer(child: _image!)
                  : Center(
                      child: Text(t['no_image_rendered'] ?? 'No Image Rendered',
                          style: const TextStyle(color: Colors.grey, fontSize: 12))),
            ),
          ),
        ],
      ),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolButton(onPressed: _render, icon: Icons.arrow_downward, label: 'Render Image'),
          const SizedBox(width: 16),
          ToolButton(onPressed: _selectImage, icon: Icons.image, label: 'Select Image'),
        ],
      ),
    );
  }
}
