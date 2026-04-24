import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/collection_model.dart';
import '../../data/local/database_helper.dart';
import 'workspace_provider.dart';

class CollectionNotifier extends StateNotifier<List<CollectionModel>> {
  CollectionNotifier() : super([]) {
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final data = await dbHelper.getCollections();
      if (data.isNotEmpty) {
        state = data
            .map((e) =>
                CollectionModel.fromJson(jsonDecode(e['data'] as String)))
            .toList();
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
    } catch (e) {
      
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
    } catch (e) {
      
    }
  }

  Future<void> deleteCollection(String id) async {
    try {
      await DatabaseHelper.instance.deleteCollection(id);
      state = state.where((c) => c.id != id).toList();
    } catch (e) {
      
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
            jsonEncode(collection.toJson()));
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
