import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../core/intents.dart';
import '../providers/request_provider.dart';
import '../../domain/models/http_request_model.dart';
import '../../domain/models/http_response_model.dart';
import '../../domain/models/environment_model.dart';
import '../providers/console_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/environment_provider.dart';
import '../providers/global_variables_provider.dart';
import '../../core/utils/toast_utils.dart';
import '../../utils/format_utils.dart';
import '../utils/request_save_helper.dart';
import '../../domain/services/js_engine_service.dart';
import '../../domain/services/collection_variables_service.dart';
import '../../domain/models/collection_model.dart';
import '../providers/collection_provider.dart';
import 'app_code_editor.dart';
import 'doc_editor.dart';
import 'hover_overlay.dart';
import 'script_snippets_overlay.dart';
import 'table_cell_text_field.dart';
import 'package:post_lens/presentation/widgets/common/custom_controls.dart';

class RequestPane extends ConsumerStatefulWidget {
  const RequestPane({super.key});

  @override
  ConsumerState<RequestPane> createState() => _RequestPaneState();
}

class _DraftParamRow {
  final String id;
  final TextEditingController keyController;
  final TextEditingController valueController;
  final FocusNode keyFocusNode;
  final FocusNode valueFocusNode;

  _DraftParamRow({required this.id})
      : keyController = TextEditingController(),
        valueController = TextEditingController(),
        keyFocusNode = FocusNode(),
        valueFocusNode = FocusNode();

  bool get isEmpty =>
      keyController.text.trim().isEmpty && valueController.text.trim().isEmpty;

  void dispose() {
    keyController.dispose();
    valueController.dispose();
    keyFocusNode.dispose();
    valueFocusNode.dispose();
  }
}

class _CaseLocation {
  final CollectionRequest parent;
  final CollectionRequestCase caseNode;

  _CaseLocation({required this.parent, required this.caseNode});
}

// removed _CodeEditorTextField

class _RequestPaneState extends ConsumerState<RequestPane>
    with SingleTickerProviderStateMixin {
  static const double _compactTableRowHeight = 28;
  static const double _compactTableOuterHorizontalPadding = 6;
  static const double _compactTableCellHorizontalPadding = 4;
  static const double _compactTableColumnGap = 6;
  static const double _compactTableSideSlotWidth = 28;
  static const double _compactTableLeadingSlotWidth = 22;
  static const double _compactSectionTopSpacing = 12;
  static const double _compactSectionLabelGap = 6;

  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final TextEditingController _nameController = TextEditingController();
  final List<_DraftParamRow> _draftParamRows = [];
  int _draftParamRowCounter = 0;
  bool _showDefaultHeaders = false;
  bool _showBodySchema = false;
  bool _showBodyPreview = false;
  bool _isProtocolHovered = false;
  String _selectedScriptSubTab = 'Pre-req';
  final GlobalKey<AppCodeEditorState> _scriptEditorKey =
      GlobalKey<AppCodeEditorState>();

  @override
  void initState() {
    super.initState();
    final requestId = ref.read(requestProvider).id;
    final uiState = ref.read(requestPageUiProvider(requestId));
    _tabController = TabController(
      length: 7,
      vsync: this,
      initialIndex: uiState.requestTabIndex >= 7 ? 6 : uiState.requestTabIndex,
    );
    _tabController.addListener(_handleTabChanged);
    _urlFocusNode.addListener(() => setState(() {}));
    _showDefaultHeaders = uiState.showDefaultHeaders;
    _showBodySchema = uiState.showBodySchema;
    _showBodyPreview = uiState.showBodyPreview;
    _ensureTrailingDraftParamRow();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _urlController.dispose();
    _urlFocusNode.dispose();
    _nameController.dispose();
    for (final row in _draftParamRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    final requestId = ref.read(requestProvider).id;
    ref
        .read(requestPageUiProvider(requestId).notifier)
        .updateRequestTabIndex(_tabController.index);
  }

  String _makeDraftParamRowId() {
    final id = _draftParamRowCounter;
    _draftParamRowCounter++;
    return 'draft_$id';
  }

  void _ensureTrailingDraftParamRow() {
    if (_draftParamRows.isEmpty) {
      _addDraftParamRow();
      return;
    }

    while (_draftParamRows.length > 1 &&
        _draftParamRows.last.isEmpty &&
        _draftParamRows[_draftParamRows.length - 2].isEmpty) {
      final last = _draftParamRows.removeLast();
      last.dispose();
    }

    if (!_draftParamRows.last.isEmpty) {
      _addDraftParamRow();
    }
  }

  void _addDraftParamRow() {
    final row = _DraftParamRow(id: _makeDraftParamRowId());
    row.keyFocusNode.addListener(() => _handleDraftParamFocusChange(row.id));
    row.valueFocusNode.addListener(() => _handleDraftParamFocusChange(row.id));
    _draftParamRows.add(row);
  }

  void _handleDraftParamFocusChange(String id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final index = _draftParamRows.indexWhere((r) => r.id == id);
      if (index == -1) return;

      final row = _draftParamRows[index];
      if (row.keyFocusNode.hasFocus || row.valueFocusNode.hasFocus) {
        setState(() {});
        return;
      }

      if (row.isEmpty) {
        if (index != _draftParamRows.length - 1) {
          setState(() {
            final removed = _draftParamRows.removeAt(index);
            removed.dispose();
            _ensureTrailingDraftParamRow();
          });
        } else {
          setState(_ensureTrailingDraftParamRow);
        }
        return;
      }

      setState(() {
        ref.read(requestProvider.notifier).addParam(
              row.keyController.text.trim(),
              row.valueController.text,
            );
        final removed = _draftParamRows.removeAt(index);
        removed.dispose();
        _ensureTrailingDraftParamRow();
      });
    });
  }

  void _onDraftParamChanged(String id) {
    final index = _draftParamRows.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final row = _draftParamRows[index];
    if (index == _draftParamRows.length - 1 && !row.isEmpty) {
      setState(_ensureTrailingDraftParamRow);
    }
  }

  void _commitDraftParamRow(String id, {bool focusNext = false}) {
    final index = _draftParamRows.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final row = _draftParamRows[index];
    if (row.isEmpty) return;

    setState(() {
      ref.read(requestProvider.notifier).addParam(
            row.keyController.text.trim(),
            row.valueController.text,
          );
      final removed = _draftParamRows.removeAt(index);
      removed.dispose();
      _ensureTrailingDraftParamRow();
    });

    if (!mounted || !focusNext) return;
    final nextIndex =
        index < _draftParamRows.length ? index : _draftParamRows.length - 1;
    if (nextIndex < 0 || nextIndex >= _draftParamRows.length) return;
    FocusScope.of(context)
        .requestFocus(_draftParamRows[nextIndex].keyFocusNode);
  }

  Future<void> _showSaveDialog(
      BuildContext context, HttpRequestModel request) async {
    await saveRequest(context, ref, request);
  }

  CollectionRequest? _findRequestNode(
      CollectionModel collection, String requestId) {
    CollectionRequest? found;

    void visit(List<CollectionNode> nodes) {
      for (final node in nodes) {
        if (found != null) return;
        if (node is CollectionFolder) {
          visit(node.children);
          continue;
        }
        if (node is CollectionRequest && node.id == requestId) {
          found = node;
          return;
        }
      }
    }

    visit(collection.children);
    return found;
  }

  _CaseLocation? _findCaseLocation(
      CollectionModel collection, String caseId) {
    _CaseLocation? found;

    void visit(List<CollectionNode> nodes) {
      for (final node in nodes) {
        if (found != null) return;
        if (node is CollectionFolder) {
          visit(node.children);
          continue;
        }
        if (node is CollectionRequest) {
          for (final c in node.cases) {
            if (c.id == caseId) {
              found = _CaseLocation(parent: node, caseNode: c);
              return;
            }
          }
        }
      }
    }

    visit(collection.children);
    return found;
  }

  CollectionModel _addCaseToRequest(
    CollectionModel collection, {
    required String parentRequestId,
    required CollectionRequestCase newCase,
  }) {
    List<CollectionNode> visit(List<CollectionNode> nodes) {
      return nodes.map((node) {
        if (node is CollectionFolder) {
          return node.copyWith(children: visit(node.children));
        }
        if (node is CollectionRequest && node.id == parentRequestId) {
          return node.copyWith(cases: [...node.cases, newCase]);
        }
        return node;
      }).toList();
    }

    return collection.copyWith(children: visit(collection.children));
  }

  CollectionModel _updateCaseInRequest(
    CollectionModel collection, {
    required String parentRequestId,
    required CollectionRequestCase updatedCase,
  }) {
    List<CollectionNode> visit(List<CollectionNode> nodes) {
      return nodes.map((node) {
        if (node is CollectionFolder) {
          return node.copyWith(children: visit(node.children));
        }
        if (node is CollectionRequest && node.id == parentRequestId) {
          return node.copyWith(
              cases: node.cases
                  .map((c) => c.id == updatedCase.id ? updatedCase : c)
                  .toList());
        }
        return node;
      }).toList();
    }

    return collection.copyWith(children: visit(collection.children));
  }

  Future<String?> _showSaveCaseNameDialog(BuildContext context) async {
    final t = ref.read(translationsProvider);
    final controller = TextEditingController();
    final result = await AppOverlayDialogs.showModalLike<String>(
      context: context,
      barrierLabel: t['save_case'] ?? 'Save Case',
      builder: (context) => Dialog(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                      bottom:
                          BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t['save_case'] ?? 'Save Case',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const FaIcon(FontAwesomeIcons.xmark,
                          size: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['name'] ?? 'Name',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          borderSide:
                              BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          borderSide:
                              BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.secondary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        isDense: true,
                      ),
                      onSubmitted: (val) {
                        final name = val.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(context, name);
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(8)),
                  border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        minimumSize: Size.zero,
                      ),
                      child: Text(t['cancel'] ?? 'Cancel',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final name = controller.text.trim();
                        if (name.isEmpty) return;
                        Navigator.pop(context, name);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.0)),
                      ),
                      child: Text(t['save'] ?? 'Save',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return result?.trim().isEmpty ?? true ? null : result?.trim();
  }

  Future<void> _saveOrUpdateCase(
      BuildContext context, HttpRequestModel request) async {
    HttpRequestModel currentRequest = request;
    if (currentRequest.collectionId == null) {
      final saved = await saveRequest(context, ref, currentRequest,
          showSuccessMessage: false);
      if (saved == null) return;
      currentRequest = saved;
    }

    final collectionId = currentRequest.collectionId;
    if (collectionId == null) return;

    final t = ref.read(translationsProvider);
    final collections = ref.read(collectionsProvider);
    final collection =
        collections.where((c) => c.id == collectionId).firstOrNull;
    if (collection == null) {
      if (context.mounted) {
        ToastUtils.showInfo(
            context, t['collection_not_found'] ?? 'Collection not found');
      }
      return;
    }

    final caseLocation = _findCaseLocation(collection, currentRequest.id);
    if (caseLocation != null) {
      final updatedRequest = currentRequest.copyWith(
        id: caseLocation.caseNode.id,
        name: caseLocation.caseNode.name,
      );
      final updatedCase = caseLocation.caseNode.copyWith(
        request: updatedRequest,
      );
      final updatedCollection = _updateCaseInRequest(
        collection,
        parentRequestId: caseLocation.parent.id,
        updatedCase: updatedCase,
      );
      await ref
          .read(collectionsProvider.notifier)
          .updateCollection(updatedCollection);
      ref.read(requestProvider.notifier).markSaved(updatedRequest);
      if (context.mounted) {
        ToastUtils.showInfo(context,
            t['case_updated_successfully'] ?? 'Case updated successfully');
      }
      return;
    }

    final parentRequest = _findRequestNode(collection, currentRequest.id);
    if (parentRequest == null) {
      if (context.mounted) {
        ToastUtils.showInfo(
            context,
            t['request_not_found_in_collection'] ??
                'Request not found in collection');
      }
      return;
    }

    final caseName = await _showSaveCaseNameDialog(context);
    if (caseName == null || !context.mounted) return;

    final caseId = DateTime.now().millisecondsSinceEpoch.toString();
    final caseRequest = currentRequest.copyWith(
      id: caseId,
      name: caseName,
      collectionId: collection.id,
      folderId: currentRequest.folderId,
    );
    final newCase = CollectionRequestCase(
      id: caseId,
      name: caseName,
      request: caseRequest,
    );
    final updatedCollection = _addCaseToRequest(
      collection,
      parentRequestId: parentRequest.id,
      newCase: newCase,
    );

    await ref
        .read(collectionsProvider.notifier)
        .updateCollection(updatedCollection);
    if (context.mounted) {
      ToastUtils.showInfo(
          context, t['case_saved_successfully'] ?? 'Case saved successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final request = ref.watch(requestProvider);
    ref.watch(requestPageUiProvider(request.id));
    final isSending = ref.watch(isSendingProvider(request.id));

    // Always update controllers when request changes (e.g., tab switch)
    if (_urlController.text != request.url) {
      final oldSelection = _urlController.selection;
      _urlController.text = request.url;
      if (oldSelection.isValid &&
          oldSelection.baseOffset <= request.url.length) {
        _urlController.selection = oldSelection;
      } else {
        _urlController.selection =
            TextSelection.collapsed(offset: request.url.length);
      }
    }

    if (_nameController.text != request.name) {
      _nameController.text = request.name;
    }

    return Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.keyS, control: true):
              SaveRequestIntent(),
          SingleActivator(LogicalKeyboardKey.keyS, meta: true):
              SaveRequestIntent(),
          SingleActivator(LogicalKeyboardKey.enter, control: true):
              SendRequestIntent(),
          SingleActivator(LogicalKeyboardKey.enter, meta: true):
              SendRequestIntent(),
          SingleActivator(LogicalKeyboardKey.keyL, control: true):
              FocusRequestUrlIntent(),
          SingleActivator(LogicalKeyboardKey.keyL, meta: true):
              FocusRequestUrlIntent(),
        },
        child: Actions(
            actions: <Type, Action<Intent>>{
              SaveRequestIntent: CallbackAction<SaveRequestIntent>(
                  onInvoke: (intent) => _showSaveDialog(context, request)),
              SendRequestIntent: CallbackAction<SendRequestIntent>(
                  onInvoke: (intent) => isSending ? null : _sendRequest()),
              FocusRequestUrlIntent: CallbackAction<FocusRequestUrlIntent>(
                  onInvoke: (intent) => _urlFocusNode.requestFocus()),
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(8.0),
              ),
              padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // URL Info and Save Row
                  Row(
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
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4.0),
                                        side: BorderSide(
                                          color:
                                              Theme.of(context).dividerColor,
                                          width: 1.0,
                                        ),
                                      ),
                                      constraints: const BoxConstraints(),
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
                                          child: Row(
                                            children: [
                                              FaIcon(_getProtocolIcon(value),
                                                  size: 14,
                                                  color:
                                                      _getProtocolColor(value)),
                                              const SizedBox(width: 8),
                                              Text(value.toUpperCase(),
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      child: MouseRegion(
                                        onEnter: (_) => setState(
                                            () => _isProtocolHovered = true),
                                        onExit: (_) => setState(
                                            () => _isProtocolHovered = false),
                                        cursor: SystemMouseCursors.click,
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                              right: 8.0),
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
                                            color: _getProtocolColor(
                                                request.protocol),
                                          ),
                                        ),
                                      ),
                                    ),
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxWidth: maxNameWidth),
                                      child: TextField(
                                        controller: _nameController,
                                        maxLines: 1,
                                        onChanged: (val) => ref
                                            .read(requestProvider.notifier)
                                            .updateName(val),
                                        style: const TextStyle(fontSize: 12),
                                        decoration: InputDecoration(
                                          hintText: t['untitled_request'] ??
                                              'Untitled Request',
                                          filled: true,
                                          fillColor: Theme.of(context)
                                              .colorScheme
                                              .surface,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                            borderSide: BorderSide(
                                                color: Colors.grey
                                                    .withOpacity(0.5),
                                                width: 1.0),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                            borderSide: BorderSide(
                                                color: Colors.grey
                                                    .withOpacity(0.5),
                                                width: 1.0),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(4.0),
                                            borderSide: BorderSide(
                                                color: Colors.grey
                                                    .withOpacity(0.5),
                                                width: 1.0),
                                          ),
                                          isDense: true,
                                          contentPadding:
                                              const EdgeInsets.fromLTRB(
                                                  8, 7, 8, 7),
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
                        child: Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showSaveDialog(context, request),
                              icon: const FaIcon(FontAwesomeIcons.floppyDisk,
                                  size: 14),
                              label: Text(t['save'] ?? 'Save',
                                  style: const TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .color,
                                side: BorderSide(
                                    color: Theme.of(context).dividerColor),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _saveOrUpdateCase(context, request),
                              icon: const FaIcon(FontAwesomeIcons.bookmark,
                                  size: 14),
                              label: Text(t['save_case'] ?? 'Save Case',
                                  style: const TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .color,
                                side: BorderSide(
                                    color: Theme.of(context).dividerColor),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // URL Bar
                  Row(
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
                              _buildMethodDropdown(
                                  request.method, request.protocol),
                              const VerticalDivider(width: 1, thickness: 1),
                              Expanded(
                                child: TableCellTextField(
                                  text: request.url,
                                  controller: _urlController,
                                  focusNode: _urlFocusNode,
                                  onChanged: (val) => ref
                                      .read(requestProvider.notifier)
                                      .updateUrl(val),
                                  hint: 'Enter request URL',
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
                          onPressed: isSending ? null : _sendRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0)),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            elevation: 0,
                          ),
                          child: isSending
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .color!,
                                      strokeWidth: 2))
                              : Text(t['send'] ?? 'Send',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.normal,
                                      fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Request Config Tabs
                  SizedBox(
                    height: 32,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: Theme.of(context).colorScheme.secondary,
                      labelColor:
                          Theme.of(context).textTheme.bodyMedium!.color!,
                      unselectedLabelColor: Colors.grey,
                      tabAlignment: TabAlignment.start,
                      labelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
                      dividerColor: Theme.of(context).dividerColor,
                      tabs: [
                        Tab(
                            text: (t['params'] ?? 'Params') +
                                (request.params.isNotEmpty
                                    ? " (${request.params.length})"
                                    : "")),
                        Tab(text: t['authorization'] ?? 'Authorization'),
                        Tab(
                            text: (t['headers'] ?? 'Headers') +
                                (request.headers.isNotEmpty
                                    ? " (${request.headers.length})"
                                    : "")),
                        Tab(text: t['body'] ?? 'Body'),
                        Tab(text: t['scripts'] ?? 'Scripts'),
                        Tab(text: t['settings'] ?? 'Settings'),
                        Tab(text: t['doc'] ?? 'Doc'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        SingleChildScrollView(
                            child: _buildParamsTable(request.params)),
                        SingleChildScrollView(
                            child: _buildAuthorizationTab(request)),
                        SingleChildScrollView(
                            child: _buildHeadersTable(request.headers)),
                        _buildBodyTab(request),
                        _buildScriptTab(request),
                        SingleChildScrollView(
                            child: _buildSettingsTab(request)),
                        SingleChildScrollView(child: _buildDocTab(request)),
                      ],
                    ),
                  )
                ],
              ),
            )));
  }

  Widget _buildMethodDropdown(String method, String protocol) {
    if (protocol != 'http') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        child: Text(
          protocol.toUpperCase(),
          style: TextStyle(
            color: _getMethodColor(protocol.toUpperCase()),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    Color methodColor = _getMethodColor(method);
    const double dropdownWidth = 90.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: PopupMenuButton<String>(
        tooltip: 'Method',
        position: PopupMenuPosition.under,
        offset: const Offset(-12, 0),
        padding: EdgeInsets.zero,
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        splashRadius: 16,
        onSelected: (String value) {
          ref.read(requestProvider.notifier).updateMethod(value);
        },
        itemBuilder: (context) => <String>[
          'GET',
          'POST',
          'PUT',
          'DELETE',
          'PATCH',
          'HEAD',
          'OPTIONS'
        ].map((String value) {
          return PopupMenuItem<String>(
            value: value,
            height: 28,
            child: SizedBox(
              width: dropdownWidth - 24,
              child: Text(value,
                  style: TextStyle(
                      color: _getMethodColor(value),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          );
        }).toList(),
        child: SizedBox(
          width: dropdownWidth,
          height: _compactTableRowHeight,
          child: Row(
            children: [
              Text(
                method,
                style: TextStyle(
                    color: methodColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
              const Spacer(),
              const FaIcon(FontAwesomeIcons.chevronDown,
                  size: 10, color: Colors.grey),
            ],
          ),
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
      case 'PATCH':
        return const Color(0xFF7B1FA2);
      case 'HEAD':
        return const Color(0xFF00897B);
      case 'OPTIONS':
        return const Color(0xFFE65100);
      case 'WS':
      case 'WEBSOCKET':
        return const Color(0xFF9C27B0);
      case 'SOCKET.IO':
      case 'SOCKET':
        return const Color(0xFFE91E63);
      case 'MQTT':
        return const Color(0xFFFF9800);
      case 'TCP':
        return const Color(0xFF009688);
      case 'UDP':
        return const Color(0xFF3F51B5);
      case 'GRPC':
        return const Color(0xFF2196F3);
      default:
        return Colors.grey;
    }
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

  Widget _buildParamsTable(List<Map<String, String>> params) {
    final t = ref.watch(translationsProvider);
    return Padding(
      padding: const EdgeInsets.only(top: _compactSectionTopSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['query_parameters'] ?? 'Query Parameters',
              style: TextStyle(
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
                  _buildTableRow('Key', 'Value', 'Description',
                      isHeader: true,
                      widgetKey: const ValueKey('param_row_header'),
                      rowId: 'header'),
                  ...params.asMap().entries.map((entry) {
                    final id = entry.value['id'] ?? 'idx_${entry.key}';
                    final isLast = _draftParamRows.isEmpty &&
                        entry.key == params.length - 1;
                    return _buildTableRow(
                      entry.value['key'] ?? '',
                      entry.value['value'] ?? '',
                      '',
                      isHeader: false,
                      index: entry.key,
                      enabled: (entry.value['enabled'] ?? 'true') == 'true',
                      widgetKey: ValueKey('param_row_$id'),
                      rowId: id,
                      isLast: isLast,
                    );
                  }),
                  ..._draftParamRows.asMap().entries.map((entry) {
                    final row = entry.value;
                    return _buildTableRow(
                      '',
                      '',
                      '',
                      isHeader: false,
                      isNew: true,
                      widgetKey: ValueKey('param_row_draft_${row.id}'),
                      rowId: row.id,
                      draftRow: row,
                      isLast: entry.key == _draftParamRows.length - 1,
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(String key, String value, String desc,
      {required bool isHeader,
      int? index,
      bool isNew = false,
      bool enabled = true,
      Key? widgetKey,
      String? rowId,
      _DraftParamRow? draftRow,
      bool isLast = false}) {
    final showDraftCheckbox = isNew &&
        draftRow != null &&
        (!draftRow.isEmpty ||
            draftRow.keyFocusNode.hasFocus ||
            draftRow.valueFocusNode.hasFocus);

    return Container(
      key: widgetKey,
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
          if (!isHeader && !isNew) ...[
            InkWell(
              onTap: () {
                if (index != null) {
                  ref
                      .read(requestProvider.notifier)
                      .updateParamEnabled(index, !enabled);
                }
              },
              child: SizedBox(
                width: 16,
                child: Center(
                  child: FaIcon(
                    enabled
                        ? FontAwesomeIcons.squareCheck
                        : FontAwesomeIcons.square,
                    size: 16,
                    color: enabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: _compactTableColumnGap),
          ] else if (!isHeader && isNew) ...[
            SizedBox(
              width: 16,
              child: Center(
                child: showDraftCheckbox
                    ? FaIcon(
                        FontAwesomeIcons.squareCheck,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: _compactTableColumnGap),
          ] else
            const SizedBox(width: _compactTableLeadingSlotWidth),
          Expanded(
              flex: 2,
              child: isNew
                  ? _buildTableCell(
                      draftRow?.keyController.text ?? '',
                      isHeader: isHeader,
                      hint: 'Key',
                      controller: draftRow?.keyController,
                      focusNode: draftRow?.keyFocusNode,
                      fieldKey:
                          ValueKey('param_cell_draft_${draftRow?.id}_key'),
                      onChanged: (_) {
                        if (draftRow != null) {
                          _onDraftParamChanged(draftRow.id);
                        }
                      },
                      onSubmitted: (_) {
                        if (draftRow != null) {
                          FocusScope.of(context)
                              .requestFocus(draftRow.valueFocusNode);
                        }
                      },
                    )
                  : _buildTableCell(
                      key,
                      isHeader: isHeader,
                      hint: 'Key',
                      fieldKey: ValueKey('param_cell_${rowId ?? index}_key'),
                      onChanged: (v) {
                        if (index != null) {
                          ref
                              .read(requestProvider.notifier)
                              .updateParam(index, v, value);
                        }
                      },
                    )),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 2,
              child: isNew
                  ? _buildTableCell(
                      draftRow?.valueController.text ?? '',
                      isHeader: isHeader,
                      hint: 'Value',
                      controller: draftRow?.valueController,
                      focusNode: draftRow?.valueFocusNode,
                      fieldKey:
                          ValueKey('param_cell_draft_${draftRow?.id}_value'),
                      onChanged: (_) {
                        if (draftRow != null) {
                          _onDraftParamChanged(draftRow.id);
                        }
                      },
                      onSubmitted: (_) {
                        if (draftRow != null) {
                          _commitDraftParamRow(draftRow.id, focusNext: true);
                        }
                      },
                      onEditingComplete: () {
                        if (draftRow != null) {
                          _commitDraftParamRow(draftRow.id, focusNext: true);
                        }
                      },
                    )
                  : _buildTableCell(
                      value,
                      isHeader: isHeader,
                      hint: 'Value',
                      fieldKey: ValueKey('param_cell_${rowId ?? index}_value'),
                      onChanged: (v) {
                        if (index != null) {
                          ref
                              .read(requestProvider.notifier)
                              .updateParam(index, key, v);
                        }
                      },
                    )),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 3,
              child: _buildTableCell(desc,
                  isHeader: isHeader, hint: 'Description', onChanged: (v) {})),
          if (!isHeader && !isNew)
            Center(
              child: SizedBox(
                width: _compactTableSideSlotWidth,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const FaIcon(FontAwesomeIcons.xmark,
                      size: 16, color: Colors.grey),
                  onPressed: () {
                    if (index != null) {
                      ref.read(requestProvider.notifier).removeParam(index);
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
      bool readOnly = false,
      Key? fieldKey,
      TextEditingController? controller,
      FocusNode? focusNode,
      ValueChanged<String>? onSubmitted,
      VoidCallback? onEditingComplete,
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
        key: fieldKey,
        text: text,
        hint: hint,
        readOnly: readOnly,
        controller: controller,
        focusNode: focusNode,
        onSubmitted: onSubmitted,
        onEditingComplete: onEditingComplete,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildHeadersTable(List<Map<String, String>> headers) {
    final t = ref.watch(translationsProvider);
    final requestId = ref.read(requestProvider).id;
    final defaultHeaders = [
      {'key': 'Cache-Control', 'value': 'no-cache'},
      {'key': 'PostLens-Token', 'value': '<calculated when request is sent>'},
      {'key': 'Host', 'value': '<calculated when request is sent>'},
      {'key': 'User-Agent', 'value': 'PostLensRuntime/7.53.0'},
      {'key': 'Accept', 'value': '*/*'},
      {'key': 'Accept-Encoding', 'value': 'gzip, deflate, br'},
      {'key': 'Connection', 'value': 'keep-alive'},
    ];

    final defaultHeaderValueByKey = <String, String>{
      for (final header in defaultHeaders)
        (header['key'] ?? '').trim().toLowerCase(): header['value'] ?? '',
    };

    final presetHeaderRowIndexes = <int>{};
    final overriddenDefaultHeaderKeys = <String>{};

    for (final entry in headers.asMap().entries) {
      final keyLower = (entry.value['key'] ?? '').trim().toLowerCase();
      if (keyLower.isEmpty) continue;
      final defaultValue = defaultHeaderValueByKey[keyLower];
      if (defaultValue == null) continue;

      final value = entry.value['value'] ?? '';
      if (value == defaultValue) {
        presetHeaderRowIndexes.add(entry.key);
      } else {
        overriddenDefaultHeaderKeys.add(keyLower);
      }
    }

    final visibleDefaultHeaders = defaultHeaders
        .where((h) => !overriddenDefaultHeaderKeys
            .contains((h['key'] ?? '').toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: _compactSectionTopSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t['headers'] ?? 'Headers',
                  style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.normal)),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showDefaultHeaders = !_showDefaultHeaders;
                  });
                  ref
                      .read(requestPageUiProvider(requestId).notifier)
                      .updateShowDefaultHeaders(_showDefaultHeaders);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                ),
                child: Text(
                  _showDefaultHeaders
                      ? 'Hide auto-generated headers (${visibleDefaultHeaders.length})'
                      : 'Show auto-generated headers (${visibleDefaultHeaders.length})',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
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
                  _buildHeaderTableRow('Key', 'Value', 'Description',
                      isHeader: true),
                  if (_showDefaultHeaders)
                    ...visibleDefaultHeaders.asMap().entries.map((entry) {
                      return _buildHeaderTableRow(
                        entry.value['key'] ?? '',
                        entry.value['value'] ?? '',
                        'Auto-generated',
                        isHeader: false,
                        enabled: true,
                        readOnly: true,
                      );
                    }),
                  ...headers
                      .asMap()
                      .entries
                      .where((e) => !presetHeaderRowIndexes.contains(e.key))
                      .map((entry) {
                    return _buildHeaderTableRow(
                      entry.value['key'] ?? '',
                      entry.value['value'] ?? '',
                      '',
                      isHeader: false,
                      index: entry.key,
                      enabled: (entry.value['enabled'] ?? 'true') == 'true',
                    );
                  }),
                  _buildHeaderTableRow('', '', '',
                      isHeader: false, isNew: true, isLast: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderTableRow(String key, String value, String desc,
      {required bool isHeader,
      int? index,
      bool isNew = false,
      bool enabled = true,
      bool readOnly = false,
      bool isLast = false}) {
    return Container(
      height: _compactTableRowHeight,
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        color: isHeader || readOnly
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
          if (!isHeader && !isNew) ...[
            readOnly
                ? const SizedBox(
                    width: 16,
                    child: Center(
                      child: FaIcon(FontAwesomeIcons.circleInfo,
                          size: 14, color: Colors.grey),
                    ),
                  )
                : InkWell(
                    onTap: () {
                      if (index != null) {
                        ref
                            .read(requestProvider.notifier)
                            .updateHeaderEnabled(index, !enabled);
                      }
                    },
                    child: SizedBox(
                      width: 16,
                      child: Center(
                        child: FaIcon(
                          enabled
                              ? FontAwesomeIcons.squareCheck
                              : FontAwesomeIcons.square,
                          size: 16,
                          color: enabled
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(width: _compactTableColumnGap),
          ] else if (!isHeader && isNew) ...[
            const SizedBox(width: 16),
            const SizedBox(width: _compactTableColumnGap),
          ] else
            const SizedBox(width: _compactTableLeadingSlotWidth),
          Expanded(
              flex: 2,
              child: _buildTableCell(key,
                  isHeader: isHeader,
                  hint: 'Key',
                  readOnly: readOnly, onChanged: (v) {
                if (isNew) {
                  ref.read(requestProvider.notifier).addHeader(v, '');
                } else if (index != null && !readOnly) {
                  ref
                      .read(requestProvider.notifier)
                      .updateHeader(index, v, value);
                }
              })),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 2,
              child: _buildTableCell(value,
                  isHeader: isHeader,
                  hint: 'Value',
                  readOnly: readOnly, onChanged: (v) {
                if (isNew) {
                  ref.read(requestProvider.notifier).addHeader(key, v);
                } else if (index != null && !readOnly) {
                  ref
                      .read(requestProvider.notifier)
                      .updateHeader(index, key, v);
                }
              })),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 3,
              child: _buildTableCell(desc,
                  isHeader: isHeader,
                  hint: 'Description',
                  readOnly: readOnly,
                  onChanged: (v) {})),
          if (!isHeader && !isNew && !readOnly)
            Center(
              child: SizedBox(
                width: _compactTableSideSlotWidth,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const FaIcon(FontAwesomeIcons.xmark,
                      size: 16, color: Colors.grey),
                  onPressed: () {
                    if (index != null) {
                      ref.read(requestProvider.notifier).removeHeader(index);
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

  Widget _buildAuthorizationTab(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 250,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t['auth_type'] ?? 'Auth Type',
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.normal)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: PopupMenuButton<String>(
                    tooltip: 'Auth Type',
                    position: PopupMenuPosition.under,
                    padding: EdgeInsets.zero,
                    color: Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                      side: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1.0,
                      ),
                    ),
                    constraints: const BoxConstraints(minWidth: 234),
                    splashRadius: 16,
                    onSelected: (String value) {
                      ref.read(requestProvider.notifier).updateAuthType(value);
                    },
                    itemBuilder: (context) => <String>[
                      'No Auth',
                      'Basic Auth',
                      'Bearer Token',
                      'JWT Bearer',
                      'Digest Auth',
                      'OAuth 1.0',
                      'OAuth 2.0',
                      'Hawk Authentication',
                      'AWS Signature',
                      'NTLM Authentication',
                      'API Key',
                      'Akamai EdgeGrid',
                      'ASAP (Atlassian)'
                    ].map((String value) {
                      return PopupMenuItem<String>(
                        value: value,
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            if (value == request.authType)
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
                    child: SizedBox(
                      height: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            request.authType,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .color!,
                                fontSize: 12),
                          ),
                          const FaIcon(FontAwesomeIcons.chevronDown,
                              size: 10, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                    t['auth_header_auto_gen'] ??
                        'The authorization header will be automatically generated when you send the request.',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: _buildAuthContent(request),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthContent(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    if (request.authType == 'No Auth') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: FaIcon(FontAwesomeIcons.minus,
                    size: 16, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            Text(t['no_auth'] ?? 'No Auth',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium!.color!,
                    fontSize: 12,
                    fontWeight: FontWeight.normal)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                    t['no_auth_desc'] ??
                        'This request does not use any authorization. ',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              ],
            )
          ],
        ),
      );
    } else if (request.authType == 'Bearer Token') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['token'] ?? 'Token',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: TextField(
              controller: TextEditingController(text: request.bearerToken)
                ..selection =
                    TextSelection.collapsed(offset: request.bearerToken.length),
              onChanged: (val) =>
                  ref.read(requestProvider.notifier).updateBearerToken(val),
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium!.color!,
                  fontFamily: 'Consolas',
                  fontSize: 12),
              decoration: InputDecoration(
                hintText: t['token'] ?? 'Token',
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      );
    } else if (request.authType == 'Basic Auth') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['username'] ?? 'Username',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: TextField(
              controller: TextEditingController(text: request.basicAuthUsername)
                ..selection = TextSelection.collapsed(
                    offset: request.basicAuthUsername.length),
              onChanged: (val) => ref
                  .read(requestProvider.notifier)
                  .updateBasicAuthUsername(val),
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium!.color!,
                  fontFamily: 'Consolas',
                  fontSize: 12),
              decoration: InputDecoration(
                hintText: t['username'] ?? 'Username',
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(t['password'] ?? 'Password',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: TextField(
              controller: TextEditingController(text: request.basicAuthPassword)
                ..selection = TextSelection.collapsed(
                    offset: request.basicAuthPassword.length),
              onChanged: (val) => ref
                  .read(requestProvider.notifier)
                  .updateBasicAuthPassword(val),
              obscureText: true,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium!.color!,
                  fontFamily: 'Consolas',
                  fontSize: 12),
              decoration: InputDecoration(
                hintText: t['password'] ?? 'Password',
                hintStyle: const TextStyle(color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      );
    } else if (request.authType == 'API Key') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['key'] ?? 'Key',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: TextField(
              controller: TextEditingController(text: request.apiKeyKey)
                ..selection =
                    TextSelection.collapsed(offset: request.apiKeyKey.length),
              onChanged: (val) => ref
                  .read(requestProvider.notifier)
                  .updateApiKey(val, request.apiKeyValue, request.apiKeyAddTo),
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium!.color!,
                  fontFamily: 'Consolas',
                  fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Key',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(t['value'] ?? 'Value',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: TextField(
              controller: TextEditingController(text: request.apiKeyValue)
                ..selection =
                    TextSelection.collapsed(offset: request.apiKeyValue.length),
              onChanged: (val) => ref
                  .read(requestProvider.notifier)
                  .updateApiKey(request.apiKeyKey, val, request.apiKeyAddTo),
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium!.color!,
                  fontFamily: 'Consolas',
                  fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Value',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(t['add_to'] ?? 'Add to',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            height: 36,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8.0),
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: PopupMenuButton<String>(
              tooltip: 'Add To',
              position: PopupMenuPosition.under,
              padding: EdgeInsets.zero,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
                side: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1.0,
                ),
              ),
              constraints: const BoxConstraints(
                  minWidth: 234), // Adjust to match the width of the text field
              splashRadius: 16,
              onSelected: (String value) {
                ref.read(requestProvider.notifier).updateApiKey(
                    request.apiKeyKey, request.apiKeyValue, value);
              },
              itemBuilder: (context) =>
                  <String>['Header', 'Query Params'].map((String value) {
                return PopupMenuItem<String>(
                  value: value,
                  height: 32,
                  child: Text(value, style: const TextStyle(fontSize: 12)),
                );
              }).toList(),
              child: SizedBox(
                height: 36,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      request.apiKeyAddTo,
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium!.color!,
                          fontFamily: 'Consolas',
                          fontSize: 12),
                    ),
                    const FaIcon(FontAwesomeIcons.chevronDown,
                        size: 10, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else if (request.authType == 'JWT Bearer') {
      return _buildJwtBearerAuth(request);
    } else if (request.authType == 'Digest Auth') {
      return _buildDigestAuth(request);
    } else if (request.authType == 'OAuth 1.0') {
      return _buildOAuth1Auth(request);
    } else if (request.authType == 'OAuth 2.0') {
      return _buildOAuth2Auth(request);
    } else if (request.authType == 'Hawk Authentication') {
      return _buildHawkAuth(request);
    } else if (request.authType == 'AWS Signature') {
      return _buildAwsAuth(request);
    } else if (request.authType == 'NTLM Authentication') {
      return _buildNtlmAuth(request);
    } else if (request.authType == 'Akamai EdgeGrid') {
      return _buildAkamaiAuth(request);
    } else if (request.authType == 'ASAP (Atlassian)') {
      return _buildAsapAuth(request);
    }
    // Other auth types are not specified in the requirements, returning a placeholder
    return Center(
        child: Text('${request.authType} Config',
            style: const TextStyle(color: Colors.grey, fontSize: 12)));
  }

  Widget _buildBodyTab(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    const bodyTypes = [
      'none',
      'form-data',
      'x-www-form-urlencoded',
      'raw',
      'binary',
      'GraphQL',
    ];

    void setBodyType(String value) {
      if (value == request.bodyType) return;
      ref.read(requestProvider.notifier).updateBodyType(value);
      if (value != 'raw') {
        setState(() {
          _showBodySchema = false;
          _showBodyPreview = false;
        });
        final uiNotifier = ref.read(requestPageUiProvider(request.id).notifier);
        uiNotifier.updateShowBodySchema(false);
        uiNotifier.updateShowBodyPreview(false);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: bodyTypes.map((type) {
                      return InkWell(
                        onTap: () => setBodyType(type),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: Transform.scale(
                                scale: 0.7,
                                child: CustomRadio<String>(
                                  value: type,
                                  groupValue: request.bodyType,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (v) {
                                    if (v != null) setBodyType(v);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (request.bodyType == 'raw') ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Raw Body Type',
                  position: PopupMenuPosition.under,
                  padding: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    side: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1.0,
                    ),
                  ),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onSelected: (String value) {
                    ref.read(requestProvider.notifier).updateRawBodyType(value);
                  },
                  itemBuilder: (context) => <String>[
                    'Text',
                    'JavaScript',
                    'JSON',
                    'HTML',
                    'XML'
                  ].map((String value) {
                    return PopupMenuItem<String>(
                      value: value,
                      height: 32,
                      child: Text(value, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  child: SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          request.rawBodyType,
                          style:
                              const TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const FaIcon(FontAwesomeIcons.chevronDown,
                            size: 10, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showBodySchema = !_showBodySchema;
                    });
                    ref
                        .read(requestPageUiProvider(request.id).notifier)
                        .updateShowBodySchema(_showBodySchema);
                  },
                  icon: const FaIcon(FontAwesomeIcons.sliders,
                      size: 12, color: Colors.grey),
                  label: Text(t['schema'] ?? 'Schema',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final formatted =
                        formatCode(request.body, request.rawBodyType);
                    if (formatted != request.body) {
                      ref.read(requestProvider.notifier).updateBody(formatted);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(t['beautify'] ?? 'Beautify',
                      style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showBodyPreview = !_showBodyPreview;
                    });
                    ref
                        .read(requestPageUiProvider(request.id).notifier)
                        .updateShowBodyPreview(_showBodyPreview);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(_showBodyPreview ? 'Raw' : 'Preview',
                      style: const TextStyle(color: Colors.blue, fontSize: 12)),
                ),
              ],
              if (request.bodyType == 'GraphQL') ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    final formattedQuery = formatJs(request.graphqlQuery);
                    if (formattedQuery != request.graphqlQuery) {
                      ref
                          .read(requestProvider.notifier)
                          .updateGraphqlQuery(formattedQuery);
                    }
                    final formattedVars =
                        formatCode(request.graphqlVariables, 'JSON');
                    if (formattedVars != request.graphqlVariables) {
                      ref
                          .read(requestProvider.notifier)
                          .updateGraphqlVariables(formattedVars);
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(t['beautify'] ?? 'Beautify',
                      style: TextStyle(color: Colors.blue, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Fetch Mode',
                  position: PopupMenuPosition.under,
                  padding: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4.0),
                    side: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1.0,
                    ),
                  ),
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onSelected: (String value) {},
                  itemBuilder: (context) =>
                      <String>['Auto Fetch'].map((String value) {
                    return PopupMenuItem<String>(
                      value: value,
                      height: 32,
                      child: Text(value, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  child: SizedBox(
                    height: 20,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          t['auto_fetch'] ?? 'Auto Fetch',
                          style:
                              const TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                        const SizedBox(width: 4),
                        const FaIcon(FontAwesomeIcons.chevronDown,
                            size: 10, color: Colors.blue),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const FaIcon(FontAwesomeIcons.rotateRight,
                      size: 12, color: Colors.grey),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                ),
                const FaIcon(FontAwesomeIcons.triangleExclamation,
                    size: 12, color: Colors.amber),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildBodyContent(request),
          ),
        ],
      ),
    );
  }

  Widget _buildScriptTab(HttpRequestModel request) {
    return StatefulBuilder(
      builder: (context, setState) {
        final isPreReq = _selectedScriptSubTab == 'Pre-req';
        final currentText = isPreReq ? request.preRequestScript : request.tests;

        return Container(
          margin: const EdgeInsets.only(top: 16.0),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sidebar
              Container(
                width: 100,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                child: Column(
                  children: [
                    _buildScriptSidebarItem('Pre-req', isPreReq, () {
                      setState(() {
                        _selectedScriptSubTab = 'Pre-req';
                      });
                      this.setState(
                          () {}); // trigger rebuild to update outer scope
                    }),
                    const SizedBox(height: 2),
                    _buildScriptSidebarItem('Post-res', !isPreReq, () {
                      setState(() {
                        _selectedScriptSubTab = 'Post-res';
                      });
                      this.setState(
                          () {}); // trigger rebuild to update outer scope
                    }),
                  ],
                ),
              ),
              // Editor Area
              Expanded(
                child: Stack(
                  children: [
                    AppCodeEditor(
                      key: _scriptEditorKey,
                      text: currentText,
                      hint:
                          '// Use JavaScript to write tests, visualize response, and more.',
                      language: 'javascript',
                      onChanged: (val) {
                        if (isPreReq) {
                          ref
                              .read(requestProvider.notifier)
                              .updatePreRequestScript(val);
                        } else {
                          ref.read(requestProvider.notifier).updateTests(val);
                        }
                      },
                    ),
                    // Floating Action Bar
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Builder(
                              builder: (anchorContext) {
                                return IconButton(
                                  icon: const FaIcon(FontAwesomeIcons.code,
                                      size: 14, color: Colors.grey),
                                  onPressed: () {
                                    DropdownOverlayController.showAnchored(
                                      context: context,
                                      anchorContext: anchorContext,
                                      panelSize: const Size(320, 460),
                                      placement:
                                          DropdownOverlayPlacement.topRight,
                                      gap: 8,
                                      groupId: 'script-snippets',
                                      contentBuilder: (_, hide) {
                                        return Material(
                                          color: Colors.transparent,
                                          child: ScriptSnippetsOverlay(
                                            isPreRequest: isPreReq,
                                            onSelect: (code) {
                                              hide();
                                              final prefix =
                                                  currentText.trim().isEmpty
                                                      ? ''
                                                      : '\n\n';
                                              _scriptEditorKey.currentState
                                                  ?.insertText('$prefix$code');
                                            },
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                  tooltip: 'Snippets',
                                );
                              },
                            ),
                            Container(
                                width: 1,
                                color: Theme.of(context).dividerColor),
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.broom,
                                  size: 14, color: Colors.grey),
                              onPressed: () {
                                // Beautify functionality
                                final formatted =
                                    formatCode(currentText, 'JavaScript');
                                if (formatted != currentText) {
                                  if (isPreReq) {
                                    ref
                                        .read(requestProvider.notifier)
                                        .updatePreRequestScript(formatted);
                                  } else {
                                    ref
                                        .read(requestProvider.notifier)
                                        .updateTests(formatted);
                                  }
                                }
                              },
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              constraints: const BoxConstraints(
                                  minWidth: 32, minHeight: 32),
                              tooltip: 'Beautify',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScriptSidebarItem(
      String title, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.grey,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    switch (request.bodyType) {
      case 'none':
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                  t['this_request_does_not_hav'] ??
                      'This request does not have a body',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        );
      case 'form-data':
        return SingleChildScrollView(
            child: _buildFormDataTable(request.formData));
      case 'x-www-form-urlencoded':
        return SingleChildScrollView(
            child: _buildUrlEncodedTable(request.urlEncodedData));
      case 'raw':
        final schemaText = request.rawBodyType == 'JSON'
            ? generateJsonSchemaText(request.body)
            : '';
        final previewText = _showBodyPreview
            ? formatCode(request.body, request.rawBodyType)
            : request.body;
        return Container(
          height: 300,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: _showBodySchema ? 2 : 1,
                child: _showBodyPreview
                    ? AppCodeEditor(
                        text: previewText,
                        wrapLines: true,
                        readOnly: true,
                        language:
                            request.rawBodyType.toLowerCase() == 'javascript'
                                ? 'javascript'
                                : request.rawBodyType.toLowerCase(),
                      )
                    : AppCodeEditor(
                        text: request.body,
                        hint: '',
                        onChanged: (val) =>
                            ref.read(requestProvider.notifier).updateBody(val),
                        language:
                            request.rawBodyType.toLowerCase() == 'javascript'
                                ? 'javascript'
                                : request.rawBodyType.toLowerCase(),
                      ),
              ),
              if (_showBodySchema)
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    child: schemaText.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                request.rawBodyType == 'JSON'
                                    ? 'Invalid JSON'
                                    : 'Schema only supports JSON',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          )
                        : AppCodeEditor(
                            text: schemaText,
                            wrapLines: true,
                            readOnly: true,
                            language: 'json'),
                  ),
                ),
            ],
          ),
        );
      case 'binary':
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      if (request.binaryFilePath.isNotEmpty) ...[
                        Text(
                          'Selected file: ${request.binaryFilePath.split(RegExp(r'[\\\\/]')).last}',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .color!,
                              fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles();
                          if (result != null &&
                              result.files.single.path != null) {
                            ref
                                .read(requestProvider.notifier)
                                .updateBinaryFilePath(
                                    result.files.single.path!);
                          }
                        },
                        icon: const FaIcon(FontAwesomeIcons.fileArrowUp,
                            size: 14, color: Colors.blue),
                        label: Text(
                            request.binaryFilePath.isNotEmpty
                                ? 'Change File'
                                : 'Select File',
                            style: const TextStyle(color: Colors.blue)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                      if (request.binaryFilePath.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(requestProvider.notifier)
                                .updateBinaryFilePath('');
                          },
                          child: Text(t['clear_file'] ?? 'Clear File',
                              style:
                                  TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      case 'GraphQL':
        return SizedBox(
          height: 300,
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['query'] ?? 'QUERY',
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.normal)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: AppCodeEditor(
                          text: request.graphqlQuery,
                          hint: '',
                          onChanged: (val) => ref
                              .read(requestProvider.notifier)
                              .updateGraphqlQuery(val),
                          language: 'graphql',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(t['graphql_variables'] ?? 'GRAPHQL VARIABLES',
                            style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.normal)),
                        const SizedBox(width: 4),
                        const Icon(Icons.info_outline,
                            size: 12, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: AppCodeEditor(
                          text: request.graphqlVariables,
                          hint: '',
                          onChanged: (val) => ref
                              .read(requestProvider.notifier)
                              .updateGraphqlVariables(val),
                          language: 'json',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        return Center(
            child: Text('${request.bodyType} Editor',
                style: const TextStyle(color: Colors.grey, fontSize: 12)));
    }
  }

  Widget _buildFormDataTable(List<Map<String, String>> formData) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFormDataRow('Key', 'Value', 'Description', 'Text',
                isHeader: true),
            ...formData.asMap().entries.map((entry) {
              return _buildFormDataRow(
                entry.value['key'] ?? '',
                entry.value['value'] ?? '',
                entry.value['description'] ?? '',
                entry.value['type'] ?? 'Text',
                isHeader: false,
                index: entry.key,
              );
            }),
            _buildFormDataRow('', '', '', 'Text',
                isHeader: false, isNew: true, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildFormDataRow(String key, String value, String desc, String type,
      {required bool isHeader,
      int? index,
      bool isNew = false,
      bool isLast = false}) {
    final t = ref.watch(translationsProvider);
    const typeColumnWidth = 72.0;
    final fieldTypeColor = isNew
        ? Colors.grey
        : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    final displayFileName =
        value.isEmpty ? '' : value.split(RegExp(r'[\\\\/]')).last;
    String tooltipText() {
      if (value.isEmpty) return '';
      if (kIsWeb) return value;
      try {
        final size = File(value).lengthSync();
        return '$value\n${formatBytes(size)}';
      } catch (_) {
        return value;
      }
    }

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
          SizedBox(
            width: 24,
            child: isHeader
                ? const SizedBox.shrink()
                : const Center(
                    child: FaIcon(FontAwesomeIcons.squareCheck,
                        size: 16, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
            flex: 2,
            child: _buildTableCell(key, isHeader: isHeader, hint: 'Key',
                onChanged: (v) {
              if (isNew) {
                ref.read(requestProvider.notifier).addFormData(v, '');
              } else if (index != null) {
                ref
                    .read(requestProvider.notifier)
                    .updateFormData(index, v, value);
              }
            }),
          ),
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(width: _compactTableColumnGap),
          SizedBox(
            width: typeColumnWidth,
            child: isHeader
                ? const SizedBox.shrink()
                : Center(
                    child: PopupMenuButton<String>(
                      tooltip: 'Field Type',
                      position: PopupMenuPosition.under,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 16,
                      onSelected: (String selectedType) {
                        if (index != null) {
                          ref.read(requestProvider.notifier).updateFormData(
                              index, key, '',
                              type: selectedType);
                        }
                      },
                      itemBuilder: (context) =>
                          <String>['Text', 'File'].map((String val) {
                        return PopupMenuItem<String>(
                          value: val,
                          height: 32,
                          child:
                              Text(val, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      child: SizedBox(
                        height: 20,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              type,
                              style: TextStyle(
                                  color: fieldTypeColor, fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            const FaIcon(FontAwesomeIcons.chevronDown,
                                size: 10, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: _compactTableColumnGap),
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 2,
              child: (isHeader || isNew || type != 'File')
                  ? _buildTableCell(value, isHeader: isHeader, hint: 'Value',
                      onChanged: (v) {
                      if (isNew) {
                        ref.read(requestProvider.notifier).addFormData(key, v);
                      } else if (index != null) {
                        ref
                            .read(requestProvider.notifier)
                            .updateFormData(index, key, v);
                      }
                    })
                  : InkWell(
                      onTap: () async {
                        final result = await FilePicker.platform.pickFiles();
                        if (result != null &&
                            result.files.single.path != null) {
                          ref.read(requestProvider.notifier).updateFormData(
                              index!, key, result.files.single.path!,
                              type: 'File');
                        }
                      },
                      child: value.isEmpty
                          ? Container(
                              height: 28,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                t['select_files'] ?? 'Select files',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            )
                          : Tooltip(
                              message: tooltipText(),
                              child: Container(
                                height: 28,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  displayFileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.color ??
                                          Colors.black,
                                      fontSize: 12),
                                ),
                              ),
                            ),
                    )),
          Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 3,
              child: _buildTableCell(desc,
                  isHeader: isHeader, hint: 'Description', onChanged: (v) {})),
          if (!isHeader && !isNew)
            Center(
              child: SizedBox(
                width: _compactTableSideSlotWidth,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const FaIcon(FontAwesomeIcons.xmark,
                      size: 16, color: Colors.grey),
                  onPressed: () {
                    if (index != null) {
                      ref.read(requestProvider.notifier).removeFormData(index);
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

  Widget _buildUrlEncodedTable(List<Map<String, String>> urlEncodedData) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUrlEncodedRow('Key', 'Value', 'Description', isHeader: true),
            ...urlEncodedData.asMap().entries.map((entry) {
              return _buildUrlEncodedRow(
                entry.value['key'] ?? '',
                entry.value['value'] ?? '',
                entry.value['description'] ?? '',
                isHeader: false,
                index: entry.key,
              );
            }),
            _buildUrlEncodedRow('', '', '',
                isHeader: false, isNew: true, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlEncodedRow(String key, String value, String desc,
      {required bool isHeader,
      int? index,
      bool isNew = false,
      bool isLast = false}) {
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
            const Center(
              child: FaIcon(FontAwesomeIcons.squareCheck,
                  size: 16, color: Colors.grey),
            ),
            const SizedBox(width: _compactTableColumnGap),
          ] else
            const SizedBox(width: _compactTableLeadingSlotWidth),
          Expanded(
            flex: 2,
            child: _buildTableCell(key, isHeader: isHeader, hint: 'Key',
                onChanged: (v) {
              if (isNew) {
                ref.read(requestProvider.notifier).addUrlEncodedData(v, '');
              } else if (index != null) {
                ref
                    .read(requestProvider.notifier)
                    .updateUrlEncodedData(index, v, value);
              }
            }),
          ),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 2,
              child: _buildTableCell(value, isHeader: isHeader, hint: 'Value',
                  onChanged: (v) {
                if (isNew) {
                  ref.read(requestProvider.notifier).addUrlEncodedData(key, v);
                } else if (index != null) {
                  ref
                      .read(requestProvider.notifier)
                      .updateUrlEncodedData(index, key, v);
                }
              })),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 3,
              child: _buildTableCell(desc,
                  isHeader: isHeader, hint: 'Description', onChanged: (v) {})),
          if (!isHeader && !isNew)
            Center(
              child: SizedBox(
                width: _compactTableSideSlotWidth,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const FaIcon(FontAwesomeIcons.xmark,
                      size: 16, color: Colors.grey),
                  onPressed: () {
                    if (index != null) {
                      ref
                          .read(requestProvider.notifier)
                          .removeUrlEncodedData(index);
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

  HttpRequestModel? _findRequestInCollections(
      List<CollectionModel> collections, String reqId) {
    HttpRequestModel? findInNodes(List<CollectionNode> nodes) {
      for (final node in nodes) {
        if (node is CollectionRequest && node.id == reqId) {
          return node.request;
        } else if (node is CollectionFolder) {
          final found = findInNodes(node.children);
          if (found != null) return found;
        }
      }
      return null;
    }

    for (final c in collections) {
      final found = findInNodes(c.children);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _sendRequest() async {
    var request = ref.read(requestProvider);
    final requestId = request.id;
    ref.read(isSendingProvider(requestId).notifier).state = true;

    // Get current environment for JS execution
    Map<String, dynamic> currentEnvMap = {};
    EnvironmentModel? currentEnv;
    final activeEnvironmentId = ref.read(activeEnvironmentIdProvider);
    if (activeEnvironmentId != null) {
      final environments = ref.read(activeWorkspaceEnvironmentsProvider);
      final envList =
          environments.where((e) => e.id == activeEnvironmentId).toList();
      if (envList.isNotEmpty) {
        currentEnv = envList.first;
        for (var v in currentEnv.variables) {
          if (v.enabled) currentEnvMap[v.key] = v.value;
        }
      }
    }

    final globalVarsList = ref.read(globalVariablesProvider);
    Map<String, dynamic> globalsMap = {};
    for (final v in globalVarsList) {
      if (v.enabled) globalsMap[v.key] = v.value;
    }

    Map<String, dynamic> collectionVarsMap = {};
    final collectionId = request.collectionId;
    if (collectionId != null) {
      collectionVarsMap =
          await CollectionVariablesService.instance.load(collectionId);
    }

    Future<Map<String, dynamic>> plSendRequestHandler(
        Map<String, dynamic> options) async {
      HttpRequestModel? targetReq;
      if (options.containsKey('collectionRequestId')) {
        final reqId = options['collectionRequestId'].toString();
        final collections = ref.read(activeWorkspaceCollectionsProvider);
        targetReq = _findRequestInCollections(collections, reqId);
      }

      final url = (options['url'] ?? targetReq?.url ?? '').toString();
      if (url.trim().isEmpty) {
        throw Exception('url is required');
      }
      final method = (options['method'] ?? targetReq?.method ?? 'GET')
          .toString()
          .toUpperCase();

      final headers = <Map<String, String>>[];

      // If we have a target request, initialize headers from it
      if (targetReq != null) {
        headers
            .addAll(targetReq.headers.map((e) => Map<String, String>.from(e)));
      }

      final rawHeaders = options['headers'];
      if (rawHeaders is Map) {
        rawHeaders.forEach((k, v) {
          final existingIdx = headers.indexWhere(
              (h) => h['key']?.toLowerCase() == k.toString().toLowerCase());
          if (existingIdx >= 0) {
            headers[existingIdx] = {
              'key': k.toString(),
              'value': v.toString(),
              'enabled': 'true',
            };
          } else {
            headers.add({
              'key': k.toString(),
              'value': v.toString(),
              'enabled': 'true',
            });
          }
        });
      }

      String body = targetReq?.body ?? '';
      final rawBody = options['body'];
      if (rawBody != null) {
        body = rawBody is String ? rawBody : jsonEncode(rawBody);
      }

      final req = HttpRequestModel(
        id: 'pl_send',
        protocol: 'http',
        method: method,
        url: url,
        headers: headers,
        bodyType: body.isEmpty ? 'none' : 'raw',
        rawBodyType: 'JSON',
        body: body,
      );

      final client = ref.read(networkClientProvider);
      final res = await client.sendRequest(req);
      return {
        'code': res.statusCode,
        'status': res.statusMessage,
        'headers': res.headers,
        'body': res.body,
        'responseTime': res.timeMs,
      };
    }

    // 1. Execute Pre-request Script
    if (request.preRequestScript.trim().isNotEmpty) {
      final preReqResult =
          await JsEngineService.instance.executePreRequestScript(
        request.preRequestScript,
        request,
        currentEnvMap,
        globalsMap,
        collectionVarsMap,
        plSendRequestHandler,
      );
      if (preReqResult['error'] != null) {
        ToastUtils.showError(
            context, 'Pre-request script error: ${preReqResult['error']}');
      } else {
        request = preReqResult['request'] as HttpRequestModel;
        currentEnvMap = preReqResult['environment'] as Map<String, dynamic>;
        globalsMap =
            preReqResult['globals'] as Map<String, dynamic>? ?? globalsMap;
        collectionVarsMap =
            preReqResult['collectionVariables'] as Map<String, dynamic>? ??
                collectionVarsMap;
        _updateEnvironmentVariables(currentEnv, currentEnvMap);
        _updateGlobalVariables(globalsMap);
        if (collectionId != null) {
          await CollectionVariablesService.instance
              .save(collectionId, collectionVarsMap);
        }
      }
    }

    // In case the response pane needs the client, wait... actually network client doesn't need to be kept alive per request
    // Wait, networkClient is a singleton provider? Let's assume yes.
    final client = ref.read(networkClientProvider);

    final response = await client.sendRequest(request);

    if (response.statusCode > 0) {
      final reqHeaders = <String, List<String>>{};
      for (final h in request.headers) {
        final key = h['key'] ?? '';
        final val = h['value'] ?? '';
        final enabled = h['enabled'] ?? 'true';
        if (key.isNotEmpty && enabled == 'true') {
          reqHeaders.putIfAbsent(key, () => []).add(val);
        }
      }
      ref.read(consoleProvider.notifier).addNetworkLog(
            method: request.method,
            url: request.url,
            statusCode: response.statusCode,
            statusMessage: response.statusMessage,
            requestHeaders: reqHeaders,
            requestBody: request.body.isNotEmpty ? request.body : null,
            responseHeaders: response.headers,
            responseBody: response.body,
            durationMs: response.timeMs,
          );
    } else {
      ref.read(consoleProvider.notifier).addNetworkErrorLog(
            method: request.method,
            url: request.url,
            errorMessage: response.statusMessage,
          );
    }

    // 2. Execute Tests (Post-response Script)
    HttpResponseModel finalResponse = response;
    if (request.tests.trim().isNotEmpty) {
      final testsResult = await JsEngineService.instance.executeTests(
        request.tests,
        request,
        finalResponse,
        currentEnvMap,
        globalsMap,
        collectionVarsMap,
        plSendRequestHandler,
      );
      if (testsResult['error'] != null) {
        ToastUtils.showError(
            context, 'Tests script error: ${testsResult['error']}');
      } else {
        currentEnvMap = testsResult['environment'] as Map<String, dynamic>;
        globalsMap =
            testsResult['globals'] as Map<String, dynamic>? ?? globalsMap;
        collectionVarsMap =
            testsResult['collectionVariables'] as Map<String, dynamic>? ??
                collectionVarsMap;
        _updateEnvironmentVariables(currentEnv, currentEnvMap);
        _updateGlobalVariables(globalsMap);
        if (collectionId != null) {
          await CollectionVariablesService.instance
              .save(collectionId, collectionVarsMap);
        }

        final testResults = testsResult['testResults'] as List<dynamic>? ?? [];
        if (testResults.isNotEmpty) {
          finalResponse = finalResponse.copyWith(testResults: testResults);
        }
      }
    }

    ref.read(responseProvider(requestId).notifier).state = finalResponse;
    ref.read(isSendingProvider(requestId).notifier).state = false;

    // Add to history, include response only if saveResponses is enabled
    final saveResponses = ref.read(saveResponsesProvider);
    // Ensure we always save response if the setting is enabled
    final requestToSave =
        saveResponses ? request.copyWith(response: finalResponse) : request;
    ref.read(historyProvider.notifier).addHistory(requestToSave);
  }

  void _updateGlobalVariables(Map<String, dynamic> newMap) {
    final current = ref.read(globalVariablesProvider);
    final updated = <GlobalVariable>[];
    final copy = Map<String, dynamic>.from(newMap);
    for (final v in current) {
      if (!v.enabled || !copy.containsKey(v.key)) {
        updated.add(v);
      } else {
        updated.add(v.copyWith(value: copy[v.key].toString()));
        copy.remove(v.key);
      }
    }
    copy.forEach((k, val) {
      updated.add(GlobalVariable(key: k, value: val.toString(), enabled: true));
    });
    ref.read(globalVariablesProvider.notifier).setVariables(updated);
  }

  void _updateEnvironmentVariables(
      EnvironmentModel? currentEnv, Map<String, dynamic> newMap) {
    if (currentEnv == null) return;
    final newVars = <EnvironmentVariable>[];
    final mapCopy = Map<String, dynamic>.from(newMap);

    for (var v in currentEnv.variables) {
      if (!v.enabled || !mapCopy.containsKey(v.key)) {
        newVars.add(v);
      } else {
        newVars.add(v.copyWith(value: mapCopy[v.key].toString()));
        mapCopy.remove(v.key);
      }
    }

    mapCopy.forEach((k, val) {
      newVars.add(
          EnvironmentVariable(key: k, value: val.toString(), enabled: true));
    });

    ref
        .read(environmentsProvider.notifier)
        .updateEnvironment(currentEnv.copyWith(variables: newVars));
  }

  Widget _buildSettingsTab(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingDropdown(
            t['http_version_label'] ?? 'HTTP version',
            t['http_version_desc'] ??
                'Select the HTTP version to use for sending the request.',
            request.settings['httpVersion'] ?? 'Auto',
            ['Auto', 'HTTP/1.1', 'HTTP/2', 'HTTP/3'],
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('httpVersion', val),
          ),
          _buildSettingSwitch(
            t['enable_ssl_verification'] ??
                'Enable SSL certificate verification',
            t['enable_ssl_verification_desc'] ??
                'Verify SSL certificates when sending a request. Verification failures will result in the request being aborted.',
            request.settings['enableSslVerification'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('enableSslVerification', val),
          ),
          _buildSettingSwitch(
            t['follow_redirects'] ?? 'Automatically follow redirects',
            t['follow_redirects_desc'] ??
                'Follow HTTP 3xx responses as redirects.',
            request.settings['followRedirects'] ?? true,
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('followRedirects', val),
          ),
          _buildSettingSwitch(
            t['follow_original_http_method'] ?? 'Follow original HTTP Method',
            t['follow_original_http_method_desc'] ??
                'Redirect with the original HTTP method instead of the default behavior of redirecting with GET.',
            request.settings['followOriginalHttpMethod'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('followOriginalHttpMethod', val),
          ),
          _buildSettingSwitch(
            t['follow_authorization_header'] ?? 'Follow Authorization header',
            t['follow_authorization_header_desc'] ??
                'Retain authorization header when a redirect happens to a different hostname.',
            request.settings['followAuthorizationHeader'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('followAuthorizationHeader', val),
          ),
          _buildSettingSwitch(
            t['remove_referer_header'] ?? 'Remove referer header on redirect',
            t['remove_referer_header_desc'] ??
                'Remove the referer header when a redirect happens.',
            request.settings['removeRefererHeader'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('removeRefererHeader', val),
          ),
          _buildSettingSwitch(
            t['enable_strict_http_parser'] ?? 'Enable strict HTTP parser',
            t['enable_strict_http_parser_desc'] ??
                'Restrict responses with invalid HTTP headers.',
            request.settings['enableStrictHttpParser'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('enableStrictHttpParser', val),
          ),
          _buildSettingSwitch(
            t['encode_url_automatically'] ?? 'Encode URL automatically',
            t['encode_url_automatically_desc'] ??
                'Encode the URL\'s path, query parameters, and authentication fields.',
            request.settings['encodeUrlAutomatically'] ?? true,
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('encodeUrlAutomatically', val),
          ),
          _buildSettingSwitch(
            t['disable_cookie_jar'] ?? 'Disable cookie jar',
            t['disable_cookie_jar_desc'] ??
                'Prevent cookies used in this request from being stored in the cookie jar. Existing cookies in the cookie jar will not be added as headers for this request.',
            request.settings['disableCookieJar'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('disableCookieJar', val),
          ),
          _buildSettingSwitch(
            t['use_server_cipher_suite'] ??
                'Use server cipher suite during handshake',
            t['use_server_cipher_suite_desc'] ??
                'Use the server\'s cipher suite order instead of the client\'s during handshake.',
            request.settings['useServerCipherSuite'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('useServerCipherSuite', val),
          ),
          _buildSettingTextField(
            t['max_redirects'] ?? 'Maximum number of redirects',
            t['max_redirects_desc'] ??
                'Set a cap on the maximum number of redirects to follow.',
            request.settings['maxRedirects']?.toString() ?? '10',
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('maxRedirects', int.tryParse(val) ?? 10),
            isNumber: true,
          ),
          _buildSettingTextField(
            t['disabled_protocols'] ??
                'TLS/SSL protocols disabled during handshake',
            t['disabled_protocols_desc'] ??
                'Specify the SSL and TLS protocol versions to be disabled during handshake. All other protocols will be enabled.',
            request.settings['disabledProtocols'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('disabledProtocols', val),
            maxLines: 3,
          ),
          _buildSettingTextField(
            t['cipher_suite_selection'] ?? 'Cipher suite selection',
            t['cipher_suite_selection_desc'] ??
                'Order of cipher suites that the SSL server profile uses to establish a secure connection.',
            request.settings['cipherSuiteSelection'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateSettings('cipherSuiteSelection', val),
            maxLines: 3,
            hint: t['enter_cipher_suites'] ?? 'Enter cipher suites',
          ),
        ],
      ),
    );
  }

  Widget _buildDocTab(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: DocEditor(
        title: t['doc'] ?? 'Doc',
        richTextLabel: t['rich_text'] ?? 'Rich Text',
        markdownLabel: t['markdown'] ?? 'Markdown',
        editLabel: t['edit'] ?? 'Edit',
        previewLabel: t['preview'] ?? 'Preview',
        value: request.description,
        onChanged: (v) => ref.read(requestProvider.notifier).updateDescription(v),
      ),
    );
  }

  Widget _buildSettingDropdown(String label, String description, String value,
      List<String> items, Function(String) onChanged) {
    final displayValue = items.contains(value) ? value : items.first;
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
                Text(label,
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
              child: PopupMenuButton<String>(
                tooltip: label,
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
                onSelected: (String newValue) {
                  onChanged(newValue);
                },
                itemBuilder: (context) => items.map((String val) {
                  return PopupMenuItem<String>(
                    value: val,
                    height: 32,
                    child: Text(val, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                child: SizedBox(
                  height: 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayValue,
                        style:
                            const TextStyle(color: Colors.blue, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const FaIcon(FontAwesomeIcons.chevronDown,
                          size: 10, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSwitch(
      String label, String description, bool value, Function(bool) onChanged) {
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
                Text(label,
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
              child: SizedBox(
                height: 24,
                child: Transform.scale(
                  scale: 0.65,
                  child: Switch(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTextField(String label, String description, String value,
      Function(String) onChanged,
      {bool isNumber = false, int maxLines = 1, String? hint}) {
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
                Text(label,
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
            child: SizedBox(
              height: maxLines == 1 ? 36 : null,
              child: TextField(
                controller: TextEditingController(text: value)
                  ..selection = TextSelection.collapsed(offset: value.length),
                onChanged: onChanged,
                keyboardType:
                    isNumber ? TextInputType.number : TextInputType.text,
                maxLines: maxLines,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.grey),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: maxLines == 1 ? 0 : 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthTextField(
      String label, String value, Function(String) onChanged,
      {bool obscureText = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.normal)),
        const SizedBox(height: 8),
        Container(
          height: maxLines == 1 ? 36 : null,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: TextField(
            controller: TextEditingController(text: value)
              ..selection = TextSelection.collapsed(offset: value.length),
            onChanged: onChanged,
            obscureText: obscureText,
            maxLines: maxLines,
            textAlignVertical: maxLines == 1 ? null : TextAlignVertical.top,
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium!.color!,
                fontFamily: 'Consolas',
                fontSize: 12),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAuthDropdown(String label, String value, List<String> items,
      Function(String) onChanged) {
    final displayValue = items.contains(value) ? value : items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.normal)),
        const SizedBox(height: 8),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8.0),
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: PopupMenuButton<String>(
            tooltip: label,
            position: PopupMenuPosition.under,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 234),
            splashRadius: 16,
            onSelected: (String newValue) {
              onChanged(newValue);
            },
            itemBuilder: (context) => items.map((String val) {
              return PopupMenuItem<String>(
                value: val,
                height: 32,
                child: Text(val, style: const TextStyle(fontSize: 12)),
              );
            }).toList(),
            child: SizedBox(
              height: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayValue,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium!.color!,
                        fontFamily: 'Consolas',
                        fontSize: 12),
                  ),
                  const FaIcon(FontAwesomeIcons.chevronDown,
                      size: 10, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAuthCheckbox(
      String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CustomCheckbox(
              value: value,
              onChanged: (bool? newValue) {
                if (newValue != null) {
                  onChanged(newValue);
                }
              },
              side: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium!.color!,
                  fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildJwtBearerAuth(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthDropdown(
            'Add JWT token to',
            request.authConfig['jwtAddTo'] ?? 'Request Header',
            ['Request Header', 'Query Param'],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('jwtAddTo', val)),
        _buildAuthDropdown(
            'Algorithm',
            request.authConfig['jwtAlgorithm'] ?? 'HS256',
            [
              'HS256',
              'HS384',
              'HS512',
              'RS256',
              'RS384',
              'RS512',
              'ES256',
              'ES384',
              'ES512',
              'PS256',
              'PS384',
              'PS512'
            ],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('jwtAlgorithm', val)),
        _buildAuthTextField(
            'Secret',
            request.authConfig['jwtSecret'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('jwtSecret', val)),
        _buildAuthCheckbox(
            'Secret Base64 encoded',
            request.authConfig['jwtSecretBase64Encoded'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('jwtSecretBase64Encoded', val)),
        _buildAuthTextField(
            'Payload',
            request.authConfig['jwtPayload'] ?? '{}',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('jwtPayload', val),
            maxLines: 4),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(t['advanced_configuration'] ?? 'Advanced configuration',
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.normal,
                  fontSize: 12)),
        ),
        _buildAuthTextField(
            'Request header prefix',
            request.authConfig['jwtRequestHeaderPrefix'] ?? 'Bearer',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('jwtRequestHeaderPrefix', val)),
        _buildAuthTextField(
            'JWT headers',
            request.authConfig['jwtHeaders'] ?? '{}',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('jwtHeaders', val),
            maxLines: 3),
      ],
    );
  }

  Widget _buildDigestAuth(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthTextField(
            'Username',
            request.authConfig['digestUsername'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestUsername', val)),
        _buildAuthTextField(
            'Password',
            request.authConfig['digestPassword'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestPassword', val),
            obscureText: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(t['advanced_configuration'] ?? 'Advanced configuration',
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.normal,
                  fontSize: 12)),
        ),
        _buildAuthTextField(
            'Realm',
            request.authConfig['digestRealm'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestRealm', val)),
        _buildAuthTextField(
            'Nonce',
            request.authConfig['digestNonce'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestNonce', val)),
        _buildAuthDropdown(
            'Algorithm',
            request.authConfig['digestAlgorithm'] ?? 'MD5',
            [
              'MD5',
              'MD5-sess',
              'SHA-256',
              'SHA-256-sess',
              'SHA-512-256',
              'SHA-512-256-sess'
            ],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestAlgorithm', val)),
        _buildAuthTextField(
            'qop',
            request.authConfig['digestQop'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestQop', val)),
        _buildAuthTextField(
            'Nonce Count',
            request.authConfig['digestNonceCount'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestNonceCount', val)),
        _buildAuthTextField(
            'Client Nonce',
            request.authConfig['digestClientNonce'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestClientNonce', val)),
        _buildAuthTextField(
            'Opaque',
            request.authConfig['digestOpaque'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestOpaque', val)),
        _buildAuthCheckbox(
            'Yes, disable retrying the request',
            request.authConfig['digestDisableRetry'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('digestDisableRetry', val)),
      ],
    );
  }

  Widget _buildOAuth1Auth(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthDropdown(
            'Add authorization data to',
            request.authConfig['oauth1AddTo'] ?? 'Request Headers',
            ['Request Body', 'Request Headers'],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1AddTo', val)),
        _buildAuthDropdown(
            'Signature Method',
            request.authConfig['oauth1SignatureMethod'] ?? 'HMAC-SHA1',
            [
              'HMAC-SHA1',
              'HMAC-SHA256',
              'HMAC-SHA512',
              'RSA-SHA1',
              'RSA-SHA256',
              'RSA-SHA512',
              'PLAINTEXT'
            ],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1SignatureMethod', val)),
        _buildAuthTextField(
            'Consumer Key',
            request.authConfig['oauth1ConsumerKey'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1ConsumerKey', val)),
        _buildAuthTextField(
            'Consumer Secret',
            request.authConfig['oauth1ConsumerSecret'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1ConsumerSecret', val)),
        _buildAuthTextField(
            'Access Token',
            request.authConfig['oauth1AccessToken'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1AccessToken', val)),
        _buildAuthTextField(
            'Token Secret',
            request.authConfig['oauth1TokenSecret'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1TokenSecret', val)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(t['advanced_configuration'] ?? 'Advanced configuration',
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.normal,
                  fontSize: 12)),
        ),
        _buildAuthTextField(
            'Callback URL',
            request.authConfig['oauth1CallbackUrl'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1CallbackUrl', val)),
        _buildAuthTextField(
            'Verifier',
            request.authConfig['oauth1Verifier'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1Verifier', val)),
        _buildAuthTextField(
            'Timestamp',
            request.authConfig['oauth1Timestamp'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1Timestamp', val)),
        _buildAuthTextField(
            'Nonce',
            request.authConfig['oauth1Nonce'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1Nonce', val)),
        _buildAuthTextField(
            'Version',
            request.authConfig['oauth1Version'] ?? '1.0',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1Version', val)),
        _buildAuthTextField(
            'Realm',
            request.authConfig['oauth1Realm'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1Realm', val)),
        _buildAuthCheckbox(
            'Include body hash',
            request.authConfig['oauth1IncludeBodyHash'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1IncludeBodyHash', val)),
        _buildAuthCheckbox(
            'Add empty parameters to signature',
            request.authConfig['oauth1AddEmptyParamsToSign'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth1AddEmptyParamsToSign', val)),
      ],
    );
  }

  Widget _buildOAuth2Auth(HttpRequestModel request) {
    final t = ref.watch(translationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthDropdown(
            'Add authorization data to',
            request.authConfig['oauth2AddTo'] ?? 'Request Headers',
            ['Request URL', 'Request Headers'],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2AddTo', val)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(t['current_token'] ?? 'Current Token',
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.normal,
                  fontSize: 12)),
        ),
        _buildAuthTextField(
            'Token',
            request.authConfig['oauth2Token'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2Token', val)),
        _buildAuthTextField(
            'Header Prefix',
            request.authConfig['oauth2HeaderPrefix'] ?? 'Bearer',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2HeaderPrefix', val)),
        _buildAuthCheckbox(
            'Auto-refresh Token',
            request.authConfig['oauth2AutoRefresh'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2AutoRefresh', val)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(t['configure_new_token'] ?? 'Configure New Token',
              style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.normal,
                  fontSize: 12)),
        ),
        _buildAuthTextField(
            'Token Name',
            request.authConfig['oauth2TokenName'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2TokenName', val)),
        _buildAuthDropdown(
            'Grant type',
            request.authConfig['oauth2GrantType'] ?? 'Authorization Code',
            [
              'Authorization Code',
              'Implicit',
              'Password Credentials',
              'Client Credentials'
            ],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2GrantType', val)),
        _buildAuthTextField(
            'Callback URL',
            request.authConfig['oauth2CallbackUrl'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2CallbackUrl', val)),
        _buildAuthCheckbox(
            'Authorize using browser',
            request.authConfig['oauth2AuthorizeBrowser'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2AuthorizeBrowser', val)),
        _buildAuthTextField(
            'Auth URL',
            request.authConfig['oauth2AuthUrl'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2AuthUrl', val)),
        _buildAuthTextField(
            'Access Token URL',
            request.authConfig['oauth2AccessTokenUrl'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2AccessTokenUrl', val)),
        _buildAuthTextField(
            'Client ID',
            request.authConfig['oauth2ClientId'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2ClientId', val)),
        _buildAuthTextField(
            'Client Secret',
            request.authConfig['oauth2ClientSecret'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2ClientSecret', val),
            obscureText: true),
        _buildAuthTextField(
            'Scope',
            request.authConfig['oauth2Scope'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2Scope', val)),
        _buildAuthTextField(
            'State',
            request.authConfig['oauth2State'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2State', val)),
        _buildAuthDropdown(
            'Client Authentication',
            request.authConfig['oauth2ClientAuth'] ??
                'Send as Basic Auth header',
            ['Send as Basic Auth header', 'Send client credentials in body'],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('oauth2ClientAuth', val)),
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF26B3A),
                foregroundColor: Colors.white,
                elevation: 0),
            child: Text(t['get_new_access_token'] ?? 'Get New Access Token',
                style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildHawkAuth(HttpRequestModel request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthTextField(
            'Auth ID',
            request.authConfig['hawkAuthId'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkAuthId', val)),
        _buildAuthTextField(
            'Auth Key',
            request.authConfig['hawkAuthKey'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkAuthKey', val)),
        _buildAuthDropdown(
            'Algorithm',
            request.authConfig['hawkAlgorithm'] ?? 'sha256',
            ['sha256', 'sha1'],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkAlgorithm', val)),
        _buildAuthTextField(
            'User',
            request.authConfig['hawkUser'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkUser', val)),
        _buildAuthTextField(
            'Nonce',
            request.authConfig['hawkNonce'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkNonce', val)),
        _buildAuthTextField(
            'Ext',
            request.authConfig['hawkExt'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkExt', val)),
        _buildAuthTextField(
            'App',
            request.authConfig['hawkApp'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkApp', val)),
        _buildAuthTextField(
            'Dlg',
            request.authConfig['hawkDlg'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkDlg', val)),
        _buildAuthTextField(
            'Timestamp',
            request.authConfig['hawkTimestamp'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkTimestamp', val)),
        _buildAuthCheckbox(
            'Include payload hash',
            request.authConfig['hawkIncludePayloadHash'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('hawkIncludePayloadHash', val)),
      ],
    );
  }

  Widget _buildAwsAuth(HttpRequestModel request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthTextField(
            'AccessKey',
            request.authConfig['awsAccessKey'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('awsAccessKey', val)),
        _buildAuthTextField(
            'SecretKey',
            request.authConfig['awsSecretKey'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('awsSecretKey', val),
            obscureText: true),
        _buildAuthTextField(
            'AWS Region',
            request.authConfig['awsRegion'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('awsRegion', val)),
        _buildAuthTextField(
            'Service Name',
            request.authConfig['awsService'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('awsService', val)),
        _buildAuthTextField(
            'Session Token',
            request.authConfig['awsSessionToken'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('awsSessionToken', val)),
      ],
    );
  }

  Widget _buildNtlmAuth(HttpRequestModel request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthTextField(
            'Username',
            request.authConfig['ntlmUsername'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('ntlmUsername', val)),
        _buildAuthTextField(
            'Password',
            request.authConfig['ntlmPassword'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('ntlmPassword', val),
            obscureText: true),
        _buildAuthTextField(
            'Domain',
            request.authConfig['ntlmDomain'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('ntlmDomain', val)),
        _buildAuthTextField(
            'Workstation',
            request.authConfig['ntlmWorkstation'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('ntlmWorkstation', val)),
        _buildAuthCheckbox(
            'Disable Retrying Request',
            request.authConfig['ntlmDisableRetry'] ?? false,
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('ntlmDisableRetry', val)),
      ],
    );
  }

  Widget _buildAkamaiAuth(HttpRequestModel request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthTextField(
            'Access Token',
            request.authConfig['akamaiAccessToken'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('akamaiAccessToken', val)),
        _buildAuthTextField(
            'Client Token',
            request.authConfig['akamaiClientToken'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('akamaiClientToken', val)),
        _buildAuthTextField(
            'Client Secret',
            request.authConfig['akamaiClientSecret'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('akamaiClientSecret', val),
            obscureText: true),
        _buildAuthTextField(
            'Base URL',
            request.authConfig['akamaiBaseUrl'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('akamaiBaseUrl', val)),
        _buildAuthTextField(
            'Nonce',
            request.authConfig['akamaiNonce'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('akamaiNonce', val)),
        _buildAuthTextField(
            'Timestamp',
            request.authConfig['akamaiTimestamp'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('akamaiTimestamp', val)),
        _buildAuthTextField(
            'Headers to sign',
            request.authConfig['akamaiHeadersToSign'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('akamaiHeadersToSign', val)),
      ],
    );
  }

  Widget _buildAsapAuth(HttpRequestModel request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAuthTextField(
            'Issuer',
            request.authConfig['asapIssuer'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('asapIssuer', val)),
        _buildAuthTextField(
            'Subject',
            request.authConfig['asapSubject'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('asapSubject', val)),
        _buildAuthTextField(
            'Audience',
            request.authConfig['asapAudience'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('asapAudience', val)),
        _buildAuthTextField(
            'Key ID',
            request.authConfig['asapKeyId'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('asapKeyId', val)),
        _buildAuthTextField(
            'Private Key',
            request.authConfig['asapPrivateKey'] ?? '',
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('asapPrivateKey', val),
            maxLines: 4),
        _buildAuthDropdown(
            'Algorithm',
            request.authConfig['asapAlgorithm'] ?? 'RS256',
            ['RS256'],
            (val) => ref
                .read(requestProvider.notifier)
                .updateAuthConfig('asapAlgorithm', val)),
      ],
    );
  }
}
