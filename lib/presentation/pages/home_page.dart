import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:window_manager/window_manager.dart';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/intents.dart';
import '../../domain/models/http_request_model.dart';
import '../../data/local/database_helper.dart';
import '../widgets/header_bar.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/import_dialog.dart';
import '../widgets/sidebar/sidebar.dart';
import '../widgets/request_pane.dart';
import '../widgets/response_pane.dart';
import '../widgets/workspace_overview.dart';
import '../widgets/tcp_pane.dart';
import '../widgets/udp_pane.dart';
import '../widgets/workspace_creation_pane.dart';
import '../widgets/all_workspaces_pane.dart';
import '../widgets/environment_creation_pane.dart';
import '../widgets/environment_editor_pane.dart';
import '../widgets/status_bar.dart';
import '../widgets/collection_pane.dart';
import '../widgets/console_pane.dart';
import '../widgets/capture_pane.dart';
import '../widgets/websocket_pane.dart';
import '../widgets/mqtt_pane.dart';
import '../widgets/socket_pane.dart';
import '../widgets/tools_pane.dart';
import '../widgets/hover_overlay.dart';
import '../utils/request_save_helper.dart';
import '../providers/request_provider.dart';
import '../providers/console_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/capture_provider.dart';
import '../providers/environment_provider.dart';
import '../../domain/models/environment_model.dart';
import 'home_page_widgets.dart';

const _tabPickerOverlayGroup = 'home-tab-picker-dropdown';
const _environmentDropdownOverlayGroup = 'home-environment-dropdown';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WindowListener {
  static const Color _workspaceTabBarColor = Color(0xFFF8F8F9);
  static const double _collapsedSidebarWidth = 48;
  late MultiSplitViewController _mainSplitController;
  late final ProviderSubscription<bool> _sidebarCollapsedSub;

  final MultiSplitViewController _workspaceSplitController =
      MultiSplitViewController(
    areas: [
      Area(flex: 0.5, min: 0.2), // Request Pane
      Area(flex: 0.5, min: 0.2), // Response Pane
    ],
  );

  int _activeTabIndex = -1; // -1 means overview, -2 means nothing is open
  final List<HttpRequestModel> _requestTabs = [];
  bool _isOverviewClosed = false;
  final ScrollController _tabScrollController = ScrollController();
  final GlobalKey _overviewTabKey = GlobalKey();
  final Map<int, GlobalKey> _tabKeys = {};

  late final ProviderSubscription<HttpRequestModel> _requestSub;
  Timer? _persistTimer;
  String? _lastSavedTabsJson;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _mainSplitController = _createMainSplitController(
        isCollapsed: ref.read(isSidebarContentCollapsedProvider));
    _sidebarCollapsedSub = ref.listenManual<bool>(
        isSidebarContentCollapsedProvider, (previous, next) {
      if (previous == null || previous == next) return;
      final old = _mainSplitController;
      setState(() {
        _mainSplitController = _createMainSplitController(isCollapsed: next);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old.dispose();
      });
    });

    _requestSub = ref.listenManual<HttpRequestModel>(requestProvider, (previous, next) {
      if (previous != next) {
        _saveActiveRequestState();
        _persistTimer?.cancel();
        _persistTimer = Timer(const Duration(milliseconds: 500), () {
          _persistTabsToDatabase();
        });
      }
    });

    // Load tabs from database or fallback to initialReq
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final tabsJsonStr =
            await DatabaseHelper.instance.getKeyValue('opened_tabs');
        if (tabsJsonStr != null && tabsJsonStr.isNotEmpty) {
          final tabsList = jsonDecode(tabsJsonStr) as List;
          final loadedTabs =
              tabsList.map((t) => HttpRequestModel.fromJson(t)).toList();

          if (loadedTabs.isNotEmpty) {
            final activeTabIdxStr =
                await DatabaseHelper.instance.getKeyValue('active_tab_index');
            final isOverviewClosedStr =
                await DatabaseHelper.instance.getKeyValue('is_overview_closed');

            setState(() {
              _requestTabs.clear();
              _requestTabs.addAll(loadedTabs);
              _activeTabIndex =
                  (activeTabIdxStr != null) ? int.parse(activeTabIdxStr) : 0;
              _isOverviewClosed = isOverviewClosedStr == 'true';

              if (_activeTabIndex >= _requestTabs.length) {
                _activeTabIndex = _requestTabs.length - 1;
              }
            });

            if (_activeTabIndex >= 0 && _activeTabIndex < _requestTabs.length) {
              final activeTab = _requestTabs[_activeTabIndex];
              if (!activeTab.url.startsWith('postlens://')) {
                ref.read(requestProvider.notifier).loadRequest(activeTab);
              }
            }
            return;
          }
        }
      } catch (e) {}

      final initialReq = ref.read(requestProvider);
      setState(() {
        _requestTabs.clear();
        _requestTabs.add(initialReq);
        _activeTabIndex = -1; // Start with overview
      });
    });
  }

  MultiSplitViewController _createMainSplitController(
      {required bool isCollapsed}) {
    return MultiSplitViewController(
      areas: [
        if (isCollapsed)
          Area(
            size: _collapsedSidebarWidth,
            min: _collapsedSidebarWidth,
            max: _collapsedSidebarWidth,
          )
        else
          Area(flex: 0.27, min: 0.2),
        if (isCollapsed) Area(flex: 1) else Area(flex: 0.73, min: 0.4),
      ],
    );
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _requestSub.close();
    windowManager.removeListener(this);
    _sidebarCollapsedSub.close();
    _mainSplitController.dispose();
    _workspaceSplitController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    _saveActiveRequestState();
    
    if (_persistTimer != null && _persistTimer!.isActive) {
      _persistTimer!.cancel();
      await _persistTabsToDatabase();
    } else {
      _persistTabsToDatabase(); // Run without await to close instantly if already mostly saved
    }

    try {
      await ref.read(captureProvider.notifier).stopCapture();
    } catch (e) {
      // Ignore errors on shutdown
    }

    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.destroy();
    }
  }

  void _ensureTabVisible(int index) {
    final key = index == -1 ? _overviewTabKey : _tabKeys[index];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _saveActiveRequestState() {
    if (_activeTabIndex >= 0 && _activeTabIndex < _requestTabs.length) {
      if (!_requestTabs[_activeTabIndex].url.startsWith('postlens://')) {
        _requestTabs[_activeTabIndex] = ref.read(requestProvider);
      }
    }
  }

  Future<void> _persistTabsToDatabase() async {
    try {
      final tabsJson = jsonEncode(_requestTabs.map((t) => t.toJson()).toList());
      if (_lastSavedTabsJson == tabsJson) return;
      _lastSavedTabsJson = tabsJson;
      await DatabaseHelper.instance.setKeyValue('opened_tabs', tabsJson);
      await DatabaseHelper.instance
          .setKeyValue('active_tab_index', _activeTabIndex.toString());
      await DatabaseHelper.instance
          .setKeyValue('is_overview_closed', _isOverviewClosed.toString());
    } catch (e) {}
  }

  bool _isManagedWorkspaceTab(HttpRequestModel request) {
    return request.url.startsWith('postlens://');
  }

  HttpRequestModel _resolveTabRequest(int index,
      {HttpRequestModel? currentRequest}) {
    final tab = _requestTabs[index];
    if (currentRequest != null &&
        _activeTabIndex == index &&
        !_isManagedWorkspaceTab(tab)) {
      return currentRequest;
    }
    return tab;
  }

  String _getTabTitle(HttpRequestModel req, Map<String, String> t) {
    String title = req.name.isNotEmpty
        ? req.name
        : (req.url.isEmpty ? 'New Request' : req.url);
    if (req.url == 'postlens://workspace/new') {
      title = 'New Workspace';
    } else if (req.url == 'postlens://workspaces/all') {
      title = t['all_workspaces'] ?? 'All Workspaces';
    } else if (req.url == 'postlens://environment/new') {
      title = 'New Environment';
    } else if (req.url.startsWith('postlens://tool/')) {
      title = req.name;
    } else if (req.url.startsWith('postlens://collection/') ||
        req.url.startsWith('postlens://folder/')) {
      title = req.name;
    } else if (req.url.startsWith('postlens://environment/')) {
      title = req.name;
    }
    return title;
  }

  String? _getTabMethod(HttpRequestModel req) {
    if (req.method == 'NEW' ||
        req.method == 'COL' ||
        req.method == 'ENV' ||
        req.method == 'TOOLS') {
      return null;
    }
    if (req.protocol == 'websocket' || req.protocol == 'ws') {
      return 'WS';
    }
    return req.protocol != 'http' ? req.protocol.toUpperCase() : req.method;
  }

  bool _canDuplicateTab(int index) {
    if (index < 0 || index >= _requestTabs.length) return false;
    return !_isManagedWorkspaceTab(_resolveTabRequest(index));
  }

  HttpRequestModel _duplicateRequestModel(HttpRequestModel source) {
    final json = Map<String, dynamic>.from(source.toJson())
      ..['id'] = DateTime.now().microsecondsSinceEpoch.toString();
    return HttpRequestModel.fromJson(json);
  }

  void _duplicateTab(int index) {
    if (!_canDuplicateTab(index)) return;

    _saveActiveRequestState();
    final source =
        _resolveTabRequest(index, currentRequest: ref.read(requestProvider));
    final duplicated = _duplicateRequestModel(source);

    setState(() {
      _requestTabs.insert(index + 1, duplicated);
      _activeTabIndex = index + 1;
      _tabKeys.clear();
    });

    ref.read(requestProvider.notifier).loadRequest(duplicated);
    _persistTabsToDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTabVisible(_activeTabIndex);
    });
  }

  void _switchTab(int index) {
    if (_activeTabIndex == index) return;

    // Save current active request state if we are moving away from a request tab
    _saveActiveRequestState();

    setState(() {
      _activeTabIndex = index;
    });

    _persistTabsToDatabase();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTabVisible(index);
    });

    // Load the new request state if we switched to a request tab
    if (index >= 0 && index < _requestTabs.length) {
      final req = _requestTabs[index];
      if (!req.url.startsWith('postlens://')) {
        ref.read(requestProvider.notifier).loadRequest(req);
      }
    }
  }

  void _addNewTab() {
    // Save current active request state
    _saveActiveRequestState();

    final newReq = HttpRequestModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: '',
      method: 'GET',
      protocol: 'http',
      name: 'New Request',
    );

    setState(() {
      _requestTabs.add(newReq);
      _activeTabIndex = _requestTabs.length - 1;
      _tabKeys.clear();
    });

    ref.read(requestProvider.notifier).loadRequest(newReq);
    _persistTabsToDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTabVisible(_activeTabIndex);
    });
  }

  void _closeOverview() {
    setState(() {
      _isOverviewClosed = true;
      if (_activeTabIndex == -1) {
        if (_requestTabs.isNotEmpty) {
          _activeTabIndex = 0;
          _loadRequestTab(0);
        } else {
          _activeTabIndex = -2;
        }
      }
    });
    _persistTabsToDatabase();
  }

  void _loadRequestTab(int index) {
    if (index >= 0 && index < _requestTabs.length) {
      final req = _requestTabs[index];
      if (!req.url.startsWith('postlens://')) {
        ref.read(requestProvider.notifier).loadRequest(req);
      }
    }
  }

  Future<_DirtyTabCloseAction> _confirmCloseDirtyTab(
      HttpRequestModel request) async {
    final t = ref.read(translationsProvider);
    final title = request.name.isNotEmpty
        ? request.name
        : (request.url.isNotEmpty ? request.url : 'New Request');

    final action = await showDialog<_DirtyTabCloseAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            t['unsaved_changes'] ?? 'Unsaved changes',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'The tab "$title" has unsaved changes. You can save before closing, or discard the draft.',
            style: const TextStyle(fontSize: 12),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DirtyTabCloseAction.cancel),
              child: Text(t['cancel'] ?? 'Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DirtyTabCloseAction.discard),
              child: Text(t['discard'] ?? 'Discard'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop(_DirtyTabCloseAction.saveAndClose),
              child: Text(t['save_and_close'] ?? 'Save and Close'),
            ),
          ],
        );
      },
    );

    return action ?? _DirtyTabCloseAction.cancel;
  }

  void _closeTabImmediate(int index) {
    final removedTab = _requestTabs[index];
    final isRequestTab = !removedTab.url.startsWith('postlens://');

    setState(() {
      _requestTabs.removeAt(index);
      _tabKeys.clear();
      if (_activeTabIndex == index) {
        if (_requestTabs.isEmpty) {
          _activeTabIndex = _isOverviewClosed ? -2 : -1;
        } else {
          int nextIndex = index - 1;
          if (nextIndex == -1) {
            if (!_isOverviewClosed) {
              _activeTabIndex = -1;
            } else {
              _activeTabIndex = 0;
              _loadRequestTab(0);
            }
          } else {
            _activeTabIndex = nextIndex;
            _loadRequestTab(nextIndex);
          }
        }
      } else if (_activeTabIndex > index) {
        _activeTabIndex--;
      }
    });

    _persistTabsToDatabase();

    if (isRequestTab) {
      ref.read(requestProvider.notifier).removeRequestCache(removedTab.id);
      ref.invalidate(requestPageUiProvider(removedTab.id));
      ref.invalidate(responseProvider(removedTab.id));
      ref.invalidate(isSendingProvider(removedTab.id));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_activeTabIndex == -2) return;
      _ensureTabVisible(_activeTabIndex);
    });
  }

  Future<bool> _closeTabInternal(int index, {required bool force}) async {
    if (index == -1) {
      if (_isOverviewClosed) return false;
      _closeOverview();
      return true;
    }

    if (index < 0 || index >= _requestTabs.length) return false;

    final rawTab = _requestTabs[index];
    final isRequestTab = !rawTab.url.startsWith('postlens://');
    if (force || !isRequestTab) {
      _closeTabImmediate(index);
      return true;
    }

    final requestToClose =
        (_activeTabIndex == index) ? ref.read(requestProvider) : rawTab;
    final isDirty = ref.read(requestDirtyProvider(requestToClose.id));
    if (isDirty) {
      final action = await _confirmCloseDirtyTab(requestToClose);
      if (action == _DirtyTabCloseAction.cancel) return false;
      if (action == _DirtyTabCloseAction.saveAndClose) {
        final savedRequest = await saveRequest(context, ref, requestToClose);
        if (savedRequest == null || !mounted) return false;
      }
    }

    if (!mounted) return false;
    _closeTabImmediate(index);
    return true;
  }

  Future<void> _closeTab(int index) async {
    await _closeTabInternal(index, force: false);
  }

  Future<void> _forceCloseTab(int index) async {
    await _closeTabInternal(index, force: true);
  }

  Future<bool> _closeTabsByIndex(List<int> indexes,
      {required bool force}) async {
    final sortedIndexes = indexes.toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    for (final index in sortedIndexes) {
      final didClose = await _closeTabInternal(index, force: force);
      if (!didClose) return false;
    }

    return true;
  }

  Future<void> _closeOtherTabs(int selectedIndex, {required bool force}) async {
    final targetTabId =
        selectedIndex >= 0 && selectedIndex < _requestTabs.length
            ? _requestTabs[selectedIndex].id
            : null;
    final indexesToClose = <int>[];

    for (int i = 0; i < _requestTabs.length; i++) {
      if (i != selectedIndex) {
        indexesToClose.add(i);
      }
    }

    final didClose = await _closeTabsByIndex(indexesToClose, force: force);
    if (!didClose || !mounted) return;

    if (selectedIndex != -1 && !_isOverviewClosed) {
      _closeOverview();
    }

    if (!mounted) return;

    if (selectedIndex == -1) {
      _switchTab(-1);
    } else {
      final nextIndex = _requestTabs.indexWhere((tab) => tab.id == targetTabId);
      if (nextIndex != -1) {
        _switchTab(nextIndex);
      }
    }

    _persistTabsToDatabase();
  }

  Future<void> _closeAllTabs({required bool force}) async {
    final indexes = List<int>.generate(_requestTabs.length, (index) => index);
    final didClose = await _closeTabsByIndex(indexes, force: force);
    if (!didClose || !mounted) return;

    if (!_isOverviewClosed) {
      _closeOverview();
    }
    _persistTabsToDatabase();
  }

  void _openRequestInTab(HttpRequestModel req) {
    // Save current active request state
    _saveActiveRequestState();

    // Check if the request is already open in a tab
    int existingIndex = _requestTabs.indexWhere((t) => t.id == req.id);
    if (existingIndex != -1) {
      // Switch to existing tab and load cached data (preserve user modifications)
      setState(() {
        _activeTabIndex = existingIndex;
      });
      _persistTabsToDatabase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureTabVisible(existingIndex);
      });
      ref
          .read(requestProvider.notifier)
          .loadRequest(_requestTabs[existingIndex]);
    } else {
      // Add new tab
      setState(() {
        _requestTabs.add(req);
        _activeTabIndex = _requestTabs.length - 1;
        _tabKeys.clear();
      });
      ref.read(requestProvider.notifier).loadRequest(req);
      _persistTabsToDatabase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureTabVisible(_activeTabIndex);
      });
    }
  }

  void _openCollectionInTab(String id, bool isFolder, String name) {
    // Save current active request state
    _saveActiveRequestState();

    final url =
        isFolder ? 'postlens://folder/$id' : 'postlens://collection/$id';
    int existingIndex = _requestTabs.indexWhere((t) => t.url == url);

    if (existingIndex != -1) {
      setState(() {
        _activeTabIndex = existingIndex;
      });
      _persistTabsToDatabase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureTabVisible(existingIndex);
      });
    } else {
      final newTab = HttpRequestModel(
        id: 'collection_tab_${DateTime.now().millisecondsSinceEpoch}',
        url: url,
        method: 'COL',
        name: name,
      );
      setState(() {
        _requestTabs.add(newTab);
        _activeTabIndex = _requestTabs.length - 1;
        _tabKeys.clear();
      });
      _persistTabsToDatabase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureTabVisible(_activeTabIndex);
      });
    }
  }

  void _addNewWorkspaceTab() {
    final newWorkspaceTab = HttpRequestModel(
      id: 'workspace_new_${DateTime.now().millisecondsSinceEpoch}',
      url: 'postlens://workspace/new',
      method: 'NEW',
      name: 'New Workspace',
    );

    setState(() {
      _requestTabs.add(newWorkspaceTab);
      _activeTabIndex = _requestTabs.length - 1;
      _tabKeys.clear();
    });
    _persistTabsToDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTabVisible(_activeTabIndex);
    });
  }

  void _openAllWorkspacesTab() {
    final t = ref.read(translationsProvider);
    final allWorkspacesTab = HttpRequestModel(
      id: 'workspaces_all_${DateTime.now().millisecondsSinceEpoch}',
      url: 'postlens://workspaces/all',
      method: 'WORKSPACE',
      name: t['all_workspaces'] ?? 'All Workspaces',
    );

    // Check if already open
    int existingIndex =
        _requestTabs.indexWhere((t) => t.url == 'postlens://workspaces/all');
    if (existingIndex != -1) {
      setState(() {
        _activeTabIndex = existingIndex;
      });
      _persistTabsToDatabase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureTabVisible(existingIndex);
      });
      return;
    }

    setState(() {
      _requestTabs.add(allWorkspacesTab);
      _activeTabIndex = _requestTabs.length - 1;
      _tabKeys.clear();
    });
    _persistTabsToDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTabVisible(_activeTabIndex);
    });
  }

  void _openToolInTab(String toolId, String name) {
    final url = 'postlens://tool/$toolId';
    int existingIndex = _requestTabs.indexWhere((t) => t.url == url);

    if (existingIndex != -1) {
      setState(() {
        _activeTabIndex = existingIndex;
      });
      _persistTabsToDatabase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureTabVisible(existingIndex);
      });
    } else {
      final newTab = HttpRequestModel(
        id: 'tool_${DateTime.now().millisecondsSinceEpoch}',
        url: url,
        method: 'TOOLS',
        name: name,
      );
      setState(() {
        _requestTabs.add(newTab);
        _activeTabIndex = _requestTabs.length - 1;
        _tabKeys.clear();
      });
      _persistTabsToDatabase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureTabVisible(_activeTabIndex);
      });
    }
  }

  void _openSettings() {
    AppOverlayDialogs.showModalLike(
      context: context,
      barrierLabel: 'Settings',
      builder: (context) => const SettingsDialog(),
    );
  }

  void _openImportDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return const ImportDialog();
      },
    );
  }

  void _openOverviewTab() {
    _saveActiveRequestState();
    setState(() {
      _isOverviewClosed = false;
      _activeTabIndex = -1;
    });
    _persistTabsToDatabase();
  }

  void _addProtocolTab({
    required String protocol,
    required String method,
    required String name,
  }) {
    _saveActiveRequestState();

    final newReq = HttpRequestModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: '',
      method: method,
      protocol: protocol,
      name: name,
    );

    setState(() {
      _requestTabs.add(newReq);
      _activeTabIndex = _requestTabs.length - 1;
      _tabKeys.clear();
    });

    ref.read(requestProvider.notifier).loadRequest(newReq);
    _persistTabsToDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTabVisible(_activeTabIndex);
    });
  }

  void _addNewEnvironmentTab() {
    final newEnvironmentTab = HttpRequestModel(
      id: 'environment_new_${DateTime.now().millisecondsSinceEpoch}',
      url: 'postlens://environment/new',
      method: 'ENV',
      name: 'New Environment',
    );

    setState(() {
      _requestTabs.add(newEnvironmentTab);
      _activeTabIndex = _requestTabs.length - 1;
      _tabKeys.clear();
    });
    _persistTabsToDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureTabVisible(_activeTabIndex);
    });
  }

  void _openSearch() {
    if (_requestTabs.isNotEmpty || !_isOverviewClosed) {
      _openTabPicker(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSidebarCollapsed = ref.watch(isSidebarContentCollapsedProvider);
    final isCaptureOpen = ref.watch(isCaptureOpenProvider);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyN, control: true):
            NewRequestIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            NewRequestIntent(),
        SingleActivator(LogicalKeyboardKey.keyT, control: true):
            NewRequestIntent(),
        SingleActivator(LogicalKeyboardKey.keyT, meta: true):
            NewRequestIntent(),
        SingleActivator(LogicalKeyboardKey.keyO, control: true): ImportIntent(),
        SingleActivator(LogicalKeyboardKey.keyO, meta: true): ImportIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, control: true):
            CloseTabIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, control: true, alt: true):
            ForceCloseTabIntent(),
        SingleActivator(LogicalKeyboardKey.keyW, meta: true): CloseTabIntent(),
        SingleActivator(LogicalKeyboardKey.tab, control: true): NextTabIntent(),
        SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
            PrevTabIntent(),
        SingleActivator(LogicalKeyboardKey.comma, control: true):
            SettingsIntent(),
        SingleActivator(LogicalKeyboardKey.comma, meta: true): SettingsIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, control: true): SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true): SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true): SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true): SearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewRequestIntent: CallbackAction<NewRequestIntent>(
              onInvoke: (intent) => _addNewTab()),
          ImportIntent: CallbackAction<ImportIntent>(
              onInvoke: (intent) => _openImportDialog()),
          CloseTabIntent: CallbackAction<CloseTabIntent>(onInvoke: (intent) {
            if (_activeTabIndex >= 0 && _activeTabIndex < _requestTabs.length) {
              _closeTab(_activeTabIndex);
            } else if (_activeTabIndex == -1 && !_isOverviewClosed) {
              _closeOverview();
            }
            return null;
          }),
          ForceCloseTabIntent:
              CallbackAction<ForceCloseTabIntent>(onInvoke: (intent) {
            if (_activeTabIndex >= 0 && _activeTabIndex < _requestTabs.length) {
              _forceCloseTab(_activeTabIndex);
            } else if (_activeTabIndex == -1 && !_isOverviewClosed) {
              _closeOverview();
            }
            return null;
          }),
          NextTabIntent: CallbackAction<NextTabIntent>(onInvoke: (intent) {
            if (_requestTabs.isNotEmpty) {
              int next = (_activeTabIndex + 1) % _requestTabs.length;
              _switchTab(next);
            }
            return null;
          }),
          PrevTabIntent: CallbackAction<PrevTabIntent>(onInvoke: (intent) {
            if (_requestTabs.isNotEmpty) {
              int prev = (_activeTabIndex - 1) % _requestTabs.length;
              if (prev < 0) prev = _requestTabs.length - 1;
              _switchTab(prev);
            }
            return null;
          }),
          SettingsIntent: CallbackAction<SettingsIntent>(
              onInvoke: (intent) => _openSettings()),
          SearchIntent:
              CallbackAction<SearchIntent>(onInvoke: (intent) => _openSearch()),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF222427)
                : const Color(0xFFEDEFF2),
            body: Column(
              children: [
                HeaderBar(
                  onCreateWorkspace: _addNewWorkspaceTab,
                  onViewAllWorkspaces: _openAllWorkspacesTab,
                  onRequestTap: _openRequestInTab,
                  onCollectionTap: _openCollectionInTab,
                  onToolTap: _openToolInTab,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Offstage(
                        offstage: isCaptureOpen,
                        child: MultiSplitViewTheme(
                          data: MultiSplitViewThemeData(
                            dividerThickness: 0,
                            dividerHandleBuffer: 4,
                            dividerPainter: DividerPainters.background(
                              color: Colors.transparent,
                              highlightedColor: Colors.transparent,
                            ),
                          ),
                          child: MultiSplitView(
                            key: ValueKey(isSidebarCollapsed),
                            controller: _mainSplitController,
                            builder: (BuildContext context, Area area) {
                              if (area.index == 0) {
                                return Sidebar(
                                  isContentCollapsed: isSidebarCollapsed,
                                  onRequestTap: _openRequestInTab,
                                  onCollectionTap: _openCollectionInTab,
                                  onToolTap: _openToolInTab,
                                );
                              }
                              return _buildMainWorkspace();
                            },
                          ),
                        ),
                      ),
                      Offstage(
                        offstage: !isCaptureOpen,
                        child: const CapturePane(),
                      ),
                    ],
                  ),
                ),
                const StatusBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainWorkspace() {
    final isConsoleOpen = ref.watch(isConsoleOpenProvider);
    final theme = Theme.of(context);
    final workspaceBackgroundColor = theme.brightness == Brightness.dark
        ? const Color(0xFF1A1B1D)
        : Colors.white;
    final workspaceTheme = theme.brightness == Brightness.dark
        ? theme.copyWith(
            scaffoldBackgroundColor: const Color(0xFF1A1B1D),
            canvasColor: const Color(0xFF1A1B1D),
          )
        : theme.copyWith(
            scaffoldBackgroundColor: Colors.white,
            canvasColor: Colors.white,
          );

    return Theme(
      data: workspaceTheme,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 6, 6),
        child: Container(
          decoration: BoxDecoration(
            color: workspaceBackgroundColor,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            child: Column(
              children: [
                _buildTabBar(),
                Expanded(
                  child: _activeTabIndex == -1 && !_isOverviewClosed
                      ? const WorkspaceOverview()
                      : (_activeTabIndex == -2 ||
                              (_requestTabs.isEmpty && _isOverviewClosed))
                          ? _buildEmptyWorkspaceState()
                          : _buildRequestResponse(),
                ),
                if (isConsoleOpen)
                  const SizedBox(
                    height: 250,
                    child: ConsolePane(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequestResponse() {
    final tabRequest = _requestTabs[_activeTabIndex];
    final activeRequest = (!tabRequest.url.startsWith('postlens://'))
        ? ref.watch(requestProvider)
        : tabRequest;
    if (activeRequest.url == 'postlens://workspace/new') {
      return WorkspaceCreationPane(
        onSaved: () {
          _closeTab(_activeTabIndex);
        },
      );
    } else if (activeRequest.url == 'postlens://workspaces/all') {
      return const AllWorkspacesPane();
    } else if (activeRequest.url == 'postlens://environment/new') {
      return EnvironmentCreationPane(
        onSaved: () {
          _closeTab(_activeTabIndex);
        },
      );
    } else if (activeRequest.url.startsWith('postlens://collection/')) {
      final id = activeRequest.url.substring('postlens://collection/'.length);
      return CollectionPane(collectionId: id, isFolder: false);
    } else if (activeRequest.url.startsWith('postlens://folder/')) {
      final id = activeRequest.url.substring('postlens://folder/'.length);
      return CollectionPane(collectionId: id, isFolder: true);
    } else if (activeRequest.url.startsWith('postlens://environment/')) {
      if (activeRequest.url != 'postlens://environment/new') {
        final id =
            activeRequest.url.substring('postlens://environment/'.length);
        return EnvironmentEditorPane(environmentId: id);
      }
    } else if (activeRequest.url.startsWith('postlens://tool/')) {
      final id = activeRequest.url.substring('postlens://tool/'.length);
      return ToolsPane(toolId: id);
    }

    if (activeRequest.protocol.toLowerCase() == 'ws' ||
        activeRequest.protocol.toLowerCase() == 'websocket' ||
        activeRequest.method.toUpperCase() == 'WS' ||
        activeRequest.method.toUpperCase() == 'WEBSOCKET') {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: WebSocketPane(key: ValueKey('ws_${activeRequest.id}')),
      );
    } else if (activeRequest.protocol.toLowerCase() == 'mqtt' ||
        activeRequest.method.toUpperCase() == 'MQTT') {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: MqttPane(key: ValueKey('mqtt_${activeRequest.id}')),
      );
    } else if (activeRequest.protocol.toLowerCase() == 'socket.io' ||
        activeRequest.protocol.toLowerCase() == 'socket' ||
        activeRequest.method == 'SOCKET.IO' ||
        activeRequest.method.toUpperCase() == 'SOCKET') {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: SocketPane(key: ValueKey('socket_${activeRequest.id}')),
      );
    } else if (activeRequest.protocol.toLowerCase() == 'tcp' ||
        activeRequest.method.toUpperCase() == 'TCP') {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: TcpPane(key: ValueKey('tcp_${activeRequest.id}')),
      );
    } else if (activeRequest.protocol.toLowerCase() == 'udp' ||
        activeRequest.method.toUpperCase() == 'UDP') {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: UdpPane(key: ValueKey('udp_${activeRequest.id}')),
      );
    }

    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 1,
        dividerHandleBuffer: 10,
        dividerPainter: DividerPainters.background(
          color: Theme.of(context).dividerColor,
          highlightedColor: Theme.of(context).colorScheme.primary,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: MultiSplitView(
          axis: Axis.vertical,
          controller: _workspaceSplitController,
          builder: (BuildContext context, Area area) {
            if (area.index == 0) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: RequestPane(key: ValueKey('request_${activeRequest.id}')),
              );
            }
            return ResponsePane(key: ValueKey('response_${activeRequest.id}'));
          },
        ),
      ),
    );
  }

  Widget _buildEnvironmentSelector() {
    final t = ref.watch(translationsProvider);
    final environments = ref.watch(activeWorkspaceEnvironmentsProvider);
    final activeEnvironmentId = ref.watch(activeEnvironmentIdProvider);

    // Find the valid environment ID if it exists in the current list
    String? validActiveId;
    if (activeEnvironmentId != null &&
        environments.any((env) => env.id == activeEnvironmentId)) {
      validActiveId = activeEnvironmentId;
    }

    // Determine display name
    String displayName;
    if (validActiveId != null) {
      final env = environments.where((e) => e.id == validActiveId).firstOrNull;
      displayName = env?.name ?? (t['no_environment'] ?? 'No Environment');
    } else {
      displayName = t['no_environment'] ?? 'No Environment';
    }

    return Builder(builder: (buttonContext) {
      return InkWell(
        onTap: () => _showEnvironmentDropdown(buttonContext),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              const FaIcon(FontAwesomeIcons.chevronDown,
                  size: 10, color: Colors.grey),
            ],
          ),
        ),
      );
    });
  }

  void _showEnvironmentDropdown(BuildContext context) {
    DropdownOverlayController.showAnchored(
      context: context,
      anchorContext: context,
      panelSize: const Size(280, 340),
      placement: DropdownOverlayPlacement.bottomRight,
      groupId: _environmentDropdownOverlayGroup,
      debugLabel: 'home-environment-dropdown',
      contentBuilder: (overlayContext, hide) => Material(
        color: Colors.transparent,
        child: EnvironmentDropdownContent(
          onSelected: (envId) {
            ref.read(activeEnvironmentIdProvider.notifier).state = envId;
            hide();
          },
          onAddNew: () {
            hide();
            _addNewEnvironmentTab();
          },
          onClose: hide,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    if (_isOverviewClosed && _requestTabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final t = ref.watch(translationsProvider);
    final currentRequest = ref.watch(requestProvider);
    const tabBarButtonConstraints =
        BoxConstraints.tightFor(width: 28, height: 32);

    return Container(
      height: 32,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF17191A)
          : const Color(0xFFF9FAFB),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              controller: _tabScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                if (!_isOverviewClosed)
                  _buildTabItem(
                    key: _overviewTabKey,
                    title: t['overview'] ?? 'Overview',
                    isActive: _activeTabIndex == -1,
                    isOverview: true,
                    onTap: () => _switchTab(-1),
                    onClose: _closeOverview,
                    onSecondaryTapDown: (details) =>
                        _showTabContextMenu(details, -1),
                  ),
                for (int i = 0; i < _requestTabs.length; i++) ...[
                  Builder(
                    builder: (context) {
                      final req =
                          _resolveTabRequest(i, currentRequest: currentRequest);
                      final isDirty = !req.url.startsWith('postlens://') &&
                          ref.watch(requestDirtyProvider(req.id));

                      Widget? toolIcon;
                      if (req.method == 'TOOLS' && req.url.startsWith('postlens://tool/')) {
                        final toolId = req.url.substring('postlens://tool/'.length);
                        final tool = ToolsData.getToolById(toolId, t);
                        if (tool != null) {
                          toolIcon = Icon(tool.icon, size: 12, color: tool.color);
                        }
                      }

                      return _buildTabItem(
                        key: _tabKeys.putIfAbsent(i, () => GlobalKey()),
                        title: _getTabTitle(req, t),
                        isActive: _activeTabIndex == i,
                        showDirtyIndicator: isDirty,
                        method: _getTabMethod(req),
                        protocol: req.protocol,
                        customIcon: toolIcon,
                        onTap: () => _switchTab(i),
                        onClose: () => _closeTab(i),
                        onSecondaryTapDown: (details) =>
                            _showTabContextMenu(details, i),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: tabBarButtonConstraints,
            visualDensity: VisualDensity.compact,
            icon: const FaIcon(
              FontAwesomeIcons.plus,
              size: 14,
              color: Colors.grey,
            ),
            onPressed: _addNewTab,
            splashRadius: 18,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Builder(
              builder: (buttonContext) {
                return IconButton(
                  padding: EdgeInsets.zero,
                  constraints: tabBarButtonConstraints,
                  visualDensity: VisualDensity.compact,
                  icon: const FaIcon(FontAwesomeIcons.chevronDown,
                      size: 12, color: Colors.grey),
                  onPressed: () => _openTabPicker(buttonContext),
                  splashRadius: 18,
                );
              },
            ),
          ),
          _buildEnvironmentSelector(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildEmptyWorkspaceState() {
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconBackground = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  size: 56,
                  color: theme.textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.28),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                t['noOpenTabs'] ?? 'No open tabs',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t['noOpenTabsDesc'] ??
                    'You can quickly create new requests or workspaces, or import existing data to continue working.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.68),
                ),
              ),
              const SizedBox(height: 30),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  children: [
                    _buildEmptyStatePrimaryAction(
                      iconWidget: const FaIcon(
                        FontAwesomeIcons.plus,
                        size: 18,
                        color: Colors.grey,
                      ),
                      label: t['newRequest'] ?? 'New Request',
                      shortcut: 'Ctrl N',
                      onTap: _addNewTab,
                    ),
                    _buildEmptyStatePrimaryAction(
                      icon: Icons.file_upload_outlined,
                      label: t['importData'] ?? 'Import Data',
                      shortcut: 'Ctrl O',
                      onTap: _openImportDialog,
                    ),
                    _buildEmptyStatePrimaryAction(
                      icon: Icons.space_dashboard_outlined,
                      label: t['openWorkspaceOverview'] ??
                          'Open Workspace Overview',
                      onTap: _openOverviewTab,
                    ),
                    _buildEmptyStatePrimaryAction(
                      icon: Icons.settings_outlined,
                      label: t['openSettings'] ?? 'Open Settings',
                      shortcut: 'Ctrl ,',
                      onTap: _openSettings,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildEmptyStateQuickAction(
                    icon: Icons.language,
                    label: 'HTTP',
                    onTap: _addNewTab,
                  ),
                  _buildEmptyStateQuickAction(
                    icon: Icons.sync_alt_rounded,
                    label: 'WebSocket',
                    onTap: () => _addProtocolTab(
                      protocol: 'websocket',
                      method: 'GET',
                      name: 'New WebSocket',
                    ),
                  ),
                  _buildEmptyStateQuickAction(
                    icon: Icons.sensors_outlined,
                    label: 'MQTT',
                    onTap: () => _addProtocolTab(
                      protocol: 'mqtt',
                      method: 'GET',
                      name: 'New MQTT',
                    ),
                  ),
                  _buildEmptyStateQuickAction(
                    icon: Icons.settings_ethernet,
                    label: 'Socket.IO',
                    onTap: () => _addProtocolTab(
                      protocol: 'socket.io',
                      method: 'GET',
                      name: 'New Socket.IO',
                    ),
                  ),
                  _buildEmptyStateQuickAction(
                    icon: Icons.workspaces_outline,
                    label: 'Workspace',
                    onTap: _addNewWorkspaceTab,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStatePrimaryAction({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback onTap,
    String? shortcut,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: HoverActionSurface(
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        onTap: onTap,
        child: Row(
          children: [
            if (iconWidget != null)
              iconWidget
            else if (icon != null)
              Icon(icon, size: 18, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            if (shortcut != null) _buildShortcutPill(shortcut),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return HoverQuickActionCard(
      width: 112,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutPill(String shortcut) {
    final keys = shortcut
        .split(RegExp(r'[\s+]+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final key in keys) ShortcutKeyCap(label: key),
      ],
    );
  }

  Widget _buildTabItem({
    Key? key,
    required String title,
    required bool isActive,
    bool showDirtyIndicator = false,
    String? method,
    String? protocol,
    Widget? customIcon,
    bool isOverview = false,
    required VoidCallback onTap,
    VoidCallback? onClose,
    GestureTapDownCallback? onSecondaryTapDown,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabSelectedBackgroundColor =
        isDark ? Colors.transparent : Colors.white;
    Color methodColor =
        method != null ? _getMethodColor(method) : Colors.transparent;

    Widget? protocolIcon;
    if (protocol != null) {
      if (protocol == 'websocket' || protocol == 'ws') {
        protocolIcon = const FaIcon(FontAwesomeIcons.plug,
            size: 12, color: Color(0xFF9C27B0));
      } else if (protocol == 'socket.io' || protocol == 'socket') {
        protocolIcon = const FaIcon(FontAwesomeIcons.circleNodes,
            size: 12, color: Color(0xFFE91E63));
      } else if (protocol == 'mqtt') {
        protocolIcon = const FaIcon(FontAwesomeIcons.satelliteDish,
            size: 12, color: Color(0xFFFF9800));
      } else if (protocol == 'grpc') {
        protocolIcon = const FaIcon(FontAwesomeIcons.server,
            size: 12, color: Color(0xFF2196F3));
      } else if (protocol == 'tcp') {
        protocolIcon = const FaIcon(FontAwesomeIcons.networkWired,
            size: 12, color: Color(0xFF009688));
      } else if (protocol == 'udp') {
        protocolIcon = const FaIcon(FontAwesomeIcons.broadcastTower,
            size: 12, color: Color(0xFF3F51B5));
      }
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: onSecondaryTapDown,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isActive ? tabSelectedBackgroundColor : Colors.transparent,
              borderRadius:
                  isDark ? BorderRadius.zero : BorderRadius.circular(5),
              border: isDark && isActive
                  ? Border(
                      bottom: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2.0))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isOverview)
                  const FaIcon(FontAwesomeIcons.gauge,
                      size: 14, color: Colors.grey)
                else if (customIcon != null)
                  customIcon
                else if (protocolIcon != null)
                  protocolIcon
                else if (method != null)
                  Text(method,
                      style: TextStyle(
                          fontSize: 11,
                          color: methodColor,
                          fontWeight: FontWeight.bold)),
                if (isOverview || customIcon != null || protocolIcon != null || method != null)
                  const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                        fontSize: 11,
                        color: isActive
                            ? Theme.of(context).textTheme.bodyMedium!.color!
                            : Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (showDirtyIndicator) const SizedBox(width: 6),
                if (showDirtyIndicator)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB400),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (onClose != null) const SizedBox(width: 12),
                if (onClose != null)
                  InkWell(
                    onTap: onClose,
                    child: const FaIcon(FontAwesomeIcons.xmark,
                        size: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showTabContextMenu(TapDownDetails details, int tabIndex) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final visibleTabCount = _requestTabs.length + (_isOverviewClosed ? 0 : 1);
    final canDuplicate = _canDuplicateTab(tabIndex);
    final hasOtherTabs = visibleTabCount > 1;

    final action = await showMenu<_TabContextMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(
          details.globalPosition.dx,
          details.globalPosition.dy,
          0,
          0,
        ),
        Offset.zero & overlay.size,
      ),
      elevation: 18,
      shadowColor: Colors.black.withValues(alpha: 0.42),
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 240),
      items: [
        _buildTabContextMenuItem(
          action: _TabContextMenuAction.newRequest,
          label: 'New Request',
          shortcut: 'Ctrl+T',
        ),
        _buildTabContextMenuItem(
          action: _TabContextMenuAction.duplicateTab,
          label: 'Duplicate Tab',
          enabled: canDuplicate,
        ),
        const PopupMenuDivider(height: 1),
        _buildTabContextMenuItem(
          action: _TabContextMenuAction.closeTab,
          label: 'Close Tab',
          shortcut: 'Ctrl+W',
        ),
        _buildTabContextMenuItem(
          action: _TabContextMenuAction.forceCloseTab,
          label: 'Force Close Tab',
          shortcut: 'Alt+Ctrl+W',
        ),
        _buildTabContextMenuItem(
          action: _TabContextMenuAction.closeOtherTabs,
          label: 'Close Other Tabs',
          enabled: hasOtherTabs,
        ),
        _buildTabContextMenuItem(
          action: _TabContextMenuAction.closeAllTabs,
          label: 'Close All Tabs',
        ),
        _buildTabContextMenuItem(
          action: _TabContextMenuAction.forceCloseAllTabs,
          label: 'Force Close All Tabs',
        ),
      ],
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _TabContextMenuAction.newRequest:
        _addNewTab();
        break;
      case _TabContextMenuAction.duplicateTab:
        _duplicateTab(tabIndex);
        break;
      case _TabContextMenuAction.closeTab:
        await _closeTab(tabIndex);
        break;
      case _TabContextMenuAction.forceCloseTab:
        await _forceCloseTab(tabIndex);
        break;
      case _TabContextMenuAction.closeOtherTabs:
        await _closeOtherTabs(tabIndex, force: false);
        break;
      case _TabContextMenuAction.closeAllTabs:
        await _closeAllTabs(force: false);
        break;
      case _TabContextMenuAction.forceCloseAllTabs:
        await _closeAllTabs(force: true);
        break;
    }
  }

  PopupMenuItem<_TabContextMenuAction> _buildTabContextMenuItem({
    required _TabContextMenuAction action,
    required String label,
    String? shortcut,
    bool enabled = true,
  }) {
    final shortcutColor = Theme.of(context)
        .textTheme
        .bodySmall
        ?.color
        ?.withValues(alpha: enabled ? 0.7 : 0.4);

    return PopupMenuItem<_TabContextMenuAction>(
      value: action,
      enabled: enabled,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (shortcut != null)
            Text(
              shortcut,
              style: TextStyle(fontSize: 12, color: shortcutColor),
            ),
        ],
      ),
    );
  }

  void _openTabPicker(BuildContext buttonContext) {
    final t = ref.read(translationsProvider);
    final currentRequest = ref.read(requestProvider);
    final controller = TextEditingController();

    const double panelWidth = 420;
    const double panelHeight = 520;

    DropdownOverlayController.showAnchored(
      context: context,
      anchorContext: buttonContext,
      panelSize: const Size(panelWidth, panelHeight),
      placement: DropdownOverlayPlacement.bottomRight,
      groupId: _tabPickerOverlayGroup,
      debugLabel: 'home-tab-picker-dropdown',
      barrierColor: Colors.transparent,
      contentBuilder: (dialogContext, hide) => Material(
        color: Colors.transparent,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            final query = controller.text.trim().toLowerCase();
            final items = <Map<String, dynamic>>[];

            if (!_isOverviewClosed) {
              items.add({
                'index': -1,
                'title': t['overview'] ?? 'Overview',
                'method': null,
                'isActive': _activeTabIndex == -1,
              });
            }

            for (int i = 0; i < _requestTabs.length; i++) {
              final req = _resolveTabRequest(i, currentRequest: currentRequest);
              final isDirty = !req.url.startsWith('postlens://') &&
                  ref.read(requestDirtyProvider(req.id));

              items.add({
                'index': i,
                'title': _getTabTitle(req, t),
                'method': _getTabMethod(req),
                'isActive': _activeTabIndex == i,
                'isDirty': isDirty,
              });
            }

            final visibleItems = query.isEmpty
                ? items
                : items
                    .where((e) =>
                        (e['title'] as String).toLowerCase().contains(query))
                    .toList();

            return Container(
              width: panelWidth,
              height: panelHeight,
              decoration: BoxDecoration(
                color: Theme.of(context).dialogTheme.backgroundColor ??
                    Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF313236)
                        : const Color(0xFFE9EDF1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: controller,
                        onChanged: (_) => setDialogState(() {}),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search tabs',
                          filled: true,
                          fillColor: Colors.transparent,
                          border: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor),
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: visibleItems.length,
                      itemBuilder: (context, idx) {
                        final item = visibleItems[idx];
                        final isActive = item['isActive'] as bool;
                        final isDirty = item['isDirty'] as bool? ?? false;
                        final method = item['method'] as String?;
                        final title = item['title'] as String;
                        bool isHovered = false;
                        return StatefulBuilder(
                          builder: (context, setState) {
                            return MouseRegion(
                              onEnter: (_) => setState(() => isHovered = true),
                              onExit: (_) => setState(() => isHovered = false),
                              child: InkWell(
                                onTap: () {
                                  hide();
                                  _switchTab(item['index'] as int);
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isActive || isHovered
                                        ? Colors.grey.withValues(alpha: 0.12)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      if (method != null) ...[
                                        Text(
                                          method,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _getMethodColor(method),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: Text(
                                          title,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      if (isDirty) const SizedBox(width: 8),
                                      if (isDirty)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFFB400),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF0CBD7D);
      case 'POST':
        return const Color(0xFFFFB400);
      case 'PUT':
        return const Color(0xFF097BED);
      case 'DELETE':
        return const Color(0xFFF05050);
      case 'WS':
      case 'WEBSOCKET':
        return const Color(0xFF9C27B0);
      case 'SOCKET.IO':
      case 'SOCKET':
        return const Color(0xFFE91E63);
      case 'MQTT':
        return const Color(0xFFFF9800);
      case 'GRPC':
        return const Color(0xFF2196F3);
      case 'TCP':
        return const Color(0xFF009688);
      case 'UDP':
        return const Color(0xFF3F51B5);
      default:
        return Colors.grey;
    }
  }
}



enum _DirtyTabCloseAction {
  cancel,
  discard,
  saveAndClose,
}

enum _TabContextMenuAction {
  newRequest,
  duplicateTab,
  closeTab,
  forceCloseTab,
  closeOtherTabs,
  closeAllTabs,
  forceCloseAllTabs,
}
