import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/utils/toast_utils.dart';
import '../../domain/models/capture_session_model.dart';
import '../providers/capture_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/settings_provider.dart';
import 'capture_pane.dart';

class CollapsibleSection extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final int? badgeCount;
  final bool initiallyExpanded;

  const CollapsibleSection({
    Key? key,
    required this.title,
    required this.children,
    this.badgeCount,
    this.initiallyExpanded = true,
  }) : super(key: key);

  @override
  _CollapsibleSectionState createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey.withOpacity(0.1),
            child: Row(
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (widget.badgeCount != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.badgeCount}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                const Spacer(),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.grey),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.children,
            ),
          ),
      ],
    );
  }
}

class BodyTabsView extends ConsumerStatefulWidget {
  final String body;
  final bool isRequest;
  final String contentType;

  const BodyTabsView({
    Key? key,
    required this.body,
    required this.isRequest,
    required this.contentType,
  }) : super(key: key);

  @override
  ConsumerState<BodyTabsView> createState() => _BodyTabsViewState();
}

class _BodyTabsViewState extends ConsumerState<BodyTabsView> {
  String _selectedTab = '';
  bool _isWrapped = false;

  Map<String, String> get t => ref.read(translationsProvider);

  @override
  void initState() {
    super.initState();
    if (widget.isRequest) {
      if (widget.contentType.contains('application/x-www-form-urlencoded')) {
        _selectedTab = 'Urlencode';
      } else {
        _selectedTab = 'Raw';
      }
    } else {
      if (widget.contentType.contains('json')) {
        _selectedTab = 'JSON';
      } else {
        _selectedTab = 'Raw';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(translationsProvider);
    final tabs = widget.isRequest
        ? ['Urlencode', 'Raw', 'Hex']
        : ['JSON', 'Tree', 'Raw', 'Hex'];
    if (!tabs.contains(_selectedTab)) {
      _selectedTab = tabs.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Row(
            children: [
              ...tabs.map((tab) => _buildTab(tab)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search, size: 16, color: Colors.grey),
                onPressed: () {
                  ToastUtils.showInfo(context,
                      t['search_coming_soon'] ?? 'Search function coming soon');
                },
                splashRadius: 16,
              ),
              IconButton(
                icon: Icon(Icons.wrap_text,
                    size: 16,
                    color: _isWrapped
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey),
                onPressed: () => setState(() => _isWrapped = !_isWrapped),
                splashRadius: 16,
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: Colors.grey),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.body));
                  ToastUtils.showInfo(context,
                      t['copied_to_clipboard'] ?? 'Copied to clipboard');
                },
                splashRadius: 16,
              ),
              IconButton(
                icon: const Icon(Icons.download, size: 16, color: Colors.grey),
                onPressed: () async {
                  final ext = widget.contentType.contains('json')
                      ? 'json'
                      : widget.contentType.contains('html')
                          ? 'html'
                          : 'txt';
                  final path = await FilePicker.platform.saveFile(
                    dialogTitle: t['save_data'] ?? 'Save Data',
                    fileName: 'response.$ext',
                  );
                  if (path != null) {
                    await File(path).writeAsString(widget.body);
                    if (mounted) {
                      ToastUtils.showInfo(
                          context, '${t['saved_to'] ?? 'Saved to '}$path');
                    }
                  }
                },
                splashRadius: 16,
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildTab(String text) {
    final isSelected = _selectedTab == text;
    return InkWell(
      onTap: () => setState(() => _selectedTab = text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? Theme.of(context).textTheme.bodyMedium?.color
                  : Colors.grey,
            )),
      ),
    );
  }

  Widget _buildContent() {
    if (widget.body.isEmpty) {
      return Center(
          child: Text(t['no_data'] ?? 'No data',
              style: const TextStyle(color: Colors.grey, fontSize: 13)));
    }

    if (_selectedTab == 'Urlencode') {
      return _buildUrlencodeView();
    } else if (_selectedTab == 'JSON') {
      return _buildJsonView();
    } else if (_selectedTab == 'Hex') {
      return _buildHexView();
    } else if (_selectedTab == 'Tree') {
      return Center(
          child: Text(t['tree_view_coming_soon'] ?? 'Tree view coming soon',
              style: const TextStyle(color: Colors.grey, fontSize: 13)));
    }

    return _buildRawView();
  }

  Widget _buildUrlencodeView() {
    try {
      final parts = widget.body.split('&');
      final rows = <TableRow>[];
      for (final p in parts) {
        final kv = p.split('=');
        final k = Uri.decodeQueryComponent(kv[0]);
        final v = kv.length > 1
            ? Uri.decodeQueryComponent(kv.sublist(1).join('='))
            : '';
        rows.add(TableRow(
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color:
                            Theme.of(context).dividerColor.withOpacity(0.5)))),
            children: [
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      SelectableText(k, style: const TextStyle(fontSize: 12))),
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child:
                      SelectableText(v, style: const TextStyle(fontSize: 12))),
            ]));
      }
      return SingleChildScrollView(
        child: Table(
          columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
          children: rows,
        ),
      );
    } catch (e) {
      return _buildRawView();
    }
  }

  Widget _buildJsonView() {
    try {
      final obj = json.decode(widget.body);
      final pretty = const JsonEncoder.withIndent('  ').convert(obj);
      return _buildRawView(text: pretty);
    } catch (e) {
      return _buildRawView();
    }
  }

  Widget _buildHexView() {
    final bytes = utf8.encode(widget.body);
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length; i += 16) {
      buffer.write('${i.toRadixString(16).padLeft(8, '0')}  ');
      for (int j = 0; j < 16; j++) {
        if (i + j < bytes.length) {
          buffer.write('${bytes[i + j].toRadixString(16).padLeft(2, '0')} ');
        } else {
          buffer.write('   ');
        }
      }
      buffer.write(' |');
      for (int j = 0; j < 16; j++) {
        if (i + j < bytes.length) {
          final b = bytes[i + j];
          if (b >= 32 && b <= 126) {
            buffer.write(String.fromCharCode(b));
          } else {
            buffer.write('.');
          }
        }
      }
      buffer.writeln('|');
    }
    return _buildRawView(text: buffer.toString());
  }

  Widget _buildRawView({String? text}) {
    final content = text ?? widget.body;
    final lines = content.split('\n');
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isWrapped)
            Container(
              padding:
                  const EdgeInsets.only(top: 12, left: 8, right: 8, bottom: 12),
              color: Colors.grey.withOpacity(0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                    lines.length,
                    (i) => Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontFamily: 'monospace',
                            height: 1.5))),
              ),
            ),
          Expanded(
            child: _isWrapped
                ? Container(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      content,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.5,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        content,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.5,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class SessionListTable extends ConsumerStatefulWidget {
  final List<CaptureSessionModel> sessions;
  final String? selectedSessionId;
  final CapturePaneState parentState;

  const SessionListTable({
    Key? key,
    required this.sessions,
    this.selectedSessionId,
    required this.parentState,
  }) : super(key: key);

  @override
  ConsumerState<SessionListTable> createState() => _SessionListTableState();
}

class _SessionListTableState extends ConsumerState<SessionListTable> {
  double _idWidth = 48;
  double _iconWidth = 36;
  double _methodWidth = 64;
  double _urlWidth = 200;
  double _appWidth = 120;
  double _statusWidth = 64;
  double _domainWidth = 120;
  double _ipWidth = 120;
  double _durationWidth = 70;
  double _sizeWidth = 70;

  double? _dragInitialWidth;
  double? _dragInitialX;

  int _sortColumnIndex = 0;
  bool _sortAscending = false;
  late List<CaptureSessionModel> _sortedSessions;

  Map<String, String> get t => widget.parentState.t;

  @override
  void initState() {
    super.initState();
    _sortSessions();
  }

  @override
  void didUpdateWidget(covariant SessionListTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessions != oldWidget.sessions) {
      _sortSessions();
    }
  }

  void _sortSessions() {
    _sortedSessions = List.from(widget.sessions);
    _sortedSessions.sort((a, b) {
      int result;
      switch (_sortColumnIndex) {
        case 0: // ID
          result = a.id.compareTo(b.id);
          break;
        case 1: // Icon/Protocol
          result = a.protocol.compareTo(b.protocol);
          break;
        case 2: // Method
          result = a.method.compareTo(b.method);
          break;
        case 3: // URL
          result = a.url.compareTo(b.url);
          break;
        case 4: // Application
          result = (a.appName ?? '').compareTo(b.appName ?? '');
          break;
        case 5: // Status Code
          result = (a.statusCode ?? 0).compareTo(b.statusCode ?? 0);
          break;
        case 6: // Domain
          result = a.host.compareTo(b.host);
          break;
        case 7: // Server IP
          result = (a.serverIp ?? '').compareTo(b.serverIp ?? '');
          break;
        case 8: // Duration
          result = a.durationMs.compareTo(b.durationMs);
          break;
        case 9: // Size
          result = (a.requestBytes + a.responseBytes)
              .compareTo(b.requestBytes + b.responseBytes);
          break;
        default:
          result = 0;
      }
      return _sortAscending ? result : -result;
    });
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _sortSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sortedSessions.isEmpty) {
      return Center(
        child: Text(
          t['no_data'] ?? 'No data',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double currentUrlWidth = _urlWidth;
        double currentTotal = 44.0 +
            _idWidth +
            _iconWidth +
            _methodWidth +
            currentUrlWidth +
            _appWidth +
            _statusWidth +
            _domainWidth +
            _ipWidth +
            _durationWidth +
            _sizeWidth;

        if (constraints.maxWidth - currentTotal > 0.5) {
          currentUrlWidth += (constraints.maxWidth - currentTotal);
          currentTotal = constraints.maxWidth;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (_urlWidth - currentUrlWidth).abs() > 0.5) {
              setState(() {
                _urlWidth = currentUrlWidth;
              });
            }
          });
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: currentTotal,
            child: Column(
              children: [
                _buildListHeader(context, currentUrlWidth),
                Expanded(
                  child: ListView.builder(
                    itemExtent: 34.0,
                    itemCount: _sortedSessions.length,
                    itemBuilder: (context, index) {
                      final s = _sortedSessions[index];
                      final isSelected = s.id == widget.selectedSessionId;
                      final methodColor = widget.parentState.methodColor(s.method);
                      final statusColor = widget.parentState.statusColor(s.statusCode);
                      return GestureDetector(
                        onDoubleTap: () {
                          ref.read(captureProvider.notifier).select(s.id);
                          widget.parentState.showDetailsDialog(context, s);
                        },
                        onSecondaryTapDown: (details) {
                          ref.read(captureProvider.notifier).select(s.id);
                          widget.parentState.showContextMenu(
                              context, s, details.globalPosition);
                        },
                        child: InkWell(
                          onTap: () {
                            ref.read(captureProvider.notifier).select(s.id);
                          },
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withOpacity(0.12)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                    color: Theme.of(context)
                                        .dividerColor
                                        .withOpacity(0.6)),
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: _idWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      '${widget.sessions.length - widget.sessions.indexOf(s)}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: _iconWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: widget.parentState.buildResourceIcon(s),
                                  ),
                                ),
                                SizedBox(
                                  width: _methodWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      s.method,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: methodColor,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: currentUrlWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      s.url,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: _appWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Row(
                                      children: [
                                        if (s.appIconPath != null) ...[
                                          Image.file(
                                            File(s.appIconPath!),
                                            width: 14,
                                            height: 14,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                const FaIcon(
                                                    FontAwesomeIcons.windowMaximize,
                                                    size: 12,
                                                    color: Colors.blueGrey),
                                          ),
                                          const SizedBox(width: 4),
                                        ] else if (s.appName != null) ...[
                                          const FaIcon(
                                              FontAwesomeIcons.windowMaximize,
                                              size: 12,
                                              color: Colors.blueGrey),
                                          const SizedBox(width: 4),
                                        ],
                                        Expanded(
                                          child: Text(
                                            widget.parentState.formatAppName(s.appName),
                                            style: const TextStyle(
                                                fontSize: 12, color: Colors.grey),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: _statusWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      s.statusCode?.toString() ?? '-',
                                      style: TextStyle(
                                          fontSize: 12, color: statusColor),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: _domainWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      s.host,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: _ipWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      s.serverIp ?? '-',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: _durationWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      '${(s.durationMs / 1000).toStringAsFixed(3)}s',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: _sizeWidth,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Text(
                                      widget.parentState.formatSize(
                                          s.requestBytes + s.responseBytes),
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListHeader(BuildContext context, double urlWidth) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 24),
          _buildResizableHeader(
            'ID',
            _idWidth,
            (w) => setState(() => _idWidth = w.clamp(30.0, 200.0)),
            columnIndex: 0,
          ),
          _buildResizableHeader(
            t['icon'] ?? 'Icon',
            _iconWidth,
            (w) => setState(() => _iconWidth = w.clamp(20.0, 100.0)),
            columnIndex: 1,
          ),
          _buildResizableHeader(
            t['method'] ?? 'Method',
            _methodWidth,
            (w) => setState(() => _methodWidth = w.clamp(40.0, 200.0)),
            columnIndex: 2,
          ),
          _buildResizableHeader(
            'URL',
            urlWidth,
            (w) => setState(() => _urlWidth = w.clamp(50.0, 5000.0)),
            columnIndex: 3,
          ),
          _buildResizableHeader(
            t['application'] ?? 'Application',
            _appWidth,
            (w) => setState(() => _appWidth = w.clamp(60.0, 300.0)),
            columnIndex: 4,
          ),
          _buildResizableHeader(
            t['status_code'] ?? 'Status Code',
            _statusWidth,
            (w) => setState(() => _statusWidth = w.clamp(40.0, 150.0)),
            columnIndex: 5,
          ),
          _buildResizableHeader(
            t['domain'] ?? 'Domain',
            _domainWidth,
            (w) => setState(() => _domainWidth = w.clamp(60.0, 300.0)),
            columnIndex: 6,
          ),
          _buildResizableHeader(
            t['server_ip'] ?? 'Server IP',
            _ipWidth,
            (w) => setState(() => _ipWidth = w.clamp(60.0, 300.0)),
            columnIndex: 7,
          ),
          _buildResizableHeader(
            t['duration'] ?? 'Duration',
            _durationWidth,
            (w) => setState(() => _durationWidth = w.clamp(40.0, 150.0)),
            columnIndex: 8,
          ),
          _buildResizableHeader(
            t['size'] ?? 'Size',
            _sizeWidth,
            (w) => setState(() => _sizeWidth = w.clamp(40.0, 150.0)),
            isLast: true,
            columnIndex: 9,
          ),
        ],
      ),
    );
  }

  Widget _buildResizableHeader(
      String title, double width, ValueChanged<double> onWidthUpdate,
      {bool isLast = false, bool isRightSide = false, required int columnIndex}) {
    final dragHandle = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (details) {
        _dragInitialWidth = width;
        _dragInitialX = details.globalPosition.dx;
      },
      onHorizontalDragUpdate: (details) {
        if (_dragInitialWidth == null || _dragInitialX == null) return;
        final deltaX = details.globalPosition.dx - _dragInitialX!;
        final newWidth = _dragInitialWidth! + (isRightSide ? -deltaX : deltaX);
        onWidthUpdate(newWidth);
      },
      onHorizontalDragEnd: (details) {
        _dragInitialWidth = null;
        _dragInitialX = null;
      },
      onHorizontalDragCancel: () {
        _dragInitialWidth = null;
        _dragInitialX = null;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 8,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: 1,
            height: 12,
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
    );

    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: () => _onSort(columnIndex),
              child: Container(
                padding: EdgeInsets.only(left: isRightSide ? 6.0 : 4.0),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(title,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (_sortColumnIndex == columnIndex)
                      Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward, size: 12, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          if (isRightSide)
            Positioned(
              left: -4,
              top: 0,
              bottom: 0,
              child: dragHandle,
            ),
          if (!isRightSide && !isLast)
            Positioned(
              right: -4,
              top: 0,
              bottom: 0,
              child: dragHandle,
            ),
        ],
      ),
    );
  }
}
