import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static DatabaseFactory? _dbFactory;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('post_lens.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (_dbFactory == null) {
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        sqfliteFfiInit();
        _dbFactory = databaseFactoryFfi;
      } else {
        _dbFactory = databaseFactory;
      }
    }

    String dbPath;
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final docDir = await getApplicationSupportDirectory();
      dbPath = docDir.path;
      final dir = Directory(dbPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } else {
      dbPath = await _dbFactory!.getDatabasesPath();
    }

    final path = join(dbPath, filePath);

    return await _dbFactory!.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
      ),
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Workspaces
    await db.execute('''
      CREATE TABLE workspaces (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT
      )
    ''');

    // Collections
    await db.execute('''
      CREATE TABLE collections (
        id TEXT PRIMARY KEY,
        workspaceId TEXT NOT NULL,
        name TEXT NOT NULL,
        data TEXT NOT NULL
      )
    ''');

    // History
    await db.execute('''
      CREATE TABLE history (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        data TEXT NOT NULL
      )
    ''');

    // Key-Value store for settings and active workspace
    await db.execute('''
      CREATE TABLE key_value (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // Workspaces
  Future<void> insertWorkspace(Map<String, dynamic> workspace) async {
    final db = await instance.database;
    await db.insert('workspaces', workspace,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getWorkspaces() async {
    final db = await instance.database;
    return await db.query('workspaces');
  }

  Future<void> updateWorkspace(Map<String, dynamic> workspace) async {
    final db = await instance.database;
    await db.update('workspaces', workspace,
        where: 'id = ?', whereArgs: [workspace['id']]);
  }

  Future<void> deleteWorkspace(String id) async {
    final db = await instance.database;
    await db.delete('workspaces', where: 'id = ?', whereArgs: [id]);
  }

  // Collections
  Future<void> insertCollection(
      String id, String workspaceId, String name, String data) async {
    final db = await instance.database;
    await db.insert('collections',
        {'id': id, 'workspaceId': workspaceId, 'name': name, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getCollections() async {
    final db = await instance.database;
    return await db.query('collections');
  }

  Future<void> updateCollection(
      String id, String workspaceId, String name, String data) async {
    final db = await instance.database;
    await db.update(
        'collections', {'workspaceId': workspaceId, 'name': name, 'data': data},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCollection(String id) async {
    final db = await instance.database;
    await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }

  // History
  Future<void> insertHistory(String id, int timestamp, String data) async {
    final db = await instance.database;
    await db.insert('history', {'id': id, 'timestamp': timestamp, 'data': data},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await instance.database;
    return await db.query('history', orderBy: 'timestamp DESC');
  }

  Future<void> clearHistory() async {
    final db = await instance.database;
    await db.delete('history');
  }

  // Key-Value Store
  Future<void> setKeyValue(String key, String value) async {
    final db = await instance.database;
    await db.insert('key_value', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getKeyValue(String key) async {
    final db = await instance.database;
    final result =
        await db.query('key_value', where: 'key = ?', whereArgs: [key]);
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }
}
