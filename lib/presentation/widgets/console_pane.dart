import 'package:post_lens/core/utils/toast_utils.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/models/console_log.dart';
import '../providers/console_provider.dart';
import '../providers/settings_provider.dart';

class ConsolePane extends ConsumerStatefulWidget {
  const ConsolePane({super.key});

  @override
  ConsumerState<ConsolePane> createState() => _ConsolePaneState();
}

class _ConsolePaneState extends ConsumerState<ConsolePane> {
  final Set<LogLevel> _activeFilters = {
    LogLevel.log,
    LogLevel.info,
    LogLevel.warning,
    LogLevel.error,
    LogLevel.network,
  };

  bool _showTimestamps = false;
  bool _hideNetwork = false;
  final Set<String> _expandedLogs = {};
  final Map<String, Set<String>> _expandedSections = {};

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final logs = ref.watch(consoleProvider);
    final errorCount = logs.where((l) => l.level == LogLevel.error).length;

    var filteredLogs =
        logs.where((l) => _activeFilters.contains(l.level)).toList();
    if (_hideNetwork) {
      filteredLogs = filteredLogs.where((l) => l.level != LogLevel.network).toList();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    t['console'] ?? 'Console',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                const Spacer(),
                if (errorCount > 0) ...[
                  Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.circleExclamation,
                        size: 12,
                        color: Color(0xFFF05050),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$errorCount Error${errorCount > 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                ],
                PopupMenuButton<LogLevel>(
                  tooltip: 'Filter Logs',
                  position: PopupMenuPosition.under,
                  padding: EdgeInsets.zero,
                  splashRadius: 16,
                  offset: const Offset(0, 8),
                  onSelected: (level) {
                    setState(() {
                      if (_activeFilters.contains(level)) {
                        _activeFilters.remove(level);
                      } else {
                        _activeFilters.add(level);
                      }
                    });
                  },
                  itemBuilder: (context) {
                    return [
                      _buildFilterMenuItem(LogLevel.log, 'Log'),
                      _buildFilterMenuItem(LogLevel.info, 'Info'),
                      _buildFilterMenuItem(LogLevel.warning, 'Warning'),
                      _buildFilterMenuItem(LogLevel.error, 'Error'),
                      _buildFilterMenuItem(LogLevel.network, 'Network'),
                    ];
                  },
                  child: const Row(
                    children: [
                      Text(
                        'All Logs',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(width: 4),
                      FaIcon(
                        FontAwesomeIcons.chevronDown,
                        size: 10,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    ref.read(consoleProvider.notifier).clearLogs();
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t['clear'] ?? 'Clear',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildActionIcon(
                  icon: FontAwesomeIcons.copy,
                  tooltip: 'Copy all logs',
                  onTap: () {
                    final logText = filteredLogs
                        .map((l) =>
                            '[${l.level.name.toUpperCase()}] ${l.message}')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: logText));
                    ToastUtils.showInfo(context, 'Logs copied to clipboard');
                  },
                ),
                const SizedBox(width: 8),
                _buildActionIcon(
                  icon: FontAwesomeIcons.ellipsis,
                  tooltip: 'More actions',
                  onTap: () {
                    _showMoreMenu(context);
                  },
                ),
                const SizedBox(width: 8),
                _buildActionIcon(
                  icon: FontAwesomeIcons.xmark,
                  tooltip: 'Close console',
                  onTap: () {
                    ref.read(isConsoleOpenProvider.notifier).state = false;
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredLogs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      if (log.isNetworkLog) {
                        return _buildNetworkLogItem(log, isDark);
                      }
                      return _buildLogItem(log, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final t = ref.read(translationsProvider);
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 180),
      items: [
        PopupMenuItem(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            setState(() {
              _showTimestamps = !_showTimestamps;
            });
          },
          child: Row(
            children: [
              Icon(
                _showTimestamps
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 16,
                color: _showTimestamps ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(t['show_timestamps'] ?? 'Show Timestamps',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        PopupMenuItem(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          onTap: () {
            setState(() {
              _hideNetwork = !_hideNetwork;
            });
          },
          child: Row(
            children: [
              Icon(
                _hideNetwork
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                size: 16,
                color: _hideNetwork ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(t['hide_network'] ?? 'Hide Network',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<LogLevel> _buildFilterMenuItem(LogLevel level, String title) {
    final isSelected = _activeFilters.contains(level);
    return PopupMenuItem<LogLevel>(
      value: level,
      height: 32,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: FaIcon(
            icon,
            size: 14,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(ConsoleLog log, bool isDark) {
    Color? bgColor;
    IconData? levelIcon;
    Color? iconColor;

    switch (log.level) {
      case LogLevel.error:
        bgColor = const Color(0xFFF05050).withOpacity(0.1);
        levelIcon = FontAwesomeIcons.circleExclamation;
        iconColor = const Color(0xFFF05050);
        break;
      case LogLevel.warning:
        bgColor = Colors.orange.withOpacity(0.1);
        levelIcon = FontAwesomeIcons.triangleExclamation;
        iconColor = Colors.orange;
        break;
      case LogLevel.info:
      case LogLevel.log:
      case LogLevel.network:
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (levelIcon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FaIcon(
                levelIcon,
                size: 12,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (_showTimestamps) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _formatTimestamp(log.timestamp),
                style: const TextStyle(
                  fontFamily: 'IBMPlexMono',
                  fontFamilyFallback: ['Monaco', 'Courier New', 'monospace'],
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SelectableText(
              log.message,
              style: TextStyle(
                fontFamily: 'IBMPlexMono',
                fontFamilyFallback: const [
                  'Monaco',
                  'Courier New',
                  'monospace'
                ],
                fontSize: 12,
                color: log.level == LogLevel.error
                    ? const Color(0xFFF05050)
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkLogItem(ConsoleLog log, bool isDark) {
    final isExpanded = _expandedLogs.contains(log.id);
    final statusColor = _statusColor(log.statusCode);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedLogs.remove(log.id);
                } else {
                  _expandedLogs.add(log.id);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  FaIcon(
                    isExpanded
                        ? FontAwesomeIcons.caretDown
                        : FontAwesomeIcons.caretRight,
                    size: 12,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  if (log.method != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _methodColor(log.method!).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        log.method!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _methodColor(log.method!),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (log.statusCode != null)
                    Text(
                      '${log.statusCode}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.url ?? log.message,
                      style: TextStyle(
                        fontFamily: 'IBMPlexMono',
                        fontFamilyFallback: const [
                          'Monaco',
                          'Courier New',
                          'monospace'
                        ],
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (log.durationMs != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${log.durationMs}ms',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                  if (_showTimestamps) ...[
                    const SizedBox(width: 8),
                    Text(
                      _formatTimestamp(log.timestamp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isExpanded) _buildNetworkLogDetails(log, isDark),
        ],
      ),
    );
  }

  Widget _buildNetworkLogDetails(ConsoleLog log, bool isDark) {
    final sections = <_ConsoleSection>[];

    if (log.proxyInfo != null && log.proxyInfo!.isNotEmpty) {
      sections.add(_ConsoleSection(
        key: 'proxy',
        title: 'Proxy',
        content: log.proxyInfo!,
      ));
    } else {
      sections.add(_ConsoleSection(
        key: 'proxy',
        title: 'Proxy',
        content: null,
      ));
    }

    sections.add(_ConsoleSection(
      key: 'request_headers',
      title: 'Request Headers',
      headers: log.requestHeaders,
    ));

    if (log.requestBody != null && log.requestBody!.isNotEmpty) {
      sections.add(_ConsoleSection(
        key: 'request_body',
        title: 'Request Body',
        content: log.requestBody!,
      ));
    }

    sections.add(_ConsoleSection(
      key: 'response_headers',
      title: 'Response Headers',
      headers: log.responseHeaders,
    ));

    sections.add(_ConsoleSection(
      key: 'response_body',
      title: 'Response Body',
      content: log.responseBody,
    ));

    return Container(
      padding: const EdgeInsets.only(left: 32, right: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections.map((section) {
          return _buildCollapsibleSection(log.id, section, isDark);
        }).toList(),
      ),
    );
  }

  Widget _buildCollapsibleSection(
      String logId, _ConsoleSection section, bool isDark) {
    final expandedSections = _expandedSections[logId] ?? {};
    final isExpanded = expandedSections.contains(section.key);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              final sections = _expandedSections[logId] ?? <String>{};
              if (isExpanded) {
                sections.remove(section.key);
              } else {
                sections.add(section.key);
              }
              _expandedSections[logId] = sections;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                FaIcon(
                  isExpanded
                      ? FontAwesomeIcons.caretDown
                      : FontAwesomeIcons.caretRight,
                  size: 10,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                if (section.headers != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${section.headers!.values.fold(0, (sum, list) => sum + list.length)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isExpanded) _buildSectionContent(section, isDark),
      ],
    );
  }

  Widget _buildSectionContent(_ConsoleSection section, bool isDark) {
    if (section.headers != null && section.headers!.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(left: 16, bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B1D) : Colors.grey[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: section.headers!.entries.expand((entry) {
            return entry.value.map((v) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 160,
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontFamily: 'IBMPlexMono',
                            fontFamilyFallback: const [
                              'Monaco',
                              'Courier New',
                              'monospace'
                            ],
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.color,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          v,
                          style: const TextStyle(
                            fontFamily: 'IBMPlexMono',
                            fontFamilyFallback: [
                              'Monaco',
                              'Courier New',
                              'monospace'
                            ],
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ));
          }).toList(),
        ),
      );
    }

    if (section.content != null && section.content!.isNotEmpty) {
      String displayContent = section.content!;
      try {
        final obj = json.decode(section.content!);
        displayContent =
            const JsonEncoder.withIndent('  ').convert(obj);
      } catch (_) {}

      return Container(
        margin: const EdgeInsets.only(left: 16, bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B1D) : Colors.grey[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.5)),
        ),
        child: SelectableText(
          displayContent,
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
            fontSize: 11,
            height: 1.4,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        section.key == 'proxy' ? 'No proxy' : 'No content',
        style: const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}.${dt.millisecond.toString().padLeft(3, '0')}';
  }

  Color _statusColor(int? code) {
    if (code == null) return Colors.grey;
    if (code >= 200 && code < 300) return const Color(0xFF2BAE66);
    if (code >= 300 && code < 400) return const Color(0xFFB8860B);
    return const Color(0xFFF05050);
  }

  Color _methodColor(String method) {
    final m = method.toUpperCase();
    if (m == 'GET') return const Color(0xFF2BAE66);
    if (m == 'POST') return const Color(0xFF3B82F6);
    if (m == 'PUT' || m == 'PATCH') return const Color(0xFFB8860B);
    if (m == 'DELETE') return const Color(0xFFF05050);
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  }
}

class _ConsoleSection {
  final String key;
  final String title;
  final String? content;
  final Map<String, List<String>>? headers;

  _ConsoleSection({
    required this.key,
    required this.title,
    this.content,
    this.headers,
  });
}
