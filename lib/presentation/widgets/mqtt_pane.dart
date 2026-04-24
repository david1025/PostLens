import 'package:flutter/material.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shared_dynamic_table.dart';
import 'table_cell_text_field.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'app_code_editor.dart';

import '../providers/request_provider.dart';
import '../providers/settings_provider.dart';
import 'save_request_dialog.dart';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:post_lens/presentation/widgets/common/custom_controls.dart';

class AppMqttMessage {
  final String topic;
  final String content;
  final bool isSent;
  final DateTime timestamp;

  AppMqttMessage(this.topic, this.content, this.isSent, this.timestamp);
}

class MqttPane extends ConsumerStatefulWidget {
  const MqttPane({super.key});

  @override
  ConsumerState<MqttPane> createState() => _MqttPaneState();
}

class _MqttPaneState extends ConsumerState<MqttPane>
    with TickerProviderStateMixin {
  static const double _compactTableRowHeight = 28;
  static const double _compactTableOuterHorizontalPadding = 6;
  static const double _compactTableCellHorizontalPadding = 4;
  static const double _compactTableColumnGap = 6;
  static const double _compactTableSideSlotWidth = 28;
  static const double _compactTableLeadingSlotWidth = 22;
  static const double _compactSectionTopSpacing = 12;
  static const double _compactSectionLabelGap = 6;

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isConnected = false;
  bool _isProtocolHovered = false;

  final List<AppMqttMessage> _messages = [];

  MqttServerClient? _client;

  late TabController _tabController;

  String _mqttVersion = '5';
  String _authType = 'No Auth';

  bool _enableCertVerification = false;
  bool _cleanSession = true;
  final TextEditingController _sessionExpiryController = TextEditingController();
  final TextEditingController _keepAliveController = TextEditingController(text: '60');
  bool _autoReconnect = false;
  final TextEditingController _connectionTimeoutController = TextEditingController(text: '30');
  final TextEditingController _receiveMaximumController = TextEditingController();
  final TextEditingController _maxPacketSizeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _urlFocusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final req = ref.read(requestProvider);
      if (req.url.isNotEmpty) {
        _urlController.text = req.url;
      }
    });
  }

  @override
  void dispose() {
    _client?.disconnect();
    _urlController.dispose();
    _urlFocusNode.dispose();
    _msgTopicController.dispose();
    _payloadController.dispose();
    _msgTopicAliasController.dispose();
    _msgResponseTopicController.dispose();
    _msgCorrelationDataController.dispose();
    _msgExpiryIntervalController.dispose();
    _msgContentTypeController.dispose();
    _willTopicController.dispose();
    _willPayloadController.dispose();
    _sessionExpiryController.dispose();
    _keepAliveController.dispose();
    _connectionTimeoutController.dispose();
    _receiveMaximumController.dispose();
    _maxPacketSizeController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleConnection() async {
    final t = ref.read(translationsProvider);
    if (_isConnected) {
      _client?.disconnect();
      setState(() {
        _isConnected = false;
        for (var topic in _topicsList) {
          topic['subscribe'] = false;
        }
        _messages.add(AppMqttMessage("system",
            t['disconnected'] ?? 'Disconnected', false, DateTime.now()));
      });
    } else {
      try {
        final url = _urlController.text;
        final host = url.split(':').first;
        final port = int.tryParse(url.split(':').last) ?? 1883;

        _client = MqttServerClient(
            host, 'post_lens_${DateTime.now().millisecondsSinceEpoch}');
        _client!.port = port;
        _client!.logging(on: false);
        _client!.keepAlivePeriod = int.tryParse(_keepAliveController.text) ?? 60;
        _client!.autoReconnect = _autoReconnect;
        _client!.connectTimeoutPeriod = (int.tryParse(_connectionTimeoutController.text) ?? 30) * 1000;
        
        if (url.startsWith('mqtts://') || url.startsWith('ssl://') || url.startsWith('wss://')) {
          _client!.secure = true;
          if (!_enableCertVerification) {
            _client!.onBadCertificate = (dynamic cert) => true;
          }
        }

        final connMess = MqttConnectMessage()
            .withClientIdentifier(
                'post_lens_${DateTime.now().millisecondsSinceEpoch}');

        if (_willTopicController.text.isNotEmpty && _willPayloadController.text.isNotEmpty) {
          MqttQos qosLevel = MqttQos.values.firstWhere((e) => e.index == _willQos, orElse: () => MqttQos.atLeastOnce);
          connMess.withWillTopic(_willTopicController.text)
                  .withWillMessage(_willPayloadController.text)
                  .withWillQos(qosLevel);
          if (_willRetain) {
            connMess.withWillRetain();
          }
        }
            
        if (_cleanSession) {
          connMess.startClean(); // Starts a clean session
        }

        // MQTT 5 specific properties (Session Expiry, Receive Maximum, Maximum Packet Size) 
        // are not natively supported in the current version of the mqtt_client library's connection flow.
        // If these features are needed, consider migrating to mqtt5_client package.
        
        _client!.connectionMessage = connMess;

        await _client!.connect();

        if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
          setState(() {
            _isConnected = true;
            _messages.add(AppMqttMessage(
                "system",
                '${t['connected_to'] ?? 'Connected to broker'} $host:$port',
                false,
                DateTime.now()));
          });

          // Subscribe to already checked topics
          for (var topicMap in _topicsList) {
            if (topicMap['subscribe'] == true) {
              final topic = topicMap['topic'];
              if (topic != null && topic.isNotEmpty) {
                MqttQos qosLevel = MqttQos.values.firstWhere(
                    (e) => e.index == (topicMap['qos'] ?? 0),
                    orElse: () => MqttQos.atLeastOnce);
                _client!.subscribe(topic, qosLevel);
                setState(() {
                  _messages.add(AppMqttMessage(
                      "system",
                      '${t['subscribed_to'] ?? 'Subscribed to'} $topic',
                      false,
                      DateTime.now()));
                });
              }
            }
          }

          _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
            final recMess = c[0].payload as MqttPublishMessage;
            final pt = MqttPublishPayload.bytesToStringAsString(
                recMess.payload.message);
            if (mounted) {
              setState(() {
                _messages
                    .add(AppMqttMessage(c[0].topic, pt, false, DateTime.now()));
              });
              _scrollToBottom();
            }
          });
        } else {
          _client!.disconnect();
          setState(() {
            _messages.add(AppMqttMessage(
                "system",
                t['failed_to_connect'] ?? 'Failed to connect',
                false,
                DateTime.now()));
          });
        }
      } catch (e) {
        setState(() {
          _messages.add(AppMqttMessage("system",
              '${t['connect_error'] ?? 'Error'}: $e', false, DateTime.now()));
        });
      }
    }
    _scrollToBottom();
  }

  void _toggleSubscription(Map<String, dynamic> topicMap) {
    final t = ref.read(translationsProvider);
    final topic = topicMap['topic'];
    if (topic.isEmpty || !_isConnected || _client == null) return;

    setState(() {
      if (topicMap['subscribe']) {
        _client!.unsubscribe(topic);
        topicMap['subscribe'] = false;
        _messages.add(AppMqttMessage(
            "system",
            '${t['unsubscribed_from'] ?? 'Unsubscribed from'} $topic',
            false,
            DateTime.now()));
      } else {
        MqttQos qosLevel = MqttQos.values.firstWhere(
            (e) => e.index == (topicMap['qos'] ?? 0),
            orElse: () => MqttQos.atLeastOnce);
        _client!.subscribe(topic, qosLevel);
        topicMap['subscribe'] = true;
        _messages.add(AppMqttMessage(
            "system",
            '${t['subscribed_to'] ?? 'Subscribed to'} $topic',
            false,
            DateTime.now()));
      }
    });
    _scrollToBottom();
  }

  void _sendMessage() {
    final topic = _msgTopicController.text;
    final text = _payloadController.text;
    if (text.isEmpty || !_isConnected || topic.isEmpty || _client == null)
      return;

    setState(() {
      _messages.add(AppMqttMessage(topic, text, true, DateTime.now()));
      _payloadController.clear();

      final builder = MqttClientPayloadBuilder();
      builder.addString(text);
      MqttQos qosLevel = MqttQos.values.firstWhere((e) => e.index == _msgQos,
          orElse: () => MqttQos.atLeastOnce);
      _client!.publishMessage(topic, qosLevel, builder.payload!,
          retain: _msgRetain);
    });
    _scrollToBottom();
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
    final request = ref.watch(requestProvider);
    final t = ref.watch(translationsProvider);
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
                  _buildHeaderBar(context, request),
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
                        Tab(text: t['topics'] ?? 'Topics'),
                        Tab(text: t['authorization'] ?? 'Authorization'),
                        Tab(text: t['properties'] ?? 'Properties'),
                        Tab(text: t['last_will'] ?? 'Last Will'),
                        Tab(text: t['settings'] ?? 'Settings'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMessageTab(),
                        SingleChildScrollView(child: _buildTopicsTab()),
                        SingleChildScrollView(child: _buildAuthorizationTab()),
                        SingleChildScrollView(child: _buildPropertiesTab()),
                        _buildLastWillTab(),
                        _buildSettingsTab(),
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
          child: Row(
            children: [
              if (request.folderPath != null &&
                  request.folderPath!.isNotEmpty) ...[
                const FaIcon(FontAwesomeIcons.networkWired,
                    size: 12, color: Colors.blue),
                const SizedBox(width: 8),
                for (int i = 0; i < request.folderPath!.length; i++) ...[
                  Text(
                    request.folderPath![i],
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child:
                        Icon(Icons.chevron_right, size: 12, color: Colors.grey),
                  ),
                ],
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
                      ref.read(requestProvider.notifier).updateProtocol(value);
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
                      onEnter: (_) => setState(() => _isProtocolHovered = true),
                      onExit: (_) => setState(() => _isProtocolHovered = false),
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
                  IntrinsicWidth(
                    child: TextField(
                      controller: TextEditingController(text: request.name)
                        ..selection = TextSelection.collapsed(
                            offset: request.name.length),
                      onChanged: (val) =>
                          ref.read(requestProvider.notifier).updateName(val),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: t['untitled_request'] ?? 'Untitled Request',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.5), width: 1.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.5), width: 1.0),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4.0),
                          borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.5), width: 1.0),
                        ),
                        isDense: true,
                        contentPadding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
            height: _compactTableRowHeight,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                  color: _urlFocusNode.hasFocus
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  tooltip: 'MQTT Version',
                  position: PopupMenuPosition.under,
                  padding: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.surface,
                  constraints: const BoxConstraints(minWidth: 80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    side: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1.0,
                    ),
                  ),
                  splashRadius: 16,
                  onSelected: (String value) {
                    setState(() {
                      _mqttVersion = value;
                    });
                  },
                  itemBuilder: (context) => <String>['3.1.1', '5']
                      .map((String value) {
                    return PopupMenuItem<String>(
                        value: value,
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                        children: [
                          if (value == _mqttVersion)
                            const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: FaIcon(FontAwesomeIcons.check,
                                  size: 12, color: Colors.grey),
                            )
                          else
                            const SizedBox(width: 20),
                          Text(
                            value == '5' ? 'V5' : value,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  child: Container(
                    width: 80,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _mqttVersion == '5' ? 'V5' : _mqttVersion,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 12,
                          ),
                        ),
                        const FaIcon(FontAwesomeIcons.chevronDown,
                            size: 10, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    style:
                        const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                    decoration: InputDecoration(
                      hintText:
                          t['mqtt_url_hint'] ?? 'mqtt://broker.hivemq.com:1883',
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
                      ref.read(requestProvider.notifier).updateUrl(val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: _compactTableRowHeight,
          child: ElevatedButton(
            onPressed:
                _urlController.text.isNotEmpty ? _toggleConnection : null,
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
  bool _msgRetain = false;
  int _msgQos = 0;
  final TextEditingController _msgTopicController = TextEditingController();
  final TextEditingController _payloadController = TextEditingController();
  bool _isResponseExpanded = true;

  // Additional settings for Publish
  final TextEditingController _msgTopicAliasController = TextEditingController();
  final TextEditingController _msgResponseTopicController = TextEditingController();
  final TextEditingController _msgCorrelationDataController = TextEditingController();
  final TextEditingController _msgExpiryIntervalController = TextEditingController();
  final TextEditingController _msgContentTypeController = TextEditingController();
  bool _msgPayloadFormatIndicator = false;
  final List<Map<String, String>> _msgPropertiesList = [];

  void _showMoreSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              alignment: Alignment.center,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Properties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              _msgPropertiesList.add({'key': '', 'value': ''});
                            });
                            setState(() {});
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.add, size: 16, color: Colors.grey),
                          ),
                        ),
                        const Spacer(),
                        const Text('Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const Divider(),
                    ..._msgPropertiesList.asMap().entries.map((entry) {
                      int i = entry.key;
                      Map<String, String> prop = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 28,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TableCellTextField(
                                  text: prop['key'] ?? '',
                                  hint: 'Property',
                                  onChanged: (val) {
                                    prop['key'] = val;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Theme.of(context).dividerColor),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: TableCellTextField(
                                        text: prop['value'] ?? '',
                                        hint: 'Value',
                                        onChanged: (val) {
                                          prop['value'] = val;
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        _msgPropertiesList.removeAt(i);
                                      });
                                      setState(() {});
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.close, size: 14, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TableCellTextField(
                                text: '',
                                hint: 'Add property',
                                onChanged: (val) {
                                  if (val.isNotEmpty) {
                                    setDialogState(() {
                                      _msgPropertiesList.add({'key': val, 'value': ''});
                                    });
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 28,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: TableCellTextField(
                                      text: '',
                                      hint: 'Add Value',
                                      onChanged: (val) {
                                        if (val.isNotEmpty) {
                                          setDialogState(() {
                                            _msgPropertiesList.add({'key': '', 'value': val});
                                          });
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 22),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    _buildSettingsRow('Topic Alias', 'Add integer value', _msgTopicAliasController),
                    const Divider(height: 1),
                    _buildSettingsRow('Response Topic', 'Add topic', _msgResponseTopicController),
                    const Divider(height: 1),
                    _buildSettingsRow('Correlation Data', 'Add data', _msgCorrelationDataController),
                    const Divider(height: 1),
                    _buildSettingsRow('Message Expiry Interval', 'Add interval', _msgExpiryIntervalController, suffix: 'ms'),
                    const Divider(height: 1),
                    _buildSettingsRow('Content Type', 'Add type', _msgContentTypeController),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Expanded(child: Text('Payload Format Indicator', style: TextStyle(fontSize: 12))),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                height: 24,
                                child: Transform.scale(
                                  scale: 0.6,
                                  child: Switch(
                                    value: _msgPayloadFormatIndicator,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        _msgPayloadFormatIndicator = val;
                                      });
                                      setState(() {});
                                    },
                                    activeThumbColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsRow(String label, String hint, TextEditingController controller, {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (suffix != null) ...[
                  const SizedBox(width: 4),
                  Text(suffix, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTab() {
    final t = ref.watch(translationsProvider);
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: AppCodeEditor(
              text: _payloadController.text,
              language: _payloadType.toLowerCase(),
              onChanged: (val) {
                _payloadController.text = val;
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                splashRadius: 16,
                onSelected: (String value) {
                  setState(() {
                    _payloadType = value;
                  });
                },
                itemBuilder: (context) => <String>['Text', 'JSON', 'XML']
                    .map((String value) {
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
                        Text(
                          value,
                          style: const TextStyle(fontSize: 12),
                        ),
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
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                      ),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  _showMoreSettings(context);
                },
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.more_horiz, size: 16, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: CustomCheckbox(
                      value: _msgRetain,
                      onChanged: (val) {
                        setState(() {
                          _msgRetain = val ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(t['retain'] ?? 'Retain',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(width: 12),
              const Text('QoS:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              PopupMenuButton<int>(
                tooltip: 'QoS',
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                constraints: const BoxConstraints(minWidth: 130, maxWidth: 130),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                splashRadius: 16,
                onSelected: (int value) {
                  setState(() {
                    _msgQos = value;
                  });
                },
                itemBuilder: (context) => <Map<String, dynamic>>[
                  {'value': 0, 'label': '0 At most once'},
                  {'value': 1, 'label': '1 At least once'},
                  {'value': 2, 'label': '2 Exactly once'},
                ].map((Map<String, dynamic> item) {
                  return PopupMenuItem<int>(
                    value: item['value'] as int,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (item['value'] == _msgQos)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: FaIcon(FontAwesomeIcons.check,
                                size: 12, color: Colors.grey),
                          )
                        else
                          const SizedBox(width: 20),
                        Text(
                          item['label'] as String,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  width: 130,
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
                        _msgQos == 0 ? '0 At most once' : _msgQos == 1 ? '1 At least once' : '2 Exactly once',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                      ),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 28,
                width: 150,
                child: TextField(
                  controller: _msgTopicController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: t['add_topic'] ?? 'Add Topic',
                    hintStyle:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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

  Widget _buildResponseArea() {
    final t = ref.watch(translationsProvider);
    return Column(
      children: [
        const Divider(height: 1),
        InkWell(
          onTap: () {
            setState(() {
              _isResponseExpanded = !_isResponseExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(t['response'] ?? 'Response',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                Icon(
                    _isResponseExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.grey),
              ],
            ),
          ),
        ),
        if (_isResponseExpanded)
          Expanded(
            flex: 2,
            child: _buildMessageHistory(),
          ),
      ],
    );
  }

  final List<Map<String, dynamic>> _topicsList = [];

  Widget _buildTopicsTab() {
    final t = ref.watch(translationsProvider);
    
    return Padding(
      padding: const EdgeInsets.only(top: _compactSectionTopSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['topics'] ?? 'Topics',
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.normal)),
          const SizedBox(height: _compactSectionLabelGap),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopicTableRow('Topic', 'QoS', 'Description',
                      isHeader: true),
                  ..._topicsList.asMap().entries.map((entry) {
                    return _buildTopicTableRow(
                      entry.value['topic']?.toString() ?? '',
                      entry.value['qos']?.toString() ?? '0',
                      entry.value['description']?.toString() ?? '',
                      isHeader: false,
                      index: entry.key,
                      subscribed: entry.value['subscribe'] == true,
                      topicMap: entry.value,
                    );
                  }),
                  _buildTopicTableRow('', '', '',
                      isHeader: false, isNew: true, isLast: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicTableRow(String topic, String qos, String desc,
      {required bool isHeader,
      int? index,
      bool isNew = false,
      bool subscribed = false,
      Map<String, dynamic>? topicMap,
      bool isLast = false}) {
    final t = ref.watch(translationsProvider);
    return Container(
      height: _compactTableRowHeight,
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        color: isHeader
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _compactTableOuterHorizontalPadding,
        vertical: 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isHeader) ...[
            SizedBox(
              width: 16,
              child: isNew
                  ? null
                  : InkWell(
                      onTap: () {
                        if (topicMap != null) {
                          _toggleSubscription(topicMap);
                        }
                      },
                      child: Center(
                        child: FaIcon(
                          subscribed
                              ? FontAwesomeIcons.squareCheck
                              : FontAwesomeIcons.square,
                          size: 16,
                          color: subscribed
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: _compactTableColumnGap),
          ] else
            const SizedBox(width: _compactTableLeadingSlotWidth),
          Expanded(
              flex: 3,
              child: _buildTableCell(topic,
                  isHeader: isHeader,
                  hint: t['add_topic'] ?? 'Add topic',
                  onChanged: (v) {
                if (isNew) {
                  setState(() {
                    _topicsList.add({
                      'topic': v,
                      'qos': 0,
                      'subscribe': true,
                      'description': ''
                    });
                  });
                } else if (index != null) {
                  setState(() {
                    _topicsList[index]['topic'] = v;
                  });
                }
              })),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 1,
              child: _buildTableCell(qos,
                  isHeader: isHeader,
                  hint: 'QoS',
                  onChanged: (v) {
                final parsed = int.tryParse(v) ?? 0;
                if (isNew) {
                  setState(() {
                    _topicsList.add({
                      'topic': '',
                      'qos': parsed,
                      'subscribe': true,
                      'description': ''
                    });
                  });
                } else if (index != null) {
                  setState(() {
                    _topicsList[index]['qos'] = parsed;
                  });
                }
              })),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 3,
              child: _buildTableCell(desc,
                  isHeader: isHeader,
                  hint: t['description'] ?? 'Description',
                  onChanged: (v) {
                if (isNew) {
                  setState(() {
                    _topicsList.add({
                      'topic': '',
                      'qos': 0,
                      'subscribe': true,
                      'description': v
                    });
                  });
                } else if (index != null) {
                  setState(() {
                    _topicsList[index]['description'] = v;
                  });
                }
              })),
          if (!isHeader)
            SizedBox(
              width: _compactTableSideSlotWidth,
              child: isNew
                  ? null
                  : Center(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const FaIcon(FontAwesomeIcons.xmark,
                            size: 16, color: Colors.grey),
                        onPressed: () {
                          if (index != null) {
                            setState(() {
                              if (_topicsList[index]['subscribe'] == true) {
                                _toggleSubscription(_topicsList[index]);
                              }
                              _topicsList.removeAt(index);
                            });
                          }
                        },
                      ),
                    ),
            )
          else
            const SizedBox(width: _compactTableSideSlotWidth),
        ],
      ),
    );
  }

  Widget _buildTableCell(String text,
      {required bool isHeader,
      required String hint,
      required Function(String) onChanged}) {
    if (isHeader) {
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: _compactTableCellHorizontalPadding,
        ),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 12,
                fontWeight: FontWeight.normal)),
      );
    }
    return Container(
      alignment: Alignment.centerLeft,
      child: TableCellTextField(
        text: text,
        hint: hint,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildAuthorizationTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 200,
          padding: const EdgeInsets.only(right: 16, top: 16),
          decoration: BoxDecoration(
            border: Border(
                right: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Auth type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              PopupMenuButton<String>(
                tooltip: 'Auth Type',
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                constraints: const BoxConstraints(minWidth: 100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                splashRadius: 16,
                onSelected: (String value) {
                  setState(() {
                    _authType = value;
                  });
                },
                itemBuilder: (context) => <String>['No Auth', 'Basic Auth']
                    .map((String value) {
                  return PopupMenuItem<String>(
                        value: value,
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                       children: [
                         if (value == _authType)
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
                  width: 100,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _authType,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                      ),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(32),
            child: _authType == 'No Auth'
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).dividerColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                              child: Text('-',
                                  style: TextStyle(
                                      fontSize: 24, color: Colors.grey))),
                        ),
                        const SizedBox(height: 16),
                        const Text('No Auth',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                            'This mqtt-request does not use any authorization.',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                                width: 80,
                                child: Text('Username',
                                    style: TextStyle(fontSize: 12))),
                            Expanded(
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context).dividerColor),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const TextField(
                                  style: TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const SizedBox(
                                width: 80,
                                child: Text('Password',
                                    style: TextStyle(fontSize: 12))),
                            Expanded(
                              child: Container(
                                height: 32,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Theme.of(context).dividerColor),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const TextField(
                                  obscureText: true,
                                  style: TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 10),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  final List<Map<String, dynamic>> _propertiesList = [];

  Widget _buildPropertiesTab() {
    final t = ref.watch(translationsProvider);
    final mappedProps = _propertiesList
        .map((e) => {
              'key': e['property'].toString(),
              'value': e['value'].toString(),
              'description': e['description'].toString(),
              'enabled': e['enabled'] == true ? 'true' : 'false'
            })
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: _compactSectionTopSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['properties'] ?? 'Properties',
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.normal)),
          const SizedBox(height: _compactSectionLabelGap),
          SharedDynamicTable(
            items: mappedProps,
            onAdd: (key, value, desc) {
              setState(() {
                _propertiesList.add({
                  'property': key,
                  'value': value,
                  'description': desc,
                  'enabled': true
                });
              });
            },
            onUpdate: (i, key, value) {
              setState(() {
                _propertiesList[i]['property'] = key;
                _propertiesList[i]['value'] = value;
              });
            },
            onUpdateDesc: (i, desc) {
              setState(() {
                _propertiesList[i]['description'] = desc;
              });
            },
            onRemove: (i) {
              setState(() {
                _propertiesList.removeAt(i);
              });
            },
            onToggle: (i, enabled) {
              setState(() {
                _propertiesList[i]['enabled'] = enabled;
              });
            },
          ),
        ],
      ),
    );
  }

  String _willPayloadType = 'Text';
  bool _willRetain = false;
  int _willQos = 0;
  int _willDelay = 0;
  final TextEditingController _willTopicController = TextEditingController();
  final TextEditingController _willPayloadController = TextEditingController();

  final TextEditingController _willResponseTopicController = TextEditingController();
  final TextEditingController _willCorrelationDataController = TextEditingController();
  final TextEditingController _willExpiryIntervalController = TextEditingController();
  final TextEditingController _willContentTypeController = TextEditingController();
  bool _willPayloadFormatIndicator = false;
  final List<Map<String, String>> _willPropertiesList = [];

  void _showWillMoreSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              alignment: Alignment.center,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Properties', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            setDialogState(() {
                              _willPropertiesList.add({'key': '', 'value': ''});
                            });
                            setState(() {});
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.add, size: 16, color: Colors.grey),
                          ),
                        ),
                        const Spacer(),
                        const Text('Value', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const Divider(),
                    ..._willPropertiesList.asMap().entries.map((entry) {
                      int i = entry.key;
                      Map<String, String> prop = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 28,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: TableCellTextField(
                                  text: prop['key'] ?? '',
                                  hint: 'Property',
                                  onChanged: (val) {
                                    prop['key'] = val;
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 28,
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Theme.of(context).dividerColor),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: TableCellTextField(
                                        text: prop['value'] ?? '',
                                        hint: 'Value',
                                        onChanged: (val) {
                                          prop['value'] = val;
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        _willPropertiesList.removeAt(i);
                                      });
                                      setState(() {});
                                    },
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.close, size: 14, color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TableCellTextField(
                                text: '',
                                hint: 'Add property',
                                onChanged: (val) {
                                  if (val.isNotEmpty) {
                                    setDialogState(() {
                                      _willPropertiesList.add({'key': val, 'value': ''});
                                    });
                                    setState(() {});
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 28,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Theme.of(context).dividerColor),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: TableCellTextField(
                                      text: '',
                                      hint: 'Add Value',
                                      onChanged: (val) {
                                        if (val.isNotEmpty) {
                                          setDialogState(() {
                                            _willPropertiesList.add({'key': '', 'value': val});
                                          });
                                          setState(() {});
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 22),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text('Will Delay', style: TextStyle(fontSize: 12)),
                          ),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      hintText: 'Add delay',
                                      hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    controller: TextEditingController(text: _willDelay > 0 ? _willDelay.toString() : ''),
                                    onChanged: (val) {
                                      _willDelay = int.tryParse(val) ?? 0;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('s', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    _buildSettingsRow('Response Topic', 'Add topic', _willResponseTopicController),
                    const Divider(height: 1),
                    _buildSettingsRow('Correlation Data', 'Add data', _willCorrelationDataController),
                    const Divider(height: 1),
                    _buildSettingsRow('Message Expiry Interval', 'Add interval', _willExpiryIntervalController, suffix: 'ms'),
                    const Divider(height: 1),
                    _buildSettingsRow('Content Type', 'Add type', _willContentTypeController),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const Expanded(child: Text('Payload Format Indicator', style: TextStyle(fontSize: 12))),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                height: 24,
                                child: Transform.scale(
                                  scale: 0.6,
                                  child: Switch(
                                    value: _willPayloadFormatIndicator,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        _willPayloadFormatIndicator = val;
                                      });
                                      setState(() {});
                                    },
                                    activeThumbColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLastWillTab() {
    final t = ref.watch(translationsProvider);
    return Column(
      children: [
        Expanded(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: AppCodeEditor(
              text: _willPayloadController.text,
              language: _willPayloadType.toLowerCase(),
              onChanged: (val) {
                _willPayloadController.text = val;
              },
            ),
          ),
        ),
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                splashRadius: 16,
                onSelected: (String value) {
                  setState(() {
                    _willPayloadType = value;
                  });
                },
                itemBuilder: (context) => <String>['Text', 'JSON', 'XML']
                    .map((String value) {
                  return PopupMenuItem<String>(
                    value: value,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (value == _willPayloadType)
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
                        _willPayloadType,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                      ),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  _showWillMoreSettings(context);
                },
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Icon(Icons.more_horiz, size: 16, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: CustomCheckbox(
                      value: _willRetain,
                      onChanged: (val) {
                        setState(() {
                          _willRetain = val ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(t['retain'] ?? 'Retain',
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(width: 12),
              const Text('QoS:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              PopupMenuButton<int>(
                tooltip: 'QoS',
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                color: Theme.of(context).colorScheme.surface,
                constraints: const BoxConstraints(minWidth: 130, maxWidth: 130),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1.0,
                  ),
                ),
                splashRadius: 16,
                onSelected: (int value) {
                  setState(() {
                    _willQos = value;
                  });
                },
                itemBuilder: (context) => <Map<String, dynamic>>[
                  {'value': 0, 'label': '0 At most once'},
                  {'value': 1, 'label': '1 At least once'},
                  {'value': 2, 'label': '2 Exactly once'},
                ].map((Map<String, dynamic> item) {
                  return PopupMenuItem<int>(
                    value: item['value'] as int,
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (item['value'] == _willQos)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: FaIcon(FontAwesomeIcons.check,
                                size: 12, color: Colors.grey),
                          )
                        else
                          const SizedBox(width: 20),
                        Text(
                          item['label'] as String,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                child: Container(
                  width: 130,
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
                        _willQos == 0 ? '0 At most once' : _willQos == 1 ? '1 At least once' : '2 Exactly once',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                      ),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 28,
                width: 150,
                child: TextField(
                  controller: _willTopicController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: t['add_topic'] ?? 'Add Topic',
                    hintStyle:
                        const TextStyle(color: Colors.grey, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow(String title, String description, Widget control) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: control,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingInput(TextEditingController controller) {
    return SizedBox(
      width: 80,
      height: 32,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 12,
            fontFamily: 'Consolas'),
        decoration: InputDecoration(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4.0),
            borderSide: BorderSide(color: Theme.of(context).dividerColor),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    final t = ref.watch(translationsProvider);
    return ListView(
      padding: const EdgeInsets.only(top: 16.0, right: 16.0, bottom: 16.0),
      children: [
        _buildSettingRow(
          t['enable_server_certificate_verification'] ?? 'Enable server certificate verification',
          t['verify_server_certificate_desc'] ?? 'Verify server certificate when connecting to a broker over a secure connection.',
          SizedBox(
            height: 24,
            child: Transform.scale(
              scale: 0.65,
              child: Switch(
                value: _enableCertVerification,
                onChanged: (v) => setState(() => _enableCertVerification = v),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        _buildSettingRow(
          t['clean_session'] ?? 'Clean Session',
          t['clean_session_desc'] ?? 'Configure if the broker should start with a fresh connection without retaining any previous session data.',
          SizedBox(
            height: 24,
            child: Transform.scale(
              scale: 0.65,
              child: Switch(
                value: _cleanSession,
                onChanged: (v) => setState(() => _cleanSession = v),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        _buildSettingRow(
          t['session_expiry_interval'] ?? 'Session Expiry Interval',
          t['session_expiry_interval_desc'] ?? 'Configure the session expiry interval in seconds. This impacts how long a broker will store the session data for your client. If clean start is on, this value is ignored.',
          _buildSettingInput(_sessionExpiryController),
        ),
        _buildSettingRow(
          t['keep_alive'] ?? 'Keep Alive',
          t['keep_alive_desc'] ?? 'Configure the keep alive interval in seconds.',
          _buildSettingInput(_keepAliveController),
        ),
        _buildSettingRow(
          t['auto_reconnect'] ?? 'Auto Reconnect',
          t['auto_reconnect_desc'] ?? 'Configure if the client should automatically reconnect on abrupt disconnection.',
          SizedBox(
            height: 24,
            child: Transform.scale(
              scale: 0.65,
              child: Switch(
                value: _autoReconnect,
                onChanged: (v) => setState(() => _autoReconnect = v),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        _buildSettingRow(
          t['connection_timeout'] ?? 'Connection Timeout',
          t['connection_timeout_desc'] ?? 'Configure the connection timeout in seconds.',
          _buildSettingInput(_connectionTimeoutController),
        ),
        _buildSettingRow(
          t['receive_maximum'] ?? 'Receive Maximum',
          t['receive_maximum_desc'] ?? 'Configure the maximum number of QoS 1 and 2 messages that can be processed concurrently.',
          _buildSettingInput(_receiveMaximumController),
        ),
        _buildSettingRow(
          t['maximum_packet_size'] ?? 'Maximum Packet Size',
          t['maximum_packet_size_desc'] ?? 'Configure the maximum packet size in bytes that the client will accept.',
          _buildSettingInput(_maxPacketSizeController),
        ),
      ],
    );
  }

  Widget _buildMessageHistory() {
    final t = ref.watch(translationsProvider);
    if (_messages.isEmpty) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t['connect_to_send'] ?? 'Connect to send and receive messages',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final isSystem = msg.topic == 'system';

        if (isSystem) {
          return Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(msg.content,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          );
        }

        return Align(
          alignment: msg.isSent ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7),
            decoration: BoxDecoration(
              color: msg.isSent
                  ? Colors.orange.withOpacity(0.1)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: msg.isSent
                      ? Colors.orange.withOpacity(0.3)
                      : Theme.of(context).dividerColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      msg.isSent
                          ? FontAwesomeIcons.arrowUp
                          : FontAwesomeIcons.arrowDown,
                      size: 10,
                      color: msg.isSent ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Topic: ${msg.topic}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}:${msg.timestamp.second.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(msg.content,
                    style:
                        const TextStyle(fontSize: 12, fontFamily: 'Consolas')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    final t = ref.watch(translationsProvider);
    return Container(
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TextField(
                controller: _topicController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Topic (e.g. test/topic)',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                enabled: _isConnected,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                enabled: _isConnected,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: _isConnected ? _sendMessage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                elevation: 0,
              ),
              child: Row(
                children: [
                  Text(t['publish'] ?? 'Publish',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const SizedBox(width: 8),
                  const FaIcon(FontAwesomeIcons.paperPlane,
                      size: 12, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
