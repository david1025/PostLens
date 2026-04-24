import 'dart:convert';

import '../../data/local/database_helper.dart';

class CollectionVariablesService {
  static final CollectionVariablesService instance =
      CollectionVariablesService._internal();

  CollectionVariablesService._internal();

  String _key(String collectionId) => 'collection_variables_$collectionId';

  Future<Map<String, dynamic>> load(String collectionId) async {
    final raw = await DatabaseHelper.instance.getKeyValue(_key(collectionId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> save(String collectionId, Map<String, dynamic> variables) async {
    await DatabaseHelper.instance
        .setKeyValue(_key(collectionId), jsonEncode(variables));
  }
}

