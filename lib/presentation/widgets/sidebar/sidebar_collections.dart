part of 'sidebar.dart';

extension SidebarCollectionsExt on _SidebarState {
  void _showAddCollectionDialog(BuildContext context, String workspaceId) {
    final controller = TextEditingController();
    AppOverlayDialogs.showModalLike(
      context: context,
      barrierLabel: 'New Collection',
      builder: (context) => Consumer(builder: (context, ref, _) {
        final t = ref.watch(translationsProvider);
        return Dialog(
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
                      Text(t['new_collection'] ?? 'New Collection',
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
                          hintText: 'e.g. User Service API',
                          hintStyle: const TextStyle(color: Colors.grey),
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6.0),
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6.0),
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor),
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
                          if (controller.text.trim().isNotEmpty) {
                            final newCollection = CollectionModel(
                              id: DateTime.now()
                                  .millisecondsSinceEpoch
                                  .toString(),
                              workspaceId: workspaceId,
                              name: controller.text.trim(),
                            );
                            ref
                                .read(collectionsProvider.notifier)
                                .addCollection(newCollection);
                            _expandNode(newCollection.id);
                          }
                          Navigator.pop(context);
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
                        child: Text(t['create'] ?? 'Create',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCollectionRoot(CollectionModel collection) {
    final sortedChildren = List<CollectionNode>.from(collection.children)
      ..sort((a, b) {
        if (a is CollectionFolder && b is CollectionRequest) return -1;
        if (a is CollectionRequest && b is CollectionFolder) return 1;
        return 0;
      });

    return _buildTreeNode(
      id: collection.id,
      level: 0,
      initiallyExpanded: true,
      isFolder: false,
      paddingLeftOverride: 16,
      title: Text(collection.name,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis),
      actionButtons: _buildActionButtons(collection, null, [collection.name]),
      onTap: () {
        if (widget.onCollectionTap != null) {
          widget.onCollectionTap!(collection.id, false, collection.name);
        }
      },
      children: [
        for (final node in sortedChildren)
          _buildCollectionNode(collection, node, 1, [collection.name], null),
      ],
    );
  }

  Widget _buildCollectionNode(CollectionModel collection, CollectionNode node,
      int level, List<String> currentPath, String? parentFolderId) {
    if (node is CollectionFolder) {
      final sortedChildren = List<CollectionNode>.from(node.children)
        ..sort((a, b) {
          if (a is CollectionFolder && b is CollectionRequest) return -1;
          if (a is CollectionRequest && b is CollectionFolder) return 1;
          return 0;
        });

      return _buildTreeNode(
        id: node.id,
        level: level,
        initiallyExpanded: false,
        isFolder: true,
        title: Text(node.name,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis),
        actionButtons:
            _buildActionButtons(collection, node, [...currentPath, node.name]),
        onTap: () {
          if (widget.onCollectionTap != null) {
            widget.onCollectionTap!(node.id, true, node.name);
          }
        },
        children: [
          for (final child in sortedChildren)
            _buildCollectionNode(collection, child, level + 1,
                [...currentPath, node.name], node.id),
        ],
      );
    } else if (node is CollectionRequest) {
      return _buildTreeNode(
        id: node.id,
        level: level,
        initiallyExpanded: false,
        title: Text(node.name,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis),
        isSelected: ref.watch(requestProvider).id == node.id,
        icon: Text(
          node.request.method,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: _getMethodColor(node.request.method),
          ),
        ),
        actionButtons: _buildActionButtons(collection, node, currentPath),
        children: [
          for (final c in node.cases)
            _buildRequestCaseNode(
              collection,
              node,
              c,
              level + 1,
              [...currentPath, node.name],
              parentFolderId,
            ),
        ],
        onTap: () {
          final requestWithPath = node.request.copyWith(
            id: node.id,
            name: node.name,
            folderPath: currentPath,
            collectionId: collection.id,
            folderId: parentFolderId,
          );
          if (widget.onRequestTap != null) {
            widget.onRequestTap!(requestWithPath);
          } else {
            ref.read(requestProvider.notifier).loadRequest(requestWithPath);
          }
        },
      );
    } else if (node is CollectionRequestCase) {
      return _buildRequestCaseNode(
        collection,
        null,
        node,
        level,
        currentPath,
        parentFolderId,
      );
    }
    return const SizedBox();
  }

  Widget _buildRequestCaseNode(
    CollectionModel collection,
    CollectionRequest? parentRequest,
    CollectionRequestCase caseNode,
    int level,
    List<String> currentPath,
    String? parentFolderId,
  ) {
    return _buildTreeNode(
      id: caseNode.id,
      level: level,
      initiallyExpanded: false,
      title: Text(caseNode.name,
          style: const TextStyle(fontSize: 12),
          overflow: TextOverflow.ellipsis),
      isSelected: ref.watch(requestProvider).id == caseNode.id,
      icon: const FaIcon(FontAwesomeIcons.bookmark, size: 11, color: Colors.grey),
      actionButtons: parentRequest == null
          ? _buildActionButtons(collection, caseNode, currentPath)
          : _buildCaseActionButtons(
              collection,
              parentRequest,
              caseNode,
              currentPath,
            ),
      children: const [],
      onTap: () {
        final requestWithPath = caseNode.request.copyWith(
          id: caseNode.id,
          name: caseNode.name,
          folderPath: currentPath,
          collectionId: collection.id,
          folderId: parentFolderId,
        );
        if (widget.onRequestTap != null) {
          widget.onRequestTap!(requestWithPath);
        } else {
          ref.read(requestProvider.notifier).loadRequest(requestWithPath);
        }
      },
    );
  }

  Widget _buildActionButtons(CollectionModel collection, CollectionNode? node,
      List<String> folderPath) {
    final isRequest = node is CollectionRequest;
    final isContainer = node == null || node is CollectionFolder;
    return Consumer(builder: (context, ref, _) {
      final t = ref.watch(translationsProvider);
      return SizedBox(
        height: 24,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isContainer)
              InkWell(
                onTap: () {
                  final requestId =
                      DateTime.now().millisecondsSinceEpoch.toString();
                  final newRequest = CollectionRequest(
                    id: requestId,
                    name: 'New Request',
                    request: HttpRequestModel(
                      id: requestId,
                      url: '',
                      method: 'GET',
                      name: 'New Request',
                      collectionId: collection.id,
                      folderId: node?.id,
                      folderPath: folderPath,
                    ),
                  );
                  if (node == null) {
                    final updatedCollection = collection.copyWith(
                      children: [...collection.children, newRequest],
                    );
                    ref
                        .read(collectionsProvider.notifier)
                        .updateCollection(updatedCollection);
                    _expandNode(collection.id);
                  } else {
                    final updatedCollection =
                        _addNodeToFolder(collection, node.id, newRequest);
                    ref
                        .read(collectionsProvider.notifier)
                        .updateCollection(updatedCollection);
                    _expandNode(node.id);
                  }
                  if (widget.onRequestTap != null) {
                    widget.onRequestTap!(newRequest.request);
                  } else {
                    ref
                        .read(requestProvider.notifier)
                        .loadRequest(newRequest.request);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: FaIcon(
                    FontAwesomeIcons.plus,
                    size: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            Builder(
              builder: (popupContext) => PopupMenuButton<String>(
                tooltip: 'More actions',
                offset: const Offset(24, 0),
                constraints: const BoxConstraints(),
                onOpened: () {
                  final state = popupContext
                      .findAncestorStateOfType<HoverContainerState>();
                  if (state != null) {
                    state.setPopupOpen(true);
                  }
                },
                onCanceled: () {
                  final state = popupContext
                      .findAncestorStateOfType<HoverContainerState>();
                  if (state != null) {
                    state.setPopupOpen(false);
                  }
                },
                onSelected: (value) {
                  final state = popupContext
                      .findAncestorStateOfType<HoverContainerState>();
                  if (state != null) {
                    state.setPopupOpen(false);
                  }
                  if (value == 'add_request') {
                    final requestId =
                        DateTime.now().millisecondsSinceEpoch.toString();
                    final newRequest = CollectionRequest(
                      id: requestId,
                      name: 'New Request',
                      request: HttpRequestModel(
                        id: requestId,
                        url: '',
                        method: 'GET',
                        name: 'New Request',
                        collectionId: collection.id,
                        folderId: node?.id,
                        folderPath: folderPath,
                      ),
                    );
                    if (node == null) {
                      final updatedCollection = collection.copyWith(
                        children: [...collection.children, newRequest],
                      );
                      ref
                          .read(collectionsProvider.notifier)
                          .updateCollection(updatedCollection);
                      _expandNode(collection.id);
                    } else {
                      final updatedCollection =
                          _addNodeToFolder(collection, node.id, newRequest);
                      ref
                          .read(collectionsProvider.notifier)
                          .updateCollection(updatedCollection);
                      _expandNode(node.id);
                    }
                    if (widget.onRequestTap != null) {
                      widget.onRequestTap!(newRequest.request);
                    } else {
                      ref
                          .read(requestProvider.notifier)
                          .loadRequest(newRequest.request);
                    }
                  } else if (value == 'add_folder') {
                    _showAddFolderDialog(context, collection,
                        node is CollectionFolder ? node : null);
                  } else if (value == 'rename') {
                    _showRenameDialog(context,
                        collection: collection, node: node);
                  } else if (value == 'duplicate') {
                    if (node == null) {
                      final newColl = collection.copyWith(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: '${collection.name} Copy',
                      );
                      ref
                          .read(collectionsProvider.notifier)
                          .addCollection(newColl);
                    } else {
                      CollectionNode duplicatedNode;
                      if (node is CollectionFolder) {
                        duplicatedNode = node.copyWith(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            name: '${node.name} Copy');
                      } else if (node is CollectionRequest) {
                        final newId = DateTime.now()
                                .millisecondsSinceEpoch
                                .toString();
                        final newCases = node.cases.map((c) {
                          final newCaseId = '${newId}_${c.id}';
                          return c.copyWith(
                            id: newCaseId,
                            request: c.request.copyWith(id: newCaseId),
                          );
                        }).toList();
                        duplicatedNode = node.copyWith(
                            id: newId,
                            name: '${node.name} Copy',
                            request: node.request
                                .copyWith(id: newId, name: '${node.name} Copy'),
                            cases: newCases);
                      } else {
                        return;
                      }
                      final updatedCollection = _duplicateNodeInCollection(
                          collection, node.id, duplicatedNode);
                      ref
                          .read(collectionsProvider.notifier)
                          .updateCollection(updatedCollection);
                    }
                  } else if (value == 'delete') {
                    if (node == null) {
                      ref
                          .read(collectionsProvider.notifier)
                          .deleteCollection(collection.id);
                    } else {
                      final updatedCollection =
                          _updateNodeInCollection(collection, node.id, null);
                      ref
                          .read(collectionsProvider.notifier)
                          .updateCollection(updatedCollection);
                    }
                  }
                },
                itemBuilder: (context) => [
                  if (isContainer)
                    PopupMenuItem(
                      value: 'add_request',
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(t['add_request'] ?? 'Add request',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.normal)),
                    ),
                  if (isContainer)
                    PopupMenuItem(
                      value: 'add_folder',
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(t['add_folder'] ?? 'Add folder',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.normal)),
                    ),
                  if (isContainer) const PopupMenuDivider(height: 8),
                  if (isContainer)
                    PopupMenuItem(
                      value: 'run',
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(t['run'] ?? 'Run',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.normal)),
                    ),
                  if (isContainer) const PopupMenuDivider(height: 8),
                  PopupMenuItem(
                    value: 'rename',
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(t['rename'] ?? 'Rename',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal)),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(t['duplicate'] ?? 'Duplicate',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal)),
                  ),
                  const PopupMenuDivider(height: 8),
                  PopupMenuItem(
                    value: 'delete',
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(t['delete'] ?? 'Delete',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.normal)),
                  ),
                  if (node == null) const PopupMenuDivider(height: 8),
                  if (node == null)
                    PopupMenuItem(
                      value: 'more',
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t['more'] ?? 'More',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.normal)),
                          const FaIcon(FontAwesomeIcons.chevronRight,
                              size: 13, color: Colors.grey),
                        ],
                      ),
                    ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: FaIcon(FontAwesomeIcons.ellipsis,
                      size: 13, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCaseActionButtons(
    CollectionModel collection,
    CollectionRequest parentRequest,
    CollectionRequestCase caseNode,
    List<String> folderPath,
  ) {
    return Consumer(builder: (context, ref, _) {
      final t = ref.watch(translationsProvider);
      return SizedBox(
        height: 24,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Builder(
              builder: (popupContext) => PopupMenuButton<String>(
                tooltip: 'More actions',
                offset: const Offset(24, 0),
                constraints: const BoxConstraints(),
                onOpened: () {
                  final state = popupContext
                      .findAncestorStateOfType<HoverContainerState>();
                  if (state != null) {
                    state.setPopupOpen(true);
                  }
                },
                onCanceled: () {
                  final state = popupContext
                      .findAncestorStateOfType<HoverContainerState>();
                  if (state != null) {
                    state.setPopupOpen(false);
                  }
                },
                onSelected: (value) {
                  final state = popupContext
                      .findAncestorStateOfType<HoverContainerState>();
                  if (state != null) {
                    state.setPopupOpen(false);
                  }
                  if (value == 'rename') {
                    _showRenameDialog(context,
                        collection: collection, node: caseNode);
                  } else if (value == 'duplicate') {
                    final newId =
                        DateTime.now().millisecondsSinceEpoch.toString();
                    final duplicated = caseNode.copyWith(
                      id: newId,
                      name: '${caseNode.name} Copy',
                      request: caseNode.request
                          .copyWith(id: newId, name: '${caseNode.name} Copy'),
                    );
                    final updatedCollection = _duplicateCaseInCollection(
                      collection,
                      parentRequestId: parentRequest.id,
                      targetCaseId: caseNode.id,
                      newCase: duplicated,
                    );
                    ref
                        .read(collectionsProvider.notifier)
                        .updateCollection(updatedCollection);
                  } else if (value == 'delete') {
                    final updatedCollection = _deleteCaseInCollection(
                      collection,
                      parentRequestId: parentRequest.id,
                      caseId: caseNode.id,
                    );
                    ref
                        .read(collectionsProvider.notifier)
                        .updateCollection(updatedCollection);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(t['rename'] ?? 'Rename',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal)),
                  ),
                  PopupMenuItem(
                    value: 'duplicate',
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(t['duplicate'] ?? 'Duplicate',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal)),
                  ),
                  const PopupMenuDivider(height: 8),
                  PopupMenuItem(
                    value: 'delete',
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(t['delete'] ?? 'Delete',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.normal)),
                  ),
                ],
                child: const Padding(
                  padding: EdgeInsets.all(4.0),
                  child: FaIcon(FontAwesomeIcons.ellipsis,
                      size: 13, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  CollectionModel _duplicateCaseInCollection(
    CollectionModel collection, {
    required String parentRequestId,
    required String targetCaseId,
    required CollectionRequestCase newCase,
  }) {
    List<CollectionNode> visitNodes(List<CollectionNode> nodes) {
      return nodes.map((node) {
        if (node is CollectionFolder) {
          return node.copyWith(children: visitNodes(node.children));
        }
        if (node is CollectionRequest && node.id == parentRequestId) {
          final nextCases = <CollectionRequestCase>[];
          for (final c in node.cases) {
            nextCases.add(c);
            if (c.id == targetCaseId) {
              nextCases.add(newCase);
            }
          }
          return node.copyWith(cases: nextCases);
        }
        return node;
      }).toList();
    }

    return collection.copyWith(children: visitNodes(collection.children));
  }

  CollectionModel _deleteCaseInCollection(
    CollectionModel collection, {
    required String parentRequestId,
    required String caseId,
  }) {
    List<CollectionNode> visitNodes(List<CollectionNode> nodes) {
      return nodes.map((node) {
        if (node is CollectionFolder) {
          return node.copyWith(children: visitNodes(node.children));
        }
        if (node is CollectionRequest && node.id == parentRequestId) {
          return node.copyWith(
              cases: node.cases.where((c) => c.id != caseId).toList());
        }
        return node;
      }).toList();
    }

    return collection.copyWith(children: visitNodes(collection.children));
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
        return const Color(0xFF9C27B0);
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

  CollectionModel _updateNodeInCollection(
      CollectionModel collection, String targetId, CollectionNode? newNode) {
    List<CollectionNode> updateNodes(List<CollectionNode> nodes) {
      List<CollectionNode> result = [];
      for (final node in nodes) {
        if (node.id == targetId) {
          if (newNode != null) {
            result.add(newNode);
          }
        } else if (node is CollectionFolder) {
          result.add(node.copyWith(children: updateNodes(node.children)));
        } else if (node is CollectionRequest) {
          final updatedCases = <CollectionRequestCase>[];
          for (final c in node.cases) {
            if (c.id == targetId) {
              if (newNode is CollectionRequestCase) {
                updatedCases.add(newNode);
              } else if (newNode != null) {
                updatedCases.add(c);
              }
            } else {
              updatedCases.add(c);
            }
          }
          result.add(node.copyWith(cases: updatedCases));
        } else {
          result.add(node);
        }
      }
      return result;
    }

    return collection.copyWith(children: updateNodes(collection.children));
  }

  CollectionModel _duplicateNodeInCollection(
      CollectionModel collection, String targetId, CollectionNode newNode) {
    List<CollectionNode> duplicateNode(List<CollectionNode> nodes) {
      List<CollectionNode> result = [];
      for (final node in nodes) {
        result.add(node);
        if (node.id == targetId) {
          result.add(newNode);
        } else if (node is CollectionFolder) {
          result.removeLast();
          result.add(node.copyWith(children: duplicateNode(node.children)));
        } else if (node is CollectionRequest) {
          final nextCases = <CollectionRequestCase>[];
          for (final c in node.cases) {
            nextCases.add(c);
            if (c.id == targetId && newNode is CollectionRequestCase) {
              nextCases.add(newNode);
            }
          }
          result.removeLast();
          result.add(node.copyWith(cases: nextCases));
        }
      }
      return result;
    }

    return collection.copyWith(children: duplicateNode(collection.children));
  }

  CollectionModel _addNodeToFolder(
      CollectionModel collection, String folderId, CollectionNode newNode) {
    List<CollectionNode> addNode(List<CollectionNode> nodes) {
      List<CollectionNode> result = [];
      for (final node in nodes) {
        if (node.id == folderId && node is CollectionFolder) {
          result.add(node.copyWith(children: [...node.children, newNode]));
        } else if (node is CollectionFolder) {
          result.add(node.copyWith(children: addNode(node.children)));
        } else {
          result.add(node);
        }
      }
      return result;
    }

    return collection.copyWith(children: addNode(collection.children));
  }

  void _showRenameDialog(BuildContext context,
      {required CollectionModel collection, CollectionNode? node}) {
    final t = ref.watch(translationsProvider);
    final isCollection = node == null;
    final initialName = isCollection ? collection.name : node.name;
    final controller = TextEditingController(text: initialName);

    AppOverlayDialogs.showModalLike(
      context: context,
      barrierLabel: 'Rename',
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
                    Text(
                        '${t['rename'] ?? 'Rename'} ${isCollection ? (t['collection'] ?? 'Collection') : (node is CollectionFolder ? (t['folder'] ?? 'Folder') : (node is CollectionRequestCase ? 'Case' : (t['request'] ?? 'Request')))}',
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
                        if (controller.text.trim().isNotEmpty) {
                          if (isCollection) {
                            ref
                                .read(collectionsProvider.notifier)
                                .updateCollection(collection.copyWith(
                                    name: controller.text.trim()));
                          } else {
                            CollectionNode updatedNode;
                            if (node is CollectionFolder) {
                              updatedNode =
                                  node.copyWith(name: controller.text.trim());
                            } else if (node is CollectionRequest) {
                              updatedNode =
                                  node.copyWith(name: controller.text.trim());
                            } else if (node is CollectionRequestCase) {
                              updatedNode = node.copyWith(
                                name: controller.text.trim(),
                                request: node.request
                                    .copyWith(name: controller.text.trim()),
                              );
                            } else {
                              updatedNode = node;
                            }
                            final updatedCollection = _updateNodeInCollection(
                                collection, node.id, updatedNode);
                            ref
                                .read(collectionsProvider.notifier)
                                .updateCollection(updatedCollection);
                          }
                        }
                        Navigator.pop(context);
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
  }

  void _showAddFolderDialog(BuildContext context, CollectionModel collection,
      CollectionFolder? parentFolder) {
    final t = ref.watch(translationsProvider);
    final controller = TextEditingController();
    AppOverlayDialogs.showModalLike(
      context: context,
      barrierLabel: 'New Folder',
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
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
                    Text(t['new_folder'] ?? 'New Folder',
                        style: TextStyle(
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
                        hintText: 'e.g. Auth endpoints',
                        hintStyle: const TextStyle(color: Colors.grey),
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
                        if (controller.text.trim().isNotEmpty) {
                          final newFolder = CollectionFolder(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            name: controller.text.trim(),
                          );

                          if (parentFolder == null) {
                            final updatedCollection = collection.copyWith(
                              children: [...collection.children, newFolder],
                            );
                            ref
                                .read(collectionsProvider.notifier)
                                .updateCollection(updatedCollection);
                            _expandNode(collection.id);
                          } else {
                            final updatedCollection = _addNodeToFolder(
                                collection, parentFolder.id, newFolder);
                            ref
                                .read(collectionsProvider.notifier)
                                .updateCollection(updatedCollection);
                            _expandNode(parentFolder.id);
                          }
                        }
                        Navigator.pop(context);
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
                      child: Text(t['create'] ?? 'Create',
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
  }

  Widget _buildCollectionItem(String name) {
    return _buildTreeNode(
      id: 'env_$name',
      level: 0,
      initiallyExpanded: false,
      title: Text(name, style: const TextStyle(fontSize: 12)),
      children: [],
      onTap: () {},
    );
  }

}
