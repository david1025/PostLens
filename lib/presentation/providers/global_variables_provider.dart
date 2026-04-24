import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/local/database_helper.dart';

class GlobalVariable {
  final String key;
  final String value;
  final bool enabled;

  GlobalVariable({
    required this.key,
    required this.value,
    this.enabled = true,
  });

  GlobalVariable copyWith({
    String? key,
    String? value,
    bool? enabled,
  }) {
    return GlobalVariable(
      key: key ?? this.key,
      value: value ?? this.value,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
        'enabled': enabled,
      };

  factory GlobalVariable.fromJson(Map<String, dynamic> json) => GlobalVariable(
        key: json['key'] ?? '',
        value: json['value'] ?? '',
        enabled: json['enabled'] ?? true,
      );
}

class GlobalVariablesNotifier extends StateNotifier<List<GlobalVariable>> {
  GlobalVariablesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final raw = await DatabaseHelper.instance.getKeyValue('global_variables');
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(raw);
        state = jsonList
            .map((e) => GlobalVariable.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        state = [];
      }
    }
  }

  Future<void> setVariables(List<GlobalVariable> variables) async {
    state = variables;
    final jsonList = variables.map((v) => v.toJson()).toList();
    await DatabaseHelper.instance
        .setKeyValue('global_variables', jsonEncode(jsonList));
  }

  Future<void> addVariable(GlobalVariable variable) async {
    state = [...state, variable];
    await _persist();
  }

  Future<void> updateVariable(int index, GlobalVariable variable) async {
    if (index < 0 || index >= state.length) return;
    state = [...state]..[index] = variable;
    await _persist();
  }

  Future<void> removeVariable(int index) async {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
    await _persist();
  }

  Future<void> _persist() async {
    final jsonList = state.map((v) => v.toJson()).toList();
    await DatabaseHelper.instance
        .setKeyValue('global_variables', jsonEncode(jsonList));
  }
}

final globalVariablesProvider =
    StateNotifierProvider<GlobalVariablesNotifier, List<GlobalVariable>>((ref) {
  return GlobalVariablesNotifier();
});
