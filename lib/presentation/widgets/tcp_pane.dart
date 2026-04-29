import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/request_provider.dart';
import '../providers/settings_provider.dart';
import 'app_code_editor.dart';
import 'save_request_dialog.dart';
import 'package:post_lens/presentation/widgets/common/custom_controls.dart';

class TcpMessage {
  final String content;
  final bool isSent;
  final DateTime timestamp;
  final bool isSystem;

  TcpMessage(this.content, this.isSent, this.timestamp,
      {this.isSystem = false});
}

class TcpPane extends ConsumerStatefulWidget {
  const TcpPane({super.key});

  @override
  ConsumerState<TcpPane> createState() => _TcpPaneState();
}

class _TcpPaneState extends ConsumerState<TcpPane>
    with SingleTickerProviderStateMixin {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final FocusNode _hostFocusNode = FocusNode();
  final FocusNode _portFocusNode = FocusNode();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  bool _isConnected = false;
  bool _isProtocolHovered = false;
  final List<TcpMessage> _messages = [];

  Socket? _socket;

  // Settings
  bool _receiveHex = false;
  bool _logMode = true;
  bool _autoWrap = false;
  bool _hideReceive = false;
  bool _autoScroll = true;

  bool _sendHex = false;
  bool _parseEscape = true;
  bool _loopSend = false;
  final TextEditingController _loopIntervalController =
      TextEditingController(text: '2000');
  Timer? _loopTimer;

  // Traffic
  int _rxPackets = 0;
  int _txPackets = 0;
  int _rxBytes = 0;
  int _txBytes = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _hostFocusNode.addListener(() => setState(() {}));
    _portFocusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final req = ref.read(requestProvider);
      if (req.url.isNotEmpty) {
        final url = req.url.replaceFirst('tcp://', '');
        final parts = url.split(':');
        _hostController.text = parts[0];
        if (parts.length > 1) {
          _portController.text = parts[1];
        }
      } else {
        _hostController.text = '127.0.0.1';
        _portController.text = '8080';
      }
    });
  }

  @override
  void dispose() {
    _socket?.destroy();
    _loopTimer?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _hostFocusNode.dispose();
    _portFocusNode.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    _loopIntervalController.dispose();
    super.dispose();
  }

  void _toggleConnection() async {
    final t = ref.read(translationsProvider);
    if (_isConnected) {
      _socket?.destroy();
      _loopTimer?.cancel();
      setState(() {
        _isConnected = false;
        _messages.add(TcpMessage(
            t['disconnected'] ?? 'Disconnected', false, DateTime.now(),
            isSystem: true));
      });
    } else {
      try {
        final host = _hostController.text.trim();
        final port = int.tryParse(_portController.text.trim()) ?? 8080;

        ref.read(requestProvider.notifier).updateUrl('tcp://$host:$port');

        _socket = await Socket.connect(host, port,
            timeout: const Duration(seconds: 5));

        setState(() {
          _isConnected = true;
          _messages.add(TcpMessage(
              '${t['connected_to'] ?? 'Connected to'} $host:$port',
              false,
              DateTime.now(),
              isSystem: true));
        });

        _socket!.listen(
          (List<int> data) {
            if (mounted) {
              setState(() {
                _rxPackets++;
                _rxBytes += data.length;
                if (!_hideReceive) {
                  String content = _receiveHex
                      ? data
                          .map((b) =>
                              b.toRadixString(16).padLeft(2, '0').toUpperCase())
                          .join(' ')
                      : utf8.decode(data, allowMalformed: true);
                  _messages.add(TcpMessage(content, false, DateTime.now()));
                }
              });
              if (_autoScroll) _scrollToBottom();
            }
          },
          onError: (error) {
            if (mounted) {
              setState(() {
                _messages.add(TcpMessage(
                    '${t['error'] ?? 'Error'}: $error', false, DateTime.now(),
                    isSystem: true));
                _isConnected = false;
                _loopTimer?.cancel();
              });
              if (_autoScroll) _scrollToBottom();
            }
          },
          onDone: () {
            if (mounted) {
              setState(() {
                if (_isConnected) {
                  _messages.add(TcpMessage(
                      t['connection_closed'] ?? 'Connection closed',
                      false,
                      DateTime.now(),
                      isSystem: true));
                  _isConnected = false;
                  _loopTimer?.cancel();
                }
              });
              if (_autoScroll) _scrollToBottom();
            }
          },
        );
      } catch (e) {
        setState(() {
          _messages.add(TcpMessage(
              '${t['failed_to_connect'] ?? 'Failed to connect'}: $e',
              false,
              DateTime.now(),
              isSystem: true));
        });
      }
    }
  }

  void _sendMessage() {
    if (!_isConnected || _socket == null) return;

    String text = _messageController.text;
    if (text.isEmpty) return;

    if (_parseEscape) {
      text = text
          .replaceAll('\\n', '\n')
          .replaceAll('\\r', '\r')
          .replaceAll('\\t', '\t');
    }

    List<int> data;
    if (_sendHex) {
      try {
        final cleanHex = text.replaceAll(RegExp(r'\s+'), '');
        data = [];
        for (int i = 0; i < cleanHex.length; i += 2) {
          data.add(int.parse(cleanHex.substring(i, i + 2), radix: 16));
        }
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invalid HEX format')));
        return;
      }
    } else {
      data = utf8.encode(text);
    }

    _socket!.add(data);

    setState(() {
      _txPackets++;
      _txBytes += data.length;
      _messages.add(TcpMessage(text, true, DateTime.now()));
    });
    if (_autoScroll) _scrollToBottom();
  }

  void _toggleLoopSend(bool? value) {
    setState(() {
      _loopSend = value ?? false;
      if (_loopSend) {
        final interval = int.tryParse(_loopIntervalController.text) ?? 2000;
        _loopTimer = Timer.periodic(Duration(milliseconds: interval), (timer) {
          _sendMessage();
        });
      } else {
        _loopTimer?.cancel();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetCounters() {
    setState(() {
      _rxPackets = 0;
      _txPackets = 0;
      _rxBytes = 0;
      _txBytes = 0;
    });
  }

  void _showSaveDialog(BuildContext context, var request) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SaveRequestDialog(request: request);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final req = ref.watch(requestProvider);

    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 1,
        dividerHandleBuffer: 10,
        dividerPainter: DividerPainters.background(
          color: Theme.of(context).dividerColor,
          highlightedColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      child: MultiSplitView(
        axis: Axis.vertical,
        initialAreas: [Area(flex: 0.5), Area(flex: 0.5)],
        builder: (context, area) {
          if (area.index == 0) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBar(context, req),
                  const SizedBox(height: 12),
                  _buildConnectionBar(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 32,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: Theme.of(context).colorScheme.secondary,
                      labelColor:
                          Theme.of(context).textTheme.bodyMedium?.color!,
                      unselectedLabelColor: Colors.grey,
                      tabAlignment: TabAlignment.start,
                      labelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
                      dividerColor: Theme.of(context).dividerColor,
                      tabs: [
                        Tab(text: t['message'] ?? 'Message'),
                        Tab(text: t['receive_settings'] ?? 'Receive Settings'),
                        Tab(text: t['send_settings'] ?? 'Send Settings'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMessageTab(),
                        _buildReceiveSettingsTab(),
                        _buildSendSettingsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 20.0),
              child: _buildResponseArea(),
            );
          }
        },
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, var request) {
    final t = ref.watch(translationsProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxNameWidth = (constraints.maxWidth * 0.28)
                  .clamp(140.0, 320.0)
                  .toDouble();
              return Row(
                children: [
                  if (request.folderPath != null &&
                      request.folderPath!.isNotEmpty) ...[
                    const FaIcon(FontAwesomeIcons.networkWired,
                        size: 12, color: Colors.blue),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        request.folderPath!.join(' › '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        tooltip: 'Select Protocol',
                        position: PopupMenuPosition.under,
                        padding: EdgeInsets.zero,
                        color: Theme.of(context).colorScheme.surface,
                        constraints: const BoxConstraints(),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                            width: 1.0,
                          ),
                        ),
                        splashRadius: 16,
                        onSelected: (String value) {
                          ref
                              .read(requestProvider.notifier)
                              .updateProtocol(value);
                        },
                        itemBuilder: (context) => <String>[
                          'http',
                          'grpc',
                          'websocket',
                          'socket.io',
                          'mqtt',
                          'tcp',
                          'udp'
                        ].map((String value) {
                          return PopupMenuItem<String>(
                            value: value,
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                FaIcon(_getProtocolIcon(value),
                                    size: 14, color: _getProtocolColor(value)),
                                const SizedBox(width: 8),
                                Text(value.toUpperCase(),
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                        child: MouseRegion(
                          onEnter: (_) =>
                              setState(() => _isProtocolHovered = true),
                          onExit: (_) =>
                              setState(() => _isProtocolHovered = false),
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            margin: const EdgeInsets.only(right: 8.0),
                            padding: const EdgeInsets.all(6.0),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isProtocolHovered
                                  ? Colors.grey.withOpacity(0.2)
                                  : Colors.transparent,
                            ),
                            child: FaIcon(
                              _getProtocolIcon(request.protocol),
                              size: 14,
                              color: _getProtocolColor(request.protocol),
                            ),
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxNameWidth),
                        child: TextField(
                          controller: TextEditingController(text: request.name)
                            ..selection = TextSelection.collapsed(
                                offset: request.name.length),
                          maxLines: 1,
                          onChanged: (val) => ref
                              .read(requestProvider.notifier)
                              .updateName(val),
                          style: const TextStyle(fontSize: 12),
                          decoration: InputDecoration(
                            hintText:
                                t['untitled_request'] ?? 'Untitled Request',
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.5),
                                  width: 1.0),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.5),
                                  width: 1.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4.0),
                              borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.5),
                                  width: 1.0),
                            ),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.fromLTRB(8, 7, 8, 7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(
          height: 28,
          child: OutlinedButton.icon(
            onPressed: () => _showSaveDialog(context, request),
            icon: const FaIcon(FontAwesomeIcons.floppyDisk, size: 14),
            label:
                Text(t['save'] ?? 'Save', style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
              side: BorderSide(color: Theme.of(context).dividerColor),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getProtocolIcon(String protocol) {
    switch (protocol.toLowerCase()) {
      case 'grpc':
        return FontAwesomeIcons.server;
      case 'websocket':
      case 'ws':
        return FontAwesomeIcons.plug;
      case 'socket.io':
      case 'socket':
        return FontAwesomeIcons.circleNodes;
      case 'mqtt':
        return FontAwesomeIcons.satelliteDish;
      case 'tcp':
        return FontAwesomeIcons.networkWired;
      case 'udp':
        return FontAwesomeIcons.broadcastTower;
      case 'http':
      default:
        return FontAwesomeIcons.globe;
    }
  }

  Color _getProtocolColor(String protocol) {
    switch (protocol.toLowerCase()) {
      case 'grpc':
        return const Color(0xFF2196F3);
      case 'websocket':
      case 'ws':
        return const Color(0xFF9C27B0);
      case 'socket.io':
      case 'socket':
        return const Color(0xFFE91E63);
      case 'mqtt':
        return const Color(0xFFFF9800);
      case 'tcp':
        return const Color(0xFF009688);
      case 'udp':
        return const Color(0xFF3F51B5);
      case 'http':
      default:
        return const Color(0xFF0CBD7D);
    }
  }

  Widget _buildConnectionBar() {
    final t = ref.watch(translationsProvider);
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                  color: _hostFocusNode.hasFocus || _portFocusNode.hasFocus
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _hostController,
                    focusNode: _hostFocusNode,
                    style:
                        const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '127.0.0.1',
                      hintStyle:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    onChanged: (val) {
                      ref
                          .read(requestProvider.notifier)
                          .updateUrl('tcp://$val:${_portController.text}');
                    },
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    focusNode: _portFocusNode,
                    style:
                        const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '8080',
                      hintStyle:
                          const TextStyle(color: Colors.grey, fontSize: 12),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                    ),
                    onChanged: (val) {
                      ref
                          .read(requestProvider.notifier)
                          .updateUrl('tcp://${_hostController.text}:$val');
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 28,
          child: ElevatedButton(
            onPressed:
                _hostController.text.isNotEmpty ? _toggleConnection : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isConnected
                  ? Colors.red
                  : Theme.of(context).colorScheme.secondary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              elevation: 0,
            ),
            child: Row(
              children: [
                Text(
                  _isConnected
                      ? (t['disconnect'] ?? 'Disconnect')
                      : (t['connect'] ?? 'Connect'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.normal,
                      fontSize: 12),
                ),
                if (!_isConnected) ...[
                  const SizedBox(width: 8),
                  const FaIcon(FontAwesomeIcons.envelope,
                      size: 12, color: Colors.white),
                ] else ...[
                  const SizedBox(width: 8),
                  const FaIcon(FontAwesomeIcons.xmark,
                      size: 12, color: Colors.white),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _payloadType = 'Text';

  Widget _buildMessageTab() {
    final t = ref.watch(translationsProvider);
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: AppCodeEditor(
              text: _messageController.text,
              language: _payloadType.toLowerCase(),
              onChanged: (val) {
                _messageController.text = val;
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              PopupMenuButton<String>(
                tooltip: 'Payload Type',
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                constraints: const BoxConstraints(minWidth: 80, maxWidth: 80),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(
                      color: Theme.of(context).dividerColor, width: 1.0),
                ),
                splashRadius: 16,
                onSelected: (String value) {
                  setState(() {
                    _payloadType = value;
                  });
                },
                itemBuilder: (context) =>
                    <String>['Text', 'JSON', 'XML'].map((String value) {
                  return PopupMenuItem<String>(
                    value: value,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (value == _payloadType)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: FaIcon(FontAwesomeIcons.check,
                                size: 12, color: Colors.grey),
                          )
                        else
                          const SizedBox(width: 20),
                        Text(value, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  width: 80,
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _payloadType,
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 12),
                      ),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: OutlinedButton(
                  onPressed: _isConnected ? _sendMessage : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(t['send'] ?? 'Send',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingCheckbox(
      String label, bool value, Function(bool?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CustomCheckbox(
              value: value,
              onChanged: onChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveSettingsTab() {
    final t = ref.watch(translationsProvider);
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildRadioToggle(
          label1: 'ASCII',
          label2: 'HEX',
          value: _receiveHex,
          onChanged: (val) => setState(() => _receiveHex = val),
        ),
        _buildSettingCheckbox(
          t['log_mode'] ?? 'Log mode display',
          _logMode,
          (val) => setState(() => _logMode = val ?? true),
        ),
        _buildSettingCheckbox(
          t['auto_wrap'] ?? 'Auto word wrap',
          _autoWrap,
          (val) => setState(() => _autoWrap = val ?? false),
        ),
        _buildSettingCheckbox(
          t['hide_receive'] ?? 'Do not display received data',
          _hideReceive,
          (val) => setState(() => _hideReceive = val ?? false),
        ),
        _buildSettingCheckbox(
          t['auto_scroll'] ?? 'Auto scroll',
          _autoScroll,
          (val) => setState(() => _autoScroll = val ?? true),
        ),
      ],
    );
  }

  Widget _buildSendSettingsTab() {
    final t = ref.watch(translationsProvider);
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildRadioToggle(
          label1: 'ASCII',
          label2: 'HEX',
          value: _sendHex,
          onChanged: (val) => setState(() => _sendHex = val),
        ),
        _buildSettingCheckbox(
          t['parse_escape'] ?? 'Auto parse escape characters',
          _parseEscape,
          (val) => setState(() => _parseEscape = val ?? true),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CustomCheckbox(
                  value: _loopSend,
                  onChanged: _toggleLoopSend,
                ),
              ),
              const SizedBox(width: 8),
              Text(t['loop_send'] ?? 'Loop send',
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 12)),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                height: 24,
                child: TextField(
                  controller: _loopIntervalController,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  enabled: _loopSend,
                ),
              ),
              const SizedBox(width: 4),
              const Text('ms', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResponseArea() {
    final t = ref.watch(translationsProvider);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              Icon(Icons.circle,
                  size: 10, color: _isConnected ? Colors.green : Colors.grey),
              const SizedBox(width: 4),
              Text(
                  _isConnected
                      ? (t['connected'] ?? 'Connected')
                      : (t['disconnected'] ?? 'Disconnected'),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Spacer(),
              Text(
                '${t['tx_packets'] ?? 'TX Packets'}: $_txPackets  ${t['tx_bytes'] ?? 'TX Bytes'}: $_txBytes  |  ${t['rx_packets'] ?? 'RX Packets'}: $_rxPackets  ${t['rx_bytes'] ?? 'RX Bytes'}: $_rxBytes',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => setState(() => _messages.clear()),
                child: Text(t['clear_log'] ?? 'Clear',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: _resetCounters,
                child: Text(t['reset_count'] ?? 'Reset',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.isSystem)
                        const Icon(Icons.info_outline,
                            size: 14, color: Colors.grey)
                      else if (msg.isSent)
                        const Icon(Icons.arrow_upward,
                            size: 14, color: Colors.orange)
                      else
                        const Icon(Icons.arrow_downward,
                            size: 14, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          msg.content,
                          style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 12,
                              color: msg.isSystem ? Colors.grey : null),
                          softWrap: _autoWrap,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadioToggle(
      {required String label1,
      required String label2,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => onChanged(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: !value
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12)),
                    ),
                    alignment: Alignment.center,
                    child: Text(label1,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
                InkWell(
                  onTap: () => onChanged(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: value
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12)),
                    ),
                    alignment: Alignment.center,
                    child: Text(label2,
                        style: const TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
