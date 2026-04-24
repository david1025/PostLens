import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/settings_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/request_provider.dart';
import '../providers/capture_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/environment_provider.dart';
import '../../domain/models/collection_model.dart';
import '../../domain/models/http_request_model.dart';
import 'tools_pane.dart';
import 'import_dialog.dart';
import 'settings_dialog.dart';
import 'hover_overlay.dart';
import 'custom_search_box.dart';

const _topBackgroundColor = Color(0xFFEDEFF2);
const _workspaceDropdownOverlayGroup = 'header-workspace-dropdown';
const _searchDropdownOverlayGroup = 'header-search-dropdown';

class HeaderBar extends ConsumerWidget {
  final VoidCallback? onCreateWorkspace;
  final VoidCallback? onViewAllWorkspaces;
  final void Function(HttpRequestModel)? onRequestTap;
  final void Function(String id, bool isFolder, String name)? onCollectionTap;
  final void Function(String toolId, String name)? onToolTap;

  const HeaderBar({
    super.key,
    this.onCreateWorkspace,
    this.onViewAllWorkspaces,
    this.onRequestTap,
    this.onCollectionTap,
    this.onToolTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final isCaptureOpen = ref.watch(isCaptureOpenProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerBgColor = isDark ? const Color(0xFF222427) : _topBackgroundColor;

    return DragToMoveArea(
        child: Container(
      height: 32, // Reduced height
      padding: const EdgeInsets.only(bottom: 0), // Adjust padding
      color: headerBgColor,
      child: Stack(
        children: [
          // Left side
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!kIsWeb && Platform.isMacOS) const SizedBox(width: 72),
                const SizedBox(width: 8),
                _buildModeSwitch(context, ref),
                if (!isCaptureOpen) ...[
                  const SizedBox(width: 16),
                  Builder(builder: (buttonContext) {
                    return InkWell(
                      onTap: () {
                        _showWorkspaceDropdown(buttonContext, ref);
                      },
                      child: Row(
                        children: [
                          const FaIcon(FontAwesomeIcons.usersGear,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(activeWorkspace.name,
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          const FaIcon(FontAwesomeIcons.chevronDown,
                              size: 14, color: Colors.grey),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),

          // Center Search
          Align(
            alignment: Alignment.center,
            child: isCaptureOpen
                ? const SizedBox.shrink()
                : Builder(builder: (buttonContext) {
                    return InkWell(
                      onTap: () {
                        _showSearchDropdown(buttonContext, ref);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        width: 400,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(
                              color: Colors.grey.withOpacity(0.5), width: 1.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/search.svg',
                              width: 14,
                              height: 14,
                              colorFilter: const ColorFilter.mode(
                                  Colors.grey, BlendMode.srcIn),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  t['search'] ??
                                      'Search PostLens (append > to see and run commands)',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
          ),

          // Right side
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Settings',
                  child: InkWell(
                    onTap: () {
                      AppOverlayDialogs.showModalLike(
                        context: context,
                        barrierLabel: 'Settings',
                        builder: (context) =>
                            const SettingsDialog(),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: FaIcon(FontAwesomeIcons.gear, size: 14, color: Colors.grey),
                    ),
                  ),
                ),
              // Window controls
              if (!kIsWeb && !Platform.isMacOS) ...[
                _WindowControlButton(
                  type: _WindowControlButtonType.minimize,
                  onPressed: () async => await windowManager.minimize(),
                ),
                _WindowControlButton(
                  type: _WindowControlButtonType.maximize,
                  onPressed: () async {
                    if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                _WindowControlButton(
                  type: _WindowControlButtonType.close,
                  isClose: true,
                  onPressed: () async => await windowManager.close(),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  ));
  }

  Widget _buildModeSwitch(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final isCaptureOpen = ref.watch(isCaptureOpenProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2E31) : const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            left: isCaptureOpen ? 64 : 0,
            right: isCaptureOpen ? 0 : 64,
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeOption(
                context,
                'Request',
                !isCaptureOpen,
                () {
                  ref.read(isCaptureOpenProvider.notifier).state = false;
                },
              ),
              _buildModeOption(
                context,
                t['capture'] ?? 'Capture',
                isCaptureOpen,
                () {
                  ref.read(isCaptureOpenProvider.notifier).state = true;
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
      BuildContext context, String text, bool isSelected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? theme.textTheme.bodyMedium?.color
                  : theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
            child: Text(text),
          ),
        ),
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return const ImportDialog();
      },
    );
  }

  void _showWorkspaceDropdown(BuildContext context, WidgetRef ref) {
    DropdownOverlayController.showAnchored(
      context: context,
      anchorContext: context,
      panelSize: const Size(320, 360),
      placement: DropdownOverlayPlacement.bottomLeft,
      groupId: _workspaceDropdownOverlayGroup,
      debugLabel: 'header-workspace-dropdown',
      contentBuilder: (context, hide) => Material(
        color: Colors.transparent,
        child: _WorkspaceDropdownContent(
          onCreateWorkspace: () {
            hide();
            onCreateWorkspace?.call();
          },
          onViewAllWorkspaces: () {
            hide();
            onViewAllWorkspaces?.call();
          },
          onClose: hide,
        ),
      ),
    );
  }

  void _showSearchDropdown(BuildContext context, WidgetRef ref) {
    DropdownOverlayController.showAnchored(
      context: context,
      anchorContext: context,
      panelSize: const Size(600, 450),
      placement: DropdownOverlayPlacement.bottomCenter,
      groupId: _searchDropdownOverlayGroup,
      debugLabel: 'header-search-dropdown',
      barrierColor: Colors.black54,
      contentBuilder: (overlayContext, hide) => Material(
        color: Colors.transparent,
        child: _SearchDropdownContent(
          initialWidth: (context.findRenderObject() as RenderBox).size.width,
          onRequestTap: onRequestTap,
          onCollectionTap: onCollectionTap,
          onToolTap: onToolTap,
          onClose: hide,
        ),
      ),
    );
  }
}

class _SearchDropdownContent extends ConsumerStatefulWidget {
  final double initialWidth;
  final VoidCallback onClose;
  final void Function(HttpRequestModel)? onRequestTap;
  final void Function(String id, bool isFolder, String name)? onCollectionTap;
  final void Function(String toolId, String name)? onToolTap;

  const _SearchDropdownContent({
    required this.initialWidth,
    required this.onClose,
    this.onRequestTap,
    this.onCollectionTap,
    this.onToolTap,
  });

  @override
  ConsumerState<_SearchDropdownContent> createState() =>
      _SearchDropdownContentState();
}

class _SearchDropdownContentState
    extends ConsumerState<_SearchDropdownContent> {
  String _searchQuery = '';
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green;
      case 'POST':
        return Colors.orange;
      case 'PUT':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      case 'PATCH':
        return Colors.purple;
      case 'MQTT':
        return const Color(0xFFFF9800);
      case 'TCP':
        return const Color(0xFF009688);
      case 'UDP':
        return const Color(0xFF3F51B5);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final history = ref.watch(historyProvider);
    final activeWorkspace = ref.watch(activeWorkspaceProvider);
    final collections = ref.watch(activeWorkspaceCollectionsProvider);
    final environments = ref.watch(activeWorkspaceEnvironmentsProvider);

    return Container(
      width: 600,
      decoration: BoxDecoration(
        color: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF313236)
                : const Color(0xFFE9EDF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search input row
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [ 
                Expanded(
                  child: CustomSearchBox(
                    height: 32,
                    controller: _textController,
                    focusNode: _focusNode,
                    hintText: t['search'] ??
                        'Search PostLens (append > to see and run commands)',
                    onChanged: (val) => setState(() => _searchQuery = val),
                    padding: EdgeInsets.zero,
                    borderColor: Colors.transparent,
                    borderWidth: 0,
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  InkWell(
                    onTap: () {
                      _textController.clear();
                      setState(() => _searchQuery = '');
                      _focusNode.requestFocus();
                    },
                    child: const FaIcon(FontAwesomeIcons.xmark,
                        size: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: Theme.of(context).dividerColor),

          // Results / Recently Viewed
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400),
            child: _buildResultsList(history, activeWorkspace, collections, environments, t),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(
      List<dynamic> history,
      var activeWorkspace,
      List<CollectionModel> collections,
      List<dynamic> environments,
      Map<String, String> t) {
    final items = [];

    void addItem(String type, String title, String subtitle, var icon, Color iconColor, String time, String method, dynamic data) {
      if (_searchQuery.isEmpty || title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        items.add({
          'type': type,
          'title': title,
          'subtitle': subtitle,
          'icon': icon,
          'iconColor': iconColor,
          'time': time,
          'method': method,
          'data': data,
        });
      }
    }

    void findRequestsInCollection(List<CollectionNode> nodes, String path, String collectionId) {
      for (var node in nodes) {
        if (node is CollectionRequest) {
          addItem('request', node.name, '$path · Collection', null, Colors.grey, '', node.request.method, node.request);
        } else if (node is CollectionFolder) {
          addItem('folder', node.name, '$path · Collection Folder', FontAwesomeIcons.folder, Colors.amber, '', '', {'id': node.id, 'name': node.name, 'collectionId': collectionId});
          findRequestsInCollection(node.children, '$path / ${node.name}', collectionId);
        }
      }
    }

    if (_searchQuery.isEmpty) {
      // Add workspace
      addItem('workspace', activeWorkspace.name, 'Internal', FontAwesomeIcons.borderAll, Colors.grey, '1m', '', activeWorkspace);
    }

    // Add history
    final uniqueHistory = <String>{};
    for (var req in history) {
      final key = '${req.method}:${req.url}';
      if (!uniqueHistory.contains(key) &&
          req.url.isNotEmpty &&
          !req.url.startsWith('postlens://')) {
        uniqueHistory.add(key);
        final title = req.name.isNotEmpty ? req.name : req.url;
        addItem('request', title, '${activeWorkspace.name} / ${req.url.split('/').take(3).join('/')} · Internal', null, Colors.grey, '1h', req.method, req);
      }
    }

    // Add Collections & Requests
    for (var c in collections) {
      addItem('collection', c.name, 'Collection', FontAwesomeIcons.book, Colors.blueGrey, '', '', {'id': c.id, 'name': c.name});
      findRequestsInCollection(c.children, c.name, c.id);
    }

    // Add Environments
    for (var e in environments) {
      addItem('environment', e.name, 'Environment', FontAwesomeIcons.server, Colors.blue, '', 'ENV', e);
    }

    // Add Tools
    for (var cat in ToolsData.getCategories(t)) {
      for (var tool in cat.items) {
        addItem('tool', tool.name, 'Tool · ${cat.name}', tool.icon, tool.color, '', 'TOOL', tool);
      }
    }

    final displayItems = _searchQuery.isEmpty ? items.take(7).toList() : items;

    if (displayItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
            child:
                Text(t['no_results'] ?? 'No results found', style: const TextStyle(color: Colors.grey))),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final item = displayItems[index];
        final isFirst = index == 0;

        return InkWell(
          onTap: () {
            widget.onClose();
            final type = item['type'];
            final data = item['data'];
            
            if (type == 'request') {
              if (widget.onRequestTap != null) {
                widget.onRequestTap!(data);
              } else {
                ref.read(requestProvider.notifier).loadRequest(data);
              }
            } else if (type == 'tool') {
              if (widget.onToolTap != null) {
                widget.onToolTap!(data.id, data.name);
              }
            } else if (type == 'collection' || type == 'folder') {
              if (widget.onCollectionTap != null) {
                widget.onCollectionTap!(data['id'], type == 'folder', data['name']);
              }
            } else if (type == 'environment') {
              final newReq = HttpRequestModel(
                id: data.id,
                url: 'postlens://environment/${data.id}',
                method: 'ENV',
                name: data.name,
              );
              if (widget.onRequestTap != null) {
                widget.onRequestTap!(newReq);
              } else {
                ref.read(requestProvider.notifier).loadRequest(newReq);
              }
            }
          },
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: item['type'] != 'request'
                        ? Icon(item['icon'], size: 14, color: item['iconColor'])
                        : Text(item['method'],
                            style: TextStyle(
                                fontSize: 9,
                                color: _getMethodColor(item['method']),
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),

                // Texts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['title'],
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(item['subtitle'],
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),

                // Time and Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item['time'].isNotEmpty)
                      Text(item['time'],
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey)),
                    if (isFirst && _searchQuery.isEmpty) ...[
                      const SizedBox(width: 8),
                      Text(t['recently_viewed'] ?? 'RECENTLY VIEWED',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              letterSpacing: 0.5)),
                    ]
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceDropdownContent extends ConsumerStatefulWidget {
  final VoidCallback? onCreateWorkspace;
  final VoidCallback? onViewAllWorkspaces;
  final VoidCallback onClose;

  const _WorkspaceDropdownContent(
      {this.onCreateWorkspace, this.onViewAllWorkspaces, required this.onClose});

  @override
  ConsumerState<_WorkspaceDropdownContent> createState() =>
      _WorkspaceDropdownContentState();
}

class _WorkspaceDropdownContentState
    extends ConsumerState<_WorkspaceDropdownContent> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final workspaces = ref.watch(workspacesProvider);
    final activeWorkspace = ref.watch(activeWorkspaceProvider);

    final filteredWorkspaces = workspaces.where((w) {
      return w.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Theme.of(context).dialogTheme.backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF313236)
                : const Color(0xFFE9EDF1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search and Create row
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search workspaces...',
                        hintStyle:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              BorderSide(color: Colors.blue.withOpacity(0.5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              BorderSide(color: Colors.blue.withOpacity(0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: widget.onCreateWorkspace,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      side: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    child: Text(t['create'] ?? 'Create',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                            fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),

          // Workspace List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filteredWorkspaces.length,
              itemBuilder: (context, index) {
                final workspace = filteredWorkspaces[index];
                final isActive = activeWorkspace.id == workspace.id;

                return InkWell(
                  onTap: () {
                    ref
                        .read(activeWorkspaceProvider.notifier)
                        .setActiveWorkspace(workspace);
                    widget.onClose();
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: isActive
                        ? Theme.of(context).dividerColor.withOpacity(0.2)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).dividerColor.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const FaIcon(FontAwesomeIcons.lock,
                              size: 10, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            workspace.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isActive)
                          const FaIcon(FontAwesomeIcons.check,
                              size: 12, color: Colors.blue),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Divider(height: 1, color: Theme.of(context).dividerColor),

          // Bottom action
          InkWell(
            onTap: widget.onViewAllWorkspaces,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.borderAll,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 12),
                  Text(t['view_all_workspaces'] ?? 'View all workspaces', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isFa;

  const _HoverIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isFa = false,
  });

  @override
  _HoverIconButtonState createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: IconButton(
          icon: widget.isFa
              ? FaIcon(
                  widget.icon,
                  size: 14,
                  color: _isHovered
                      ? Theme.of(context).textTheme.bodyMedium!.color
                      : Colors.grey,
                )
              : Icon(
                  widget.icon,
                  size: 16,
                  color: _isHovered
                      ? Theme.of(context).textTheme.bodyMedium!.color
                      : Colors.grey,
                ),
          onPressed: widget.onPressed,
          splashRadius: 20,
        ),
      ),
    );
  }
}

enum _WindowControlButtonType { minimize, maximize, close }

class _WindowControlButton extends StatefulWidget {
  final _WindowControlButtonType type;
  final VoidCallback onPressed;
  final bool isClose;

  const _WindowControlButton({
    required this.type,
    required this.onPressed,
    this.isClose = false,
  });

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hoverColor = widget.isClose
        ? const Color(0xFFE81123)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06));
    final iconColor = _isHovering && widget.isClose
        ? Colors.white
        : (theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72) ??
            Colors.black87);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: widget.onPressed,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          width: 46,
          height: 32,
          color: _isHovering ? hoverColor : Colors.transparent,
          child: Center(
            child: SizedBox(
              width: 10,
              height: 10,
              child: CustomPaint(
                painter: _WindowControlGlyphPainter(
                  type: widget.type,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowControlGlyphPainter extends CustomPainter {
  final _WindowControlButtonType type;
  final Color color;

  const _WindowControlGlyphPainter({
    required this.type,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.square;

    switch (type) {
      case _WindowControlButtonType.minimize:
        final y = size.height * 0.72;
        canvas.drawLine(
          Offset(size.width * 0.15, y),
          Offset(size.width * 0.85, y),
          paint,
        );
        break;
      case _WindowControlButtonType.maximize:
        final rect = Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.18,
          size.width * 0.64,
          size.height * 0.64,
        );
        canvas.drawRect(rect, paint);
        break;
      case _WindowControlButtonType.close:
        canvas.drawLine(
          Offset(size.width * 0.2, size.height * 0.2),
          Offset(size.width * 0.8, size.height * 0.8),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.8, size.height * 0.2),
          Offset(size.width * 0.2, size.height * 0.8),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _WindowControlGlyphPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
