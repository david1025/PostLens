import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/collection_model.dart';
import '../../data/local/database_helper.dart';
import 'workspace_provider.dart';

class CollectionNotifier extends StateNotifier<List<CollectionModel>> {
  CollectionNotifier() : super([]) {
    _loadCollections();
  }

  List<CollectionNode> _updateFolderInNodes(
    List<CollectionNode> nodes,
    String folderId,
    CollectionFolder Function(CollectionFolder folder) update,
  ) {
    return nodes.map((node) {
      if (node is CollectionFolder) {
        if (node.id == folderId) {
          return update(node);
        }
        return node.copyWith(
          children: _updateFolderInNodes(node.children, folderId, update),
        );
      }
      return node;
    }).toList();
  }

  Future<void> _loadCollections() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final data = await dbHelper.getCollections();
      if (data.isNotEmpty) {
        final loaded = data
            .map((e) =>
                CollectionModel.fromJson(jsonDecode(e['data'] as String)))
            .toList();
        final loadedIds = loaded.map((c) => c.id).toSet();
        state = [...loaded, ...state.where((c) => !loadedIds.contains(c.id))];
      }
    } catch (e) {
      
    }
  }

  Future<void> addCollection(CollectionModel collection) async {
    try {
      await DatabaseHelper.instance.insertCollection(
          collection.id,
          collection.workspaceId,
          collection.name,
          jsonEncode(collection.toJson()));
      state = [...state, collection];
    } catch (e, st) {
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> updateCollection(CollectionModel collection) async {
    try {
      await DatabaseHelper.instance.updateCollection(
          collection.id,
          collection.workspaceId,
          collection.name,
          jsonEncode(collection.toJson()));
      state = [
        for (final c in state)
          if (c.id == collection.id) collection else c
      ];
    } catch (e, st) {
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> updateCollectionDescription(
      String collectionId, String description) async {
    final collection = state.firstWhere((c) => c.id == collectionId);
    await updateCollection(collection.copyWith(description: description));
  }

  Future<void> updateFolderDescription(
    String collectionId,
    String folderId,
    String description,
  ) async {
    final collection = state.firstWhere((c) => c.id == collectionId);
    final updatedChildren = _updateFolderInNodes(
      collection.children,
      folderId,
      (folder) => folder.copyWith(description: description),
    );
    await updateCollection(collection.copyWith(children: updatedChildren));
  }

  Future<void> deleteCollection(String id) async {
    try {
      await DatabaseHelper.instance.deleteCollection(id);
      state = state.where((c) => c.id != id).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> setCollections(List<CollectionModel> collections) async {
    for (var collection in collections) {
      // In a real app we might need to check if it exists or clear existing, but for demo we can just insert/replace
      try {
        await DatabaseHelper.instance.insertCollection(
            collection.id,
            collection.workspaceId,
            collection.name,
            jsonEncode(collection.toJson()));
      } catch (_) {
        await DatabaseHelper.instance.updateCollection(
          collection.id,
          collection.workspaceId,
          collection.name,
          jsonEncode(collection.toJson()),
        );
      }
    }
    state = collections;
  }
}

final collectionsProvider =
    StateNotifierProvider<CollectionNotifier, List<CollectionModel>>((ref) {
  return CollectionNotifier();
});

final activeWorkspaceCollectionsProvider =
    Provider<List<CollectionModel>>((ref) {
  final activeWorkspace = ref.watch(activeWorkspaceProvider);
  final collections = ref.watch(collectionsProvider);
  return collections.where((c) => c.workspaceId == activeWorkspace.id).toList();
});
