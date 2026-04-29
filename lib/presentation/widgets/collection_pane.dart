import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/collection_model.dart';
import '../providers/collection_provider.dart';
import '../providers/settings_provider.dart';
import 'doc_editor.dart';

class CollectionPane extends ConsumerStatefulWidget {
  final String collectionId;
  final bool isFolder;

  const CollectionPane(
      {super.key, required this.collectionId, this.isFolder = false});

  @override
  ConsumerState<CollectionPane> createState() => _CollectionPaneState();
}

class _CollectionPaneState extends ConsumerState<CollectionPane> {

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final collections = ref.watch(collectionsProvider);
    CollectionModel? collection;
    CollectionFolder? folder;

    if (!widget.isFolder) {
      collection = collections.firstWhere((c) => c.id == widget.collectionId);
    } else {
      // Find the folder
      for (final c in collections) {
        final f = _findFolder(c.children, widget.collectionId);
        if (f != null) {
          collection = c;
          folder = f;
          break;
        }
      }
    }

    if (collection == null && folder == null) {
      return Center(child: Text(t['not_found'] ?? 'Not found'));
    }

    final name = folder?.name ?? collection?.name ?? 'Unknown';
    final children = folder?.children ?? collection?.children ?? [];
    int folderCount = 0;
    int requestCount = 0;
    for (final child in children) {
      if (child is CollectionFolder) folderCount++;
      if (child is CollectionRequest) requestCount++;
    }
    final description = folder?.description ?? collection?.description ?? '';

    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.fromLTRB(12.0, 20.0, 12.0, 12.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['overview'] ?? 'Overview',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This ${widget.isFolder ? "folder" : "collection"} contains $folderCount folders and $requestCount requests.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 24),
                      DocEditor(
                        title: t['doc'] ?? 'Doc',
                        richTextLabel: t['rich_text'] ?? 'Rich Text',
                        markdownLabel: t['markdown'] ?? 'Markdown',
                        editLabel: t['edit'] ?? 'Edit',
                        previewLabel: t['preview'] ?? 'Preview',
                        value: description,
                        onChanged: (v) {
                          if (collection == null) return;
                          if (folder != null) {
                            ref
                                .read(collectionsProvider.notifier)
                                .updateFolderDescription(
                                    collection.id, folder.id, v);
                          } else {
                            ref
                                .read(collectionsProvider.notifier)
                                .updateCollectionDescription(collection.id, v);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  CollectionFolder? _findFolder(List<CollectionNode> nodes, String id) {
    for (final node in nodes) {
      if (node is CollectionFolder) {
        if (node.id == id) return node;
        final f = _findFolder(node.children, id);
        if (f != null) return f;
      }
    }
    return null;
  }
}
