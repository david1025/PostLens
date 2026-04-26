import 'package:post_lens/core/utils/toast_utils.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'base_tool_widget.dart';
import '../../providers/settings_provider.dart';

import 'dart:ui' as ui;
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';
import 'package:flutter/services.dart';

import 'dart:async';

// Timestamp Tool
class TimestampTool extends ConsumerStatefulWidget {
  const TimestampTool({super.key});
  @override
  ConsumerState<TimestampTool> createState() => _TimestampToolState();
}

class _TimestampToolState extends ConsumerState<TimestampTool> {
  Timer? _timer;
  bool _isStopped = false;
  bool _isSeconds = true;
  int _currentTimestamp = 0;

  final TextEditingController _tsInput = TextEditingController();
  final TextEditingController _tsOutput = TextEditingController();
  String _tsUnit = 's';
  String _tsTimezone = 'Asia/Shanghai';

  final TextEditingController _dtInput = TextEditingController();
  final TextEditingController _dtOutput = TextEditingController();
  String _dtUnit = 's';
  String _dtTimezone = 'Asia/Shanghai';

  @override
  void initState() {
    super.initState();
    _currentTimestamp = _getNow();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isStopped) {
        setState(() {
          _currentTimestamp = _getNow();
        });
      }
    });
    _dtInput.text = DateTime.now().toString().split('.').first;
    _tsInput.text = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
  }

  int _getNow() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _isSeconds ? now ~/ 1000 : now;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _convertTsToDt() {
    try {
      int val = int.parse(_tsInput.text);
      if (_tsUnit == 's') val *= 1000;
      final dt = DateTime.fromMillisecondsSinceEpoch(val);
      // For simplicity, assuming local time is Asia/Shanghai or just using toLocal()
      _tsOutput.text = dt.toLocal().toString().split('.').first;
    } catch (e) {
      _tsOutput.text = 'Error';
    }
  }

  void _convertDtToTs() {
    try {
      final dt = DateTime.parse(_dtInput.text);
      int val = dt.millisecondsSinceEpoch;
      if (_dtUnit == 's') val ~/= 1000;
      _dtOutput.text = val.toString();
    } catch (e) {
      _dtOutput.text = 'Error';
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
          Text(t['current_timestamp'] ?? 'Current Timestamp',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$_currentTimestamp',
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12)),
              const SizedBox(width: 8),
              Text(
                  _isSeconds
                      ? (t['second_unit'] ?? 'Second')
                      : (t['millisecond_unit'] ?? 'Millisecond'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _isSeconds = !_isSeconds),
                icon: const Icon(Icons.swap_horiz, size: 14),
                label: Text(t['switch_unit'] ?? 'Switch Unit',
                    style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: _currentTimestamp.toString()));
                  ToastUtils.showInfo(context, t['copied'] ?? 'Copied');
                },
                icon: const Icon(Icons.copy, size: 14),
                label: Text(t['copy'] ?? 'Copy',
                    style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _isStopped ? Colors.green : Colors.red),
                onPressed: () => setState(() => _isStopped = !_isStopped),
                icon:
                    Icon(_isStopped ? Icons.play_arrow : Icons.stop, size: 14),
                label: Text(
                    _isStopped
                        ? (t['start'] ?? 'Start')
                        : (t['stop'] ?? 'Stop'),
                    style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          // Simple tabs placeholder
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 2)
                      ],
                    ),
                    child: Center(
                        child: Text(
                            t['single_conversion'] ?? 'Single Conversion',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold))),
                  ),
                ),
                Expanded(
                  child: Center(
                      child: Text(t['batch_conversion'] ?? 'Batch Conversion',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14),
              const SizedBox(width: 8),
              Text(t['ts_to_datetime'] ?? 'Timestamp to DateTime',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _tsInput,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: t['unit'] ?? 'Unit',
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                constraints: const BoxConstraints(minWidth: 130),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                splashRadius: 16,
                onSelected: (String value) {
                  setState(() => _tsUnit = value);
                },
                itemBuilder: (context) => ['s', 'ms'].map((String value) {
                  return PopupMenuItem<String>(
                    value: value,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (value == _tsUnit)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: FaIcon(FontAwesomeIcons.check,
                                size: 12, color: Colors.grey),
                          )
                        else
                          const SizedBox(width: 20),
                        Text(
                          value == 's'
                              ? (t['seconds'] ?? 'Seconds(s)')
                              : (t['milliseconds'] ?? 'Milliseconds(ms)'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tsUnit == 's'
                            ? (t['seconds'] ?? 'Seconds(s)')
                            : (t['milliseconds'] ?? 'Milliseconds(ms)'),
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: _convertTsToDt,
                  child: Text(t['convert'] ?? 'Convert',
                      style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _tsOutput,
                  readOnly: true,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      hintText: t['conversion_result'] ?? 'Conversion Result',
                      hintStyle:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: t['timezone'] ?? 'Timezone',
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                constraints: const BoxConstraints(minWidth: 120),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                splashRadius: 16,
                onSelected: (String value) {
                  setState(() => _tsTimezone = value);
                },
                itemBuilder: (context) =>
                    ['Asia/Shanghai', 'UTC'].map((String value) {
                  return PopupMenuItem<String>(
                    value: value,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (value == _tsTimezone)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: FaIcon(FontAwesomeIcons.check,
                                size: 12, color: Colors.grey),
                          )
                        else
                          const SizedBox(width: 20),
                        Text(
                          value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _tsTimezone,
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14),
              const SizedBox(width: 8),
              Text(t['datetime_to_ts'] ?? 'DateTime to Timestamp',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _dtInput,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: t['timezone'] ?? 'Timezone',
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                constraints: const BoxConstraints(minWidth: 120),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                splashRadius: 16,
                onSelected: (String value) {
                  setState(() => _dtTimezone = value);
                },
                itemBuilder: (context) =>
                    ['Asia/Shanghai', 'UTC'].map((String value) {
                  return PopupMenuItem<String>(
                    value: value,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (value == _dtTimezone)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: FaIcon(FontAwesomeIcons.check,
                                size: 12, color: Colors.grey),
                          )
                        else
                          const SizedBox(width: 20),
                        Text(
                          value,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dtTimezone,
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: _convertDtToTs,
                  child: Text(t['convert'] ?? 'Convert',
                      style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _dtOutput,
                  readOnly: true,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      hintText: t['conversion_result'] ?? 'Conversion Result',
                      hintStyle:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: t['unit'] ?? 'Unit',
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                constraints: const BoxConstraints(minWidth: 130),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                splashRadius: 16,
                onSelected: (String value) {
                  setState(() => _dtUnit = value);
                },
                itemBuilder: (context) => ['s', 'ms'].map((String value) {
                  return PopupMenuItem<String>(
                    value: value,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (value == _dtUnit)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: FaIcon(FontAwesomeIcons.check,
                                size: 12, color: Colors.grey),
                          )
                        else
                          const SizedBox(width: 20),
                        Text(
                          value == 's'
                              ? (t['seconds'] ?? 'Seconds(s)')
                              : (t['milliseconds'] ?? 'Milliseconds(ms)'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dtUnit == 's'
                            ? (t['seconds'] ?? 'Seconds(s)')
                            : (t['milliseconds'] ?? 'Milliseconds(ms)'),
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// UUID Tool
class UuidTool extends ConsumerStatefulWidget {
  const UuidTool({super.key});
  @override
  ConsumerState<UuidTool> createState() => _UuidToolState();
}

class _UuidToolState extends ConsumerState<UuidTool> {
  final TextEditingController _rightController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final _uuid = const Uuid();

  void _generate(int version) {
    int quantity = int.tryParse(_quantityController.text) ?? 1;
    if (quantity < 1) quantity = 1;
    if (quantity > 1000) quantity = 1000;

    List<String> newUuids = [];
    for (int i = 0; i < quantity; i++) {
      newUuids.add(version == 1 ? _uuid.v1() : _uuid.v4());
    }

    setState(() {
      _rightController.text =
          '${newUuids.join('\n')}\n${_rightController.text}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['uuid_generator'] ?? 'UUID Generator',
      leftPane: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Text(t['generate_quantity'] ?? 'Generate Quantity:',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () => _generate(1),
            child: Text(t['generate_uuid_v1_time_bas'] ??
                'Generate UUID v1 (Time-based)'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () => _generate(4),
            child: Text(
                t['generate_uuid_v4_random'] ?? 'Generate UUID v4 (Random)'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontSize: 12),
            ),
            onPressed: () => setState(() => _rightController.clear()),
            child: Text(t['clear'] ?? 'Clear'),
          ),
        ],
      ),
      rightPane: ToolTextField(
          label: t['generated_uuids'] ?? 'Generated UUIDs',
          controller: _rightController,
          readOnly: true),
      centerControls: const SizedBox(),
    );
  }
}

// Regex Tool
class RegexTool extends ConsumerStatefulWidget {
  const RegexTool({super.key});
  @override
  ConsumerState<RegexTool> createState() => _RegexToolState();
}

class _RegexToolState extends ConsumerState<RegexTool> {
  final TextEditingController _leftController = TextEditingController();
  final TextEditingController _patternController = TextEditingController();
  final TextEditingController _rightController = TextEditingController();

  void _testRegex() {
    setState(() {
      try {
        final t = ref.read(translationsProvider);
        final pattern = _patternController.text;
        final text = _leftController.text;
        if (pattern.isEmpty) {
          _rightController.text = t['please_enter_pattern'] ?? 'Please enter a pattern';
          return;
        }
        final regex = RegExp(pattern, multiLine: true);
        final matches = regex.allMatches(text);
        if (matches.isEmpty) {
          _rightController.text = t['no_matches_found'] ?? 'No matches found.';
        } else {
          final buffer = StringBuffer();
          buffer.writeln('${t['found_matches'] ?? 'Found matches:\n'} ${matches.length}:\n');
          for (int i = 0; i < matches.length; i++) {
            final m = matches.elementAt(i);
            buffer
                .writeln('${t['match'] ?? 'Match'} ${i + 1} [${m.start}-${m.end}]: ${m.group(0)}');
            for (int g = 1; g <= m.groupCount; g++) {
              buffer.writeln('  ${t['group'] ?? 'Group'} $g: ${m.group(g)}');
            }
            buffer.writeln();
          }
          _rightController.text = buffer.toString();
        }
      } catch (e) {
        final t = ref.read(translationsProvider);
        _rightController.text = '${t['regex_error'] ?? 'Regex Error: '}$e';
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
              Text(t['pattern'] ?? 'Pattern:',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _patternController,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: r'^([a-z]+)$',
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
            title: t['regex_testing'] ?? 'Regex Testing',
            leftPane:
                ToolTextField(label: t['test_text'] ?? 'Test Text', controller: _leftController),
            rightPane: ToolTextField(
                label: t['matches'] ?? 'Matches', controller: _rightController, readOnly: true),
            centerControls: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ToolButton(
                    onPressed: _testRegex,
                    icon: Icons.arrow_downward,
                    label: t['test_match'] ?? 'Test Match'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// QR Code Tool
class QrCodeTool extends ConsumerStatefulWidget {
  const QrCodeTool({super.key});
  @override
  ConsumerState<QrCodeTool> createState() => _QrCodeToolState();
}

class _QrCodeToolState extends ConsumerState<QrCodeTool> {
  final TextEditingController _leftController = TextEditingController();
  String _qrData = 'https://example.com';

  void _generate() {
    setState(() {
      _qrData = _leftController.text;
    });
  }

  Future<void> _recognizeQr() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final bytes = await File(path).readAsBytes();
        final image = img.decodeImage(bytes);
        if (image != null) {
          final pixels = Int32List(image.width * image.height);
          for (int y = 0; y < image.height; y++) {
            for (int x = 0; x < image.width; x++) {
              final pixel = image.getPixel(x, y);
              pixels[y * image.width + x] = (pixel.a.toInt() << 24) |
                  (pixel.r.toInt() << 16) |
                  (pixel.g.toInt() << 8) |
                  pixel.b.toInt();
            }
          }
          LuminanceSource source =
              RGBLuminanceSource(image.width, image.height, pixels);
          BinaryBitmap bitmap = BinaryBitmap(HybridBinarizer(source));
          Result decodeResult = QRCodeReader().decode(bitmap);
          setState(() {
            _leftController.text = decodeResult.text;
            _qrData = decodeResult.text;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        final t = ref.read(translationsProvider);
        ToastUtils.showInfo(context, '${t['failed_to_recognize_qr'] ?? 'Failed to recognize QR code: '}$e');
      }
    }
  }

  Future<void> _exportQr() async {
    if (_qrData.isEmpty) return;
    try {
      final t = ref.read(translationsProvider);
      final painter = QrPainter(
        data: _qrData,
        version: QrVersions.auto,
        color: const Color(0xff000000),
        emptyColor: const Color(0xffffffff),
        gapless: false,
      );
      final ui.Image image = await painter.toImage(800);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final buffer = byteData.buffer.asUint8List();
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: t['save_qr_code'] ?? 'Save QR Code',
          fileName: 'qrcode.png',
          type: FileType.image,
        );
        if (outputFile != null) {
          if (!outputFile.endsWith('.png')) {
            outputFile += '.png';
          }
          await File(outputFile).writeAsBytes(buffer);
          if (mounted) {
            ToastUtils.showInfo(context, t['qr_code_exported_successfully'] ?? 'QR Code exported successfully!');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final t = ref.read(translationsProvider);
        ToastUtils.showInfo(context, '${t['failed_to_export_qr'] ?? 'Failed to export QR code: '}$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return DualPaneToolWidget(
      title: t['text_to_qrcode'] ?? 'Text <-> QR Code',
      leftPane: ToolTextField(
          label: t['text_url'] ?? 'Text / URL',
          controller: _leftController,
          hintText: t['enter_text_to_generate_qr'] ?? 'Enter text to generate QR code'),
      rightPane: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['qr_code_preview'] ?? 'QR Code Preview',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              TextButton.icon(
                onPressed: _qrData.isNotEmpty ? _exportQr : null,
                icon: const Icon(Icons.download, size: 16),
                label: Text(t['export_image'] ?? 'Export Image',
                    style: TextStyle(fontSize: 12)),
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
                color: Colors.white,
              ),
              child: Center(
                child: _qrData.isNotEmpty
                    ? QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      )
                    : Text(t['no_data'] ?? 'No Data',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
          ),
        ],
      ),
      centerControls: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ToolButton(
              onPressed: _generate,
              icon: Icons.arrow_downward,
              label: t['generate_qr'] ?? 'Generate QR'),
          const SizedBox(width: 16),
          ToolButton(
              onPressed: _recognizeQr,
              icon: Icons.arrow_upward,
              label: t['recognize_qr'] ?? 'Recognize QR'),
        ],
      ),
    );
  }
}
