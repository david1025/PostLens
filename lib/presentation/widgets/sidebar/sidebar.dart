import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../domain/models/http_request_model.dart';
import '../../providers/request_provider.dart';
import '../../providers/collection_provider.dart';
import '../../../domain/models/collection_model.dart';
import '../../../domain/models/environment_model.dart';
import '../../providers/workspace_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/environment_provider.dart';
import '../../../data/local/database_helper.dart';
import '../settings_dialog.dart';
import '../import_dialog.dart';
import '../tools_pane.dart';
import '../hover_overlay.dart';
import '../custom_search_box.dart';
import 'sidebar_utils.dart';

part 'sidebar_collections.dart';
part 'sidebar_environments.dart';
part 'sidebar_tools.dart';

class Sidebar extends ConsumerStatefulWidget {
  final bool isContentCollapsed;
  final void Function(HttpRequestModel)? onRequestTap;
  final void Function(String id, bool isFolder, String name)? onCollectionTap;
  final void Function(String toolId, String name)? onToolTap;

  const Sidebar({
    super.key,
    this.isContentCollapsed = false,
    this.onRequestTap,
    this.onCollectionTap,
    this.onToolTap,
  });

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}


class _SidebarState extends ConsumerState<Sidebar> {
  static const Color _topBackgroundColor = Color(0xFFEDEFF2);
  static const double _railWidth = 32;
  int _selectedTab =
      0; // 0: Collections, 1: Environments, 2: History, 3: Files, 4: Mock Server
  String _filterText = '';
  final Map<String, TreeController> _tileControllers = {};
  static const double _topControlHeight = 30;
  static const double _importButtonHeight = 20;

  @override
  void initState() {
    super.initState();
    _loadSelectedTab();
  }

  Future<void> _loadSelectedTab() async {
    final val =
        await DatabaseHelper.instance.getKeyValue('sidebar_selected_tab');
    if (val != null && mounted) {
      setState(() {
        _selectedTab = int.tryParse(val) ?? 0;
      });
    }
  }

  void _expandNode(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tileControllers.containsKey(id)) {
        _tileControllers[id]!.expand();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const contentBorderRadius = BorderRadius.all(Radius.circular(8));
    final sidebarBgColor =
        isDark ? const Color(0xFF222427) : _topBackgroundColor;

    return Container(
      color: sidebarBgColor,
      padding: const EdgeInsets.fromLTRB(6, 0, 2, 6),
      child: Row(
        children: [
          SizedBox(
            width: _railWidth,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabIcon(0, FontAwesomeIcons.boxArchive,
                        t['collections'] ?? 'Collections'),
                    const SizedBox(height: 6),
                    _buildTabIcon(1, FontAwesomeIcons.server,
                        t['environments'] ?? 'Environments'),
                    const SizedBox(height: 6),
                    _buildTabIcon(2, FontAwesomeIcons.clockRotateLeft,
                        t['history'] ?? 'History'),
                    const SizedBox(height: 6),
                    _buildTabIcon(
                        5, FontAwesomeIcons.wrench, t['tools'] ?? 'Tools'),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.isContentCollapsed)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1B1D) : Colors.white,
                  borderRadius: contentBorderRadius,
                ),
                child: ClipRRect(
                  borderRadius: contentBorderRadius,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTabContent(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterField() {
    final t = ref.watch(translationsProvider);
    return CustomSearchBox(
      height: _topControlHeight,
      hintText: t['filter'] ?? 'Filter',
      onChanged: (value) {
        setState(() {
          _filterText = value;
        });
      },
      padding: const EdgeInsets.fromLTRB(8.0, 6.0, 8.0, 6.0),
    );
  }

  Widget _buildTabContent() {
    final t = ref.watch(translationsProvider);
    final collections = ref.watch(activeWorkspaceCollectionsProvider);

    switch (_selectedTab) {
      case 0:
        final activeWorkspace = ref.watch(activeWorkspaceProvider);
        final filteredCollections = collections.where((c) {
          if (_filterText.isEmpty) return true;
          return c.name.toLowerCase().contains(_filterText.toLowerCase());
        }).toList();
        final header = Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t['collections'] ?? 'COLLECTIONS',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      height: 24,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext dialogContext) {
                                  return const ImportDialog();
                                },
                              );
                            },
                            child: SizedBox(
                              height: _importButtonHeight,
                              child: Container(
                                alignment: Alignment.center,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(t['import'] ?? 'Import',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.normal)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          PopupMenuButton<String>(
                            tooltip: 'New',
                            position: PopupMenuPosition.under,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 16,
                            onSelected: (value) {
                              if (value == 'collection') {
                                _showAddCollectionDialog(
                                    context, activeWorkspace.id);
                              } else if (value == 'environment') {
                                final newReq = HttpRequestModel(
                                  id: 'environment_new_${DateTime.now().millisecondsSinceEpoch}',
                                  url: 'postlens://environment/new',
                                  method: 'NEW',
                                  name: 'New Environment',
                                );
                                if (widget.onRequestTap != null) {
                                  widget.onRequestTap!(newReq);
                                } else {
                                  ref
                                      .read(requestProvider.notifier)
                                      .loadRequest(newReq);
                                }
                              } else if ([
                                'http',
                                'grpc',
                                'ws',
                                'socket.io',
                                'mqtt',
                                'tcp',
                                'udp'
                              ].contains(value)) {
                                final newReq = HttpRequestModel(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  url: '',
                                  method: value == 'http'
                                      ? 'GET'
                                      : value.toUpperCase(),
                                  protocol: value,
                                  name: 'New ${value.toUpperCase()} Request',
                                );
                                if (widget.onRequestTap != null) {
                                  widget.onRequestTap!(newReq);
                                } else {
                                  ref
                                      .read(requestProvider.notifier)
                                      .loadRequest(newReq);
                                }
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'collection',
                                height: 24,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(t['collection'] ?? 'Collection',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ),
                              PopupMenuItem(
                                value: 'environment',
                                height: 24,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(t['environment'] ?? 'Environment',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ),
                              const PopupMenuDivider(height: 8),
                              PopupMenuItem(
                                value: 'http',
                                height: 24,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(t['http_request'] ?? 'HTTP Request',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ),
                              PopupMenuItem(
                                value: 'grpc',
                                height: 24,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(t['grpc_request'] ?? 'gRPC Request',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ),
                              PopupMenuItem(
                                value: 'ws',
                                height: 24,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                    t['websocket_request'] ??
                                        'WebSocket Request',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ),
                              PopupMenuItem(
                                value: 'socket.io',
                                height: 24,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                    t['socket_request'] ?? 'Socket.IO Request',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ),
                              PopupMenuItem(
                                value: 'mqtt',
                                height: 24,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(t['mqtt_request'] ?? 'MQTT Request',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ),
                              PopupMenuItem(
                                value: 'tcp',
                                height: 24,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(t['tcp_request'] ?? 'TCP Request',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ),
                              PopupMenuItem(
                                value: 'udp',
                                height: 24,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(t['udp_request'] ?? 'UDP Request',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.normal)),
                              ),
                            ],
                            child: SizedBox(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: FaIcon(
                                  FontAwesomeIcons.plus,
                                  size: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (filteredCollections.isEmpty) {
          return Column(
            children: [
              header,
              _buildFilterField(),
              Expanded(
                child: Center(
                  child: Text(t['no_collections'] ?? 'No collections',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          children: [
            header,
            _buildFilterField(),
            for (final collection in filteredCollections)
              _buildCollectionRoot(collection),
          ],
        );
      case 1:
        final envs = ref.watch(activeWorkspaceEnvironmentsProvider);
        final filteredEnvs = envs.where((e) {
          if (_filterText.isEmpty) return true;
          return e.name.toLowerCase().contains(_filterText.toLowerCase());
        }).toList();

        if (filteredEnvs.isEmpty) {
          return Column(
            children: [
              _buildNonExpandableSection(t['environments'] ?? 'ENVIRONMENTS', [
                _buildFilterField(),
              ], onAdd: () {
                final newReq = HttpRequestModel(
                  id: 'environment_new_${DateTime.now().millisecondsSinceEpoch}',
                  url: 'postlens://environment/new',
                  method: 'NEW',
                  name: 'New Environment',
                );
                if (widget.onRequestTap != null) {
                  widget.onRequestTap!(newReq);
                } else {
                  ref.read(requestProvider.notifier).loadRequest(newReq);
                }
              }),
              Expanded(
                child: Center(
                  child: Text(t['no_environment'] ?? 'No Environment',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: EdgeInsets.zero,
          physics: const ClampingScrollPhysics(),
          children: [
            _buildNonExpandableSection(t['environments'] ?? 'ENVIRONMENTS', [
              _buildFilterField(),
              for (final env in filteredEnvs) _buildEnvironmentItem(env),
            ], onAdd: () {
              final newReq = HttpRequestModel(
                id: 'environment_new_${DateTime.now().millisecondsSinceEpoch}',
                url: 'postlens://environment/new',
                method: 'NEW',
                name: 'New Environment',
              );
              if (widget.onRequestTap != null) {
                widget.onRequestTap!(newReq);
              } else {
                ref.read(requestProvider.notifier).loadRequest(newReq);
              }
            }),
          ],
        );
      case 2:
        final history = ref.watch(historyProvider);
        final filteredHistory = history.where((req) {
          if (_filterText.isEmpty) return true;
          return req.url.toLowerCase().contains(_filterText.toLowerCase()) ||
              req.method.toLowerCase().contains(_filterText.toLowerCase());
        }).toList();

        String formatDate(DateTime date) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final yesterday = today.subtract(const Duration(days: 1));
          final dateToCheck = DateTime(date.year, date.month, date.day);

          if (dateToCheck == today) {
            return t['today'] ?? 'Today';
          } else if (dateToCheck == yesterday) {
            return t['yesterday'] ?? 'Yesterday';
          } else {
            return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          }
        }

        final Map<String, List<HttpRequestModel>> grouped = {};
        for (var req in filteredHistory) {
          final ts = int.tryParse(req.id) ?? 0;
          final date = DateTime.fromMillisecondsSinceEpoch(ts);
          final dayStr = formatDate(date);
          grouped.putIfAbsent(dayStr, () => []).add(req);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: 8, right: 8, top: 8, bottom: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t['request_history'] ?? 'REQUEST HISTORY',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color)),
                  SizedBox(
                    height: 24,
                    child: PopupMenuButton<String>(
                      tooltip: 'More actions',
                      position: PopupMenuPosition.under,
                      constraints: const BoxConstraints(maxWidth: 220),
                      onSelected: (value) {
                        if (value == 'clear_all') {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(t['clear_history'] ?? 'Clear History',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold)),
                              content: Text(
                                  t['are_you_sure_you_want_to_'] ??
                                      'Are you sure you want to clear all request history?',
                                  style: TextStyle(fontSize: 12)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(t['cancel'] ?? 'Cancel',
                                      style:
                                          const TextStyle(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref
                                        .read(historyProvider.notifier)
                                        .clearHistory();
                                    Navigator.pop(ctx);
                                  },
                                  child: Text(t['clear'] ?? 'Clear',
                                      style:
                                          const TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'clear_all',
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(t['clear_all'] ?? 'Clear all',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.normal)),
                        ),
                        const PopupMenuDivider(height: 1),
                        PopupMenuItem(
                          value: 'save_responses',
                          enabled: false,
                          height: 64,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Consumer(builder: (context, ref, _) {
                            final saveResponses =
                                ref.watch(saveResponsesProvider);
                            return GestureDetector(
                              onTap: () {
                                ref
                                    .read(saveResponsesProvider.notifier)
                                    .setSaveResponses(!saveResponses);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          t['save_responses'] ??
                                              'Save Responses',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.normal,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color)),
                                      SizedBox(
                                        height: 20,
                                        width: 32,
                                        child: Transform.scale(
                                          scale: 0.65,
                                          alignment: Alignment.centerRight,
                                          child: Switch(
                                            value: saveResponses,
                                            onChanged: (val) {
                                              ref
                                                  .read(saveResponsesProvider
                                                      .notifier)
                                                  .setSaveResponses(val);
                                            },
                                            activeThumbColor: Theme.of(context)
                                                .colorScheme
                                                .secondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                      t['retain_response_details_s'] ??
                                          'Retain response details such as payload and metadata to refer back to later.',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                          height: 1.1)),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: FaIcon(FontAwesomeIcons.ellipsis,
                            size: 13,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildFilterField(),
            Expanded(
              child: grouped.isEmpty
                  ? Center(
                      child: Text(t['no_history'] ?? 'No history',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (var entry in grouped.entries)
                          _buildExpandableSection(
                              entry.key,
                              [
                                for (var req in entry.value)
                                  HoverContainer(builder: (isHovered) {
                                    final isSelected =
                                        ref.watch(requestProvider).id == req.id;
                                    return InkWell(
                                      onTap: () {
                                        if (widget.onRequestTap != null) {
                                          widget.onRequestTap!(req);
                                        } else {
                                          ref
                                              .read(requestProvider.notifier)
                                              .loadRequest(req);
                                        }
                                      },
                                      child: Container(
                                        height: 24,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 1),
                                        padding: const EdgeInsets.only(
                                            left: 24, right: 8),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(6.0),
                                          color: isSelected || isHovered
                                              ? Colors.grey
                                                  .withValues(alpha: 0.15)
                                              : Colors.transparent,
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 32,
                                              child: Text(req.method,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: _getMethodColor(
                                                          req.method),
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            Expanded(
                                                child: Text(req.url,
                                                    style: const TextStyle(
                                                        fontSize: 12),
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                              initiallyExpanded: true),
                      ],
                    ),
            ),
          ],
        );
      case 3:
        return Center(
          child: Text(t['no_files'] ?? 'No files',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        );
      case 5:
        final categories = ToolsData.getCategories(t);
        if (categories.isEmpty) {
          return Center(
            child: Text(t['no_tools'] ?? 'No tools',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const ClampingScrollPhysics(),
          children: [
            for (final category in categories)
              _buildToolCategorySection(category, widget.onToolTap),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildTabIcon(int index, IconData icon, String tooltip) {
    final theme = Theme.of(context);
    final isSelected = _selectedTab == index;
    final hoverBackgroundColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.16);

    return HoverContainer(
      builder: (isHovered) {
        final showBackground = isSelected || isHovered;
        return Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedTab = index;
              });
              DatabaseHelper.instance
                  .setKeyValue('sidebar_selected_tab', index.toString());
            },
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 28,
              width: _railWidth,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: showBackground
                        ? hoverBackgroundColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: FaIcon(
                      icon,
                      size: 14,
                      color: isSelected
                          ? theme.textTheme.bodyMedium!.color
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomIcon(IconData icon,
      {required String tooltip, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    final hoverBackgroundColor = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.16);

    return HoverContainer(
      builder: (isHovered) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 36,
            width: _railWidth,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isHovered ? hoverBackgroundColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: FaIcon(
                    icon,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTreeNode({
    required String id,
    required int level,
    required bool initiallyExpanded,
    required Widget title,
    Widget? icon,
    Widget? actionButtons,
    required List<Widget> children,
    VoidCallback? onTap,
    bool isSection = false,
    bool isFolder = false,
    bool isSelected = false,
    bool showActionButtonsOnHover = true,
    double? paddingLeftOverride,
  }) {
    final controller = _tileControllers.putIfAbsent(
        id, () => TreeController(isExpanded: initiallyExpanded));
    final double paddingLeft =
        paddingLeftOverride ?? (isSection ? 16.0 : (24.0 + level * 8.0));
    final double height = isSection ? 24.0 : 24.0;
    final bool hasChildren = children.isNotEmpty ||
        isSection ||
        isFolder; // Quick check if it's a folder

    return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HoverContainer(
                builder: (isHovered) => InkWell(
                  onTap: () {
                    if (onTap != null) onTap();
                    if (hasChildren) {
                      controller.toggle();
                    }
                  },
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Container(
                    height: height,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    padding: EdgeInsets.only(left: paddingLeft - 8, right: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6.0),
                      color: (isSelected || isHovered) && !isSection
                          ? Colors.grey.withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                    width: double.infinity,
                    child: Row(
                      children: [
                        if (hasChildren)
                          AnimatedRotation(
                            turns: controller.isExpanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(
                              FontAwesomeIcons.chevronRight,
                              size: 9,
                              color: Colors.grey,
                            ),
                          )
                        else
                          const SizedBox(width: 12),
                        const SizedBox(width: 6),
                        if (icon != null) ...[
                          icon,
                          const SizedBox(width: 6),
                        ] else if (isFolder && !isSection) ...[
                          SvgPicture.asset(
                            controller.isExpanded
                                ? 'assets/icons/folder-opened.svg'
                                : 'assets/icons/folder.svg',
                            width: 14,
                            height: 14,
                            colorFilter: const ColorFilter.mode(
                                Colors.grey, BlendMode.srcIn),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Expanded(child: title),
                        if (actionButtons != null)
                          showActionButtonsOnHover
                              ? Visibility(
                                  visible: isHovered,
                                  maintainState: true,
                                  maintainAnimation: true,
                                  maintainSize: true,
                                  child: actionButtons,
                                )
                              : actionButtons,
                      ],
                    ),
                  ),
                ),
              ),
              if (controller.isExpanded && children.isNotEmpty) ...children,
            ],
          );
        });
  }

  Widget _buildNonExpandableSection(
    String title,
    List<Widget> children, {
    VoidCallback? onAdd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              if (onAdd != null)
                InkWell(
                  onTap: onAdd,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: FaIcon(
                      FontAwesomeIcons.plus,
                      size: 13,
                      color: Colors.grey,
                    ),
                  ),
                ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildExpandableSection(
    String title,
    List<Widget> children, {
    VoidCallback? onAdd,
    bool? initiallyExpanded,
    Widget? actionButtons,
    bool showActionButtonsOnHover = true,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        return _buildTreeNode(
          id: title,
          level: 0,
          initiallyExpanded: initiallyExpanded ?? (title == 'COLLECTIONS'),
          isSection: true,
          title: Text(
            title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Theme.of(context).textTheme.bodyMedium?.color),
          ),
          actionButtons: actionButtons ??
              (onAdd != null
                  ? InkWell(
                      onTap: onAdd,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: FaIcon(
                          FontAwesomeIcons.plus,
                          size: 13,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : null),
          showActionButtonsOnHover: showActionButtonsOnHover,
          children: children,
        );
      },
    );
  }


}
