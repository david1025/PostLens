import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/models/collection_model.dart';
import '../../domain/models/http_request_model.dart';
import '../providers/collection_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/settings_provider.dart';

class SaveRequestDialog extends ConsumerStatefulWidget {
  final HttpRequestModel request;

  const SaveRequestDialog({super.key, required this.request});

  @override
  ConsumerState<SaveRequestDialog> createState() => _SaveRequestDialogState();
}

class _SaveRequestDialogState extends ConsumerState<SaveRequestDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final TextEditingController _searchController = TextEditingController();
  bool _showDescription = false;

  // The path represents the current navigation state.
  // Empty list means we are at the root (showing collections).
  // First element is CollectionModel, subsequent elements are CollectionFolder.
  List<dynamic> _currentPath = [];

  bool _isCreatingNewNode = false;
  final FocusNode _newNodeFocusNode = FocusNode();
  final TextEditingController _newNodeNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.request.name.isEmpty
          ? 'Untitled Request'
          : widget.request.name,
    );
    _descriptionController = TextEditingController(
      text: widget.request.description,
    );
    _showDescription = widget.request.description.isNotEmpty;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _newNodeNameController.dispose();
    _newNodeFocusNode.dispose();
    super.dispose();
  }

  CollectionModel _addNodeToCollection(CollectionModel collection,
      CollectionNode newNode, String? targetFolderId) {
    if (targetFolderId == null) {
      return collection.copyWith(
        children: [...collection.children, newNode],
      );
    }

    List<CollectionNode> updateChildren(List<CollectionNode> children) {
      return children.map((child) {
        if (child is CollectionFolder) {
          if (child.id == targetFolderId) {
            return child.copyWith(children: [...child.children, newNode]);
          } else {
            return child.copyWith(children: updateChildren(child.children));
          }
        }
        return child;
      }).toList();
    }

    return collection.copyWith(children: updateChildren(collection.children));
  }

  void _handleSave() {
    if (_currentPath.isEmpty) return;

    final collections = ref.read(collectionsProvider);
    final selectedCollectionId = (_currentPath.first as CollectionModel).id;
    final selectedFolderId = _currentPath.length > 1
        ? (_currentPath.last as CollectionFolder).id
        : null;

    final targetCollection =
        collections.firstWhere((c) => c.id == selectedCollectionId);

    final newNodeId = DateTime.now().millisecondsSinceEpoch.toString();
    final savedRequest = widget.request.copyWith(
      id: newNodeId,
      name: _nameController.text.trim().isEmpty
          ? 'Untitled Request'
          : _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      collectionId: selectedCollectionId,
      folderId: selectedFolderId,
    );

    final newNode = CollectionRequest(
      id: newNodeId,
      name: savedRequest.name,
      request: savedRequest,
    );

    final updatedCollection =
        _addNodeToCollection(targetCollection, newNode, selectedFolderId);
    ref.read(collectionsProvider.notifier).updateCollection(updatedCollection);

    Navigator.of(context).pop(savedRequest);
  }

  void _handleCreateNewNode() {
    final name = _newNodeNameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _isCreatingNewNode = false;
      });
      return;
    }

    final collections = ref.read(collectionsProvider);
    final activeWorkspace = ref.read(activeWorkspaceProvider);

    if (_currentPath.isEmpty) {
      // Create new collection
      final newCollection = CollectionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        workspaceId: activeWorkspace.id,
        name: name,
      );
      ref.read(collectionsProvider.notifier).addCollection(newCollection);
    } else {
      // Create new folder inside the current path
      final selectedCollectionId = (_currentPath.first as CollectionModel).id;
      final targetCollection =
          collections.firstWhere((c) => c.id == selectedCollectionId);
      final selectedFolderId = _currentPath.length > 1
          ? (_currentPath.last as CollectionFolder).id
          : null;

      final newFolder = CollectionFolder(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
      );

      final updatedCollection =
          _addNodeToCollection(targetCollection, newFolder, selectedFolderId);
      ref
          .read(collectionsProvider.notifier)
          .updateCollection(updatedCollection);

      // Update current path reference so we stay in the same directory but see the updated collection
      setState(() {
        _currentPath[0] = updatedCollection;
        if (_currentPath.length > 1) {
          // Need to recursively find the updated folder
          CollectionFolder? findFolder(List<CollectionNode> nodes, String id) {
            for (final node in nodes) {
              if (node is CollectionFolder) {
                if (node.id == id) return node;
                final found = findFolder(node.children, id);
                if (found != null) return found;
              }
            }
            return null;
          }

          for (int i = 1; i < _currentPath.length; i++) {
            final folderId = (_currentPath[i] as CollectionFolder).id;
            final updatedFolder =
                findFolder(updatedCollection.children, folderId);
            if (updatedFolder != null) {
              _currentPath[i] = updatedFolder;
            }
          }
        }
      });
    }

    setState(() {
      _isCreatingNewNode = false;
      _newNodeNameController.clear();
    });
  }

  Widget _buildBreadcrumb(String activeWorkspaceName) {
    final t = ref.watch(translationsProvider);
    List<Widget> children = [];

    // Add workspace icon / name (acts as 'home' to go to collections root)
    children.add(
      InkWell(
        onTap: () {
          setState(() {
            _currentPath = [];
          });
        },
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.cube, size: 12, color: Colors.grey),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );

    for (int i = 0; i < _currentPath.length; i++) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0),
          child: Text('/', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      );

      final isLast = i == _currentPath.length - 1;
      final nodeName = _currentPath[i].name;

      children.add(
        InkWell(
          onTap: () {
            setState(() {
              _currentPath = _currentPath.sublist(0, i + 1);
            });
          },
          child: Text(
            nodeName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
              color: isLast
                  ? Theme.of(context).textTheme.bodyMedium!.color
                  : Colors.grey,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(t['save_to'] ?? 'Save to ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<CollectionModel> allCollections) {
    List<dynamic> items = [];
    if (_currentPath.isEmpty) {
      items = allCollections;
    } else {
      final currentNode = _currentPath.last;
      if (currentNode is CollectionModel) {
        items = currentNode.children;
      } else if (currentNode is CollectionFolder) {
        items = currentNode.children;
      }
    }

    // Apply search filter if needed
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items
          .where((item) => item.name.toLowerCase().contains(query))
          .toList();
    } else {
      items = List.from(items);
    }

    // Sort folders first, then requests
    if (_currentPath.isNotEmpty) {
      items.sort((a, b) {
        if (a is CollectionFolder && b is CollectionRequest) return -1;
        if (a is CollectionRequest && b is CollectionFolder) return 1;
        return 0;
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length + (_isCreatingNewNode ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          // New Node Input Row
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Row(
              children: [
                _currentPath.isEmpty
                      ? const FaIcon(FontAwesomeIcons.cube,
                          size: 16, color: Colors.grey)
                      : SvgPicture.asset(
                          'assets/icons/folder.svg',
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(
                              Colors.grey, BlendMode.srcIn),
                        ),
                  const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: TextField(
                      controller: _newNodeNameController,
                      focusNode: _newNodeFocusNode,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        border: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: Theme.of(context).dividerColor)),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color:
                                    Theme.of(context).colorScheme.secondary)),
                      ),
                      style: const TextStyle(fontSize: 12),
                      onSubmitted: (_) => _handleCreateNewNode(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check, size: 16, color: Colors.green),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _handleCreateNewNode,
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _isCreatingNewNode = false;
                      _newNodeNameController.clear();
                    });
                  },
                ),
              ],
            ),
          );
        }

        final item = items[index];
        if (_currentPath.isEmpty) {
          // Root level - Collections
          return InkWell(
            onTap: () {
              setState(() {
                _currentPath.add(item);
                _searchController.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.cube,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Inside a collection/folder
          if (item is CollectionFolder) {
            return InkWell(
              onTap: () {
                setState(() {
                  _currentPath.add(item);
                  _searchController.clear();
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      'assets/icons/folder.svg',
                      width: 16,
                      height: 16,
                      colorFilter: const ColorFilter.mode(
                          Colors.grey, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.name,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (item is CollectionRequest) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Text(
                    item.request.method,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color:
                          _getMethodColor(item.request.method).withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.withOpacity(0.5)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }
        }
        return const SizedBox();
      },
    );
  }

  Color _getMethodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.green;
      case 'POST':
        return Colors.amber;
      case 'PUT':
        return Colors.blue;
      case 'DELETE':
        return Colors.red;
      case 'PATCH':
        return Colors.purple;
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
    final collections = ref.watch(activeWorkspaceCollectionsProvider);
    final activeWorkspace = ref.watch(activeWorkspaceProvider);

    return Dialog(
      child: Container(
        width: 600,
        height: 600,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t['save_request'] ?? 'SAVE REQUEST',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
            const SizedBox(height: 16),

            Text(t['request_name'] ?? 'Request name',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            SizedBox(
              height: 28,
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.secondary),
                  ),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),

            if (!_showDescription)
              InkWell(
                onTap: () {
                  setState(() {
                    _showDescription = true;
                  });
                },
                child: Text(t['add_description'] ?? 'Add description',
                  style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      color: Colors.grey),
                ),
              )
            else ...[
              Text(t['description'] ?? 'Description',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey)),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: TextField(
                  controller: _descriptionController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide:
                          BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),

            _buildBreadcrumb(activeWorkspace.name),
            const SizedBox(height: 12),

            // Search and Tree container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    // Search box
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                color: Theme.of(context).dividerColor)),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          const FaIcon(FontAwesomeIcons.list,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search for collection or folder',
                                hintStyle:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                              ),
                              style: const TextStyle(fontSize: 12),
                              onChanged: (val) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tree view
                    Expanded(
                      child: _buildList(collections),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isCreatingNewNode = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _newNodeFocusNode.requestFocus();
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                  ),
                  child: Text(
                      _currentPath.isEmpty ? 'New collection' : 'New folder',
                      style: const TextStyle(fontSize: 12)),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).textTheme.bodyMedium!.color,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        minimumSize: const Size(0, 28),
                      ),
                      child: Text(t['cancel'] ?? 'Cancel',
                          style: const TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _currentPath.isEmpty ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFFF6C37), // PostLens orange
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                        minimumSize: const Size(0, 28),
                      ),
                      child: Text(t['save'] ?? 'Save',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.normal)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
