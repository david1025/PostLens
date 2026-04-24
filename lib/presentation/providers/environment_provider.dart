import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database_helper.dart';
import '../../domain/models/environment_model.dart';
import 'workspace_provider.dart';

class EnvironmentsNotifier extends StateNotifier<List<EnvironmentModel>> {
  static const String _storageKey = 'environments';

  EnvironmentsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final raw = await DatabaseHelper.instance.getKeyValue(_storageKey);
    if (raw == null || raw.isEmpty) {
      state = [];
      return;
    }

    try {
      final List<dynamic> jsonList = jsonDecode(raw) as List<dynamic>;
      state = jsonList
          .map((e) => EnvironmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      
      state = [];
    }
  }

  Future<void> addEnvironment(EnvironmentModel env) async {
    state = [...state, env];
    await _persist();
  }

  Future<void> updateEnvironment(EnvironmentModel updatedEnv) async {
    state = [
      for (final env in state)
        if (env.id == updatedEnv.id) updatedEnv else env
    ];
    await _persist();
  }

  Future<void> deleteEnvironment(String id) async {
    state = state.where((env) => env.id != id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    final jsonList = state.map((env) => env.toJson()).toList();
    await DatabaseHelper.instance
        .setKeyValue(_storageKey, jsonEncode(jsonList));
  }
}

final environmentsProvider =
    StateNotifierProvider<EnvironmentsNotifier, List<EnvironmentModel>>((ref) {
  return EnvironmentsNotifier();
});

final activeEnvironmentIdProvider = StateProvider<String?>((ref) => null);

final activeWorkspaceEnvironmentsProvider =
    Provider<List<EnvironmentModel>>((ref) {
  final environments = ref.watch(environmentsProvider);
  final activeWorkspace = ref.watch(activeWorkspaceProvider);
  return environments
      .where((e) => e.workspaceId == activeWorkspace.id)
      .toList();
});
