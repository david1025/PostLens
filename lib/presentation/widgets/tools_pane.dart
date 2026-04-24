import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tools/encode_decode_tools.dart';
import 'tools/hash_tool.dart';
import 'tools/file_hash_tool.dart';
import 'tools/hmac_tool.dart';
import 'tools/aes_tool.dart';
import 'tools/rsa_tool.dart';
import 'tools/sm_tool.dart';
import 'tools/api_signature_tool.dart';
import 'tools/json_tool.dart';
import 'tools/xml_tool.dart';
import 'tools/hex_tool.dart';
import 'tools/image_tool.dart';
import 'tools/other_tools.dart';
import 'tools/color_tool.dart';
import '../providers/settings_provider.dart';

class ToolItem {
  final String id;
  final String name;
  final IconData icon;
  final Widget widget;
  final Color color;
  ToolItem(this.id, this.name, this.icon, this.widget,
      [this.color = Colors.blue]);
}

class ToolCategory {
  final String name;
  final List<ToolItem> items;
  ToolCategory(this.name, this.items);
}

class ToolsData {
  static List<ToolCategory> getCategories(Map<String, String> t) {
    return [
      ToolCategory(t['tool_encode_decode'] ?? 'Encode/Decode', [
        ToolItem('base64', t['tool_base64'] ?? 'Base64', Icons.text_snippet, const Base64Tool(), Colors.blue),
        ToolItem('url', t['tool_url'] ?? 'URL', Icons.link, const UrlTool(), Colors.green),
        ToolItem('jwt', t['tool_jwt'] ?? 'JWT', Icons.security, const JwtTool(), Colors.orange),
        ToolItem('json_escape', t['tool_json_escape'] ?? 'JSON Escape', Icons.data_object, const JsonEscapeTool(), Colors.purple),
      ]),
      ToolCategory(t['tool_encrypt_decrypt'] ?? 'Encrypt/Decrypt', [
        ToolItem('hash', t['tool_hash'] ?? 'Hash', Icons.tag, const HashTool(), Colors.red),
        ToolItem('file_md5', t['tool_file_md5'] ?? 'File MD5', Icons.insert_drive_file, const FileHashTool(), Colors.deepPurple),
        ToolItem('hmac', t['tool_hmac'] ?? 'HMAC', Icons.lock, const HmacTool(), Colors.indigo),
        ToolItem('aes', t['tool_aes'] ?? 'AES', Icons.shield, const AesTool(), Colors.teal),
        ToolItem('rsa', t['tool_rsa'] ?? 'RSA', Icons.key, const RsaTool(), Colors.brown),
        ToolItem('sm', t['tool_sm'] ?? 'SM Algorithms', Icons.verified_user, const SmTool(), Colors.deepOrange),
        ToolItem('api_signature', t['tool_api_signature'] ?? 'API Signature', Icons.assignment_turned_in, const ApiSignatureTool(), Colors.cyan),
      ]),
      ToolCategory(t['tool_view'] ?? 'View', [
        ToolItem('json', t['tool_json'] ?? 'JSON', Icons.data_object, const JsonTool(), Colors.deepPurple),
        ToolItem('xml', t['tool_xml'] ?? 'XML', Icons.code, const XmlTool(), Colors.blueGrey),
        ToolItem('hex', t['tool_hex'] ?? 'Hex', Icons.numbers, const HexTool(), Colors.pink),
        ToolItem('image', t['tool_image'] ?? 'Image', Icons.image, const ImageTool(), Colors.lightBlue),
        ToolItem('color', t['tool_color'] ?? 'Color', Icons.palette, const ColorTool(), Colors.amber),
      ]),
      ToolCategory(t['tool_other'] ?? 'Other', [
        ToolItem('timestamp', t['tool_timestamp'] ?? 'Timestamp', Icons.access_time, const TimestampTool(), Colors.lightGreen),
        ToolItem('uuid', t['tool_uuid'] ?? 'UUID', Icons.fingerprint, const UuidTool(), Colors.lime),
        ToolItem('regex', t['tool_regex'] ?? 'Regex', Icons.rule, const RegexTool(), Colors.orangeAccent),
        ToolItem('qrcode', t['tool_qrcode'] ?? 'QR Code', Icons.qr_code, const QrCodeTool(), Colors.redAccent),
      ]),
    ];
  }

  static ToolItem? getToolById(String id, Map<String, String> t) {
    for (var cat in getCategories(t)) {
      for (var item in cat.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }
}

class ToolsPane extends ConsumerWidget {
  final String toolId;

  const ToolsPane({super.key, required this.toolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final tool = ToolsData.getToolById(toolId, t);

    if (tool == null) {
      return Center(child: Text('Tool not found: $toolId'));
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tool.widget,
    );
  }
}
