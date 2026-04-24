import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/workspace_model.dart';
import '../../data/local/database_helper.dart';

final defaultWorkspace = WorkspaceModel(
    id: 'default', name: 'My Workspace', description: 'The default workspace');

class WorkspaceNotifier extends StateNotifier<List<WorkspaceModel>> {
  WorkspaceNotifier() : super([defaultWorkspace]) {
    _loadWorkspaces();
  }

  Future<void> _loadWorkspaces() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final data = await dbHelper.getWorkspaces();
      if (data.isNotEmpty) {
        state = data.map((e) => WorkspaceModel.fromJson(e)).toList();
      } else {
        await dbHelper.insertWorkspace(defaultWorkspace.toJson());
      }
    } catch (e) {
      
    }
  }

  Future<void> addWorkspace(WorkspaceModel workspace) async {
    try {
      await DatabaseHelper.instance.insertWorkspace(workspace.toJson());
      state = [...state, workspace];
    } catch (e) {
      
    }
  }

  Future<void> updateWorkspace(WorkspaceModel workspace) async {
    try {
      await DatabaseHelper.instance.updateWorkspace(workspace.toJson());
      state = [
        for (final w in state)
          if (w.id == workspace.id) workspace else w
      ];
    } catch (e) {
      
    }
  }

  Future<void> deleteWorkspace(String id) async {
    try {
      await DatabaseHelper.instance.deleteWorkspace(id);
      state = state.where((w) => w.id != id).toList();
    } catch (e) {
      
    }
  }
}

final workspacesProvider =
    StateNotifierProvider<WorkspaceNotifier, List<WorkspaceModel>>((ref) {
  return WorkspaceNotifier();
});

class ActiveWorkspaceNotifier extends StateNotifier<WorkspaceModel> {
  static const String _storageKey = 'postlens_active_workspace';

  ActiveWorkspaceNotifier() : super(defaultWorkspace) {
    _loadActiveWorkspace();
  }

  Future<void> _loadActiveWorkspace() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final data = await dbHelper.getKeyValue(_storageKey);
      if (data != null) {
        state =
            WorkspaceModel.fromJson(jsonDecode(data) as Map<String, dynamic>);
      }
    } catch (e) {
      
    }
  }

  Future<void> setActiveWorkspace(WorkspaceModel workspace) async {
    try {
      await DatabaseHelper.instance
          .setKeyValue(_storageKey, jsonEncode(workspace.toJson()));
      state = workspace;
    } catch (e) {
      
    }
  }
}

final activeWorkspaceProvider =
    StateNotifierProvider<ActiveWorkspaceNotifier, WorkspaceModel>((ref) {
  return ActiveWorkspaceNotifier();
});
