import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import '../../domain/models/collection_model.dart';
import '../../domain/models/http_request_model.dart';
import '../../utils/import_helper.dart';

class ExportData {
  final List<CollectionModel> collections;
  final List<HttpRequestModel> history;

  ExportData({
    required this.collections,
    required this.history,
  });

  Map<String, dynamic> toJson() {
    return {
      'collections': collections.map((e) => e.toJson()).toList(),
      'history': history.map((e) => e.toJson()).toList(),
    };
  }

  factory ExportData.fromJson(Map<String, dynamic> json) {
    return ExportData(
      collections: (json['collections'] as List?)
              ?.map((e) => CollectionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      history: (json['history'] as List?)
              ?.map((e) => HttpRequestModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ImportExportService {
  static Future<void> exportToJson(String filePath, ExportData data) async {
    final file = File(filePath);
    final jsonString = jsonEncode(data.toJson());
    await file.writeAsString(jsonString);
  }

  static Future<ExportData> importFromJson(String filePath) async {
    final file = File(filePath);
    final jsonString = await file.readAsString();
    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    return ExportData.fromJson(jsonMap);
  }

  static Future<void> exportToCsv(String filePath, ExportData data) async {
    List<List<dynamic>> rows = [];
    // CSV Header
    rows.add([
      'ID',
      'Name',
      'Method',
      'URL',
      'Protocol',
      'BodyType',
      'Body',
      'AuthType'
    ]);

    for (var req in data.history) {
      rows.add([
        req.id,
        req.name,
        req.method,
        req.url,
        req.protocol,
        req.bodyType,
        req.body,
        req.authType,
      ]);
    }

    final String csvStr = Csv().encode(rows);
    final file = File(filePath);
    await file.writeAsString(csvStr);
  }

  static Future<ExportData> importFromCsv(String filePath) async {
    final file = File(filePath);
    final csvString = await file.readAsString();
    final List<List<dynamic>> rows = Csv().decode(csvString);

    if (rows.isEmpty) {
      return ExportData(collections: [], history: []);
    }

    final headers = rows.first.map((e) => e.toString().toLowerCase()).toList();
    List<HttpRequestModel> history = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      final map = <String, dynamic>{};
      for (int j = 0; j < headers.length; j++) {
        if (j < row.length) {
          map[headers[j]] = row[j];
        }
      }

      history.add(HttpRequestModel(
        id: map['id']?.toString() ?? ImportHelper.generateId('history'),
        name: map['name']?.toString() ?? 'Imported Request',
        method: map['method']?.toString() ?? 'GET',
        url: map['url']?.toString() ?? '',
        protocol: map['protocol']?.toString() ?? 'http',
        bodyType: map['bodytype']?.toString() ?? 'none',
        body: map['body']?.toString() ?? '',
        authType: map['authtype']?.toString() ?? 'No Auth',
      ));
    }

    return ExportData(collections: [], history: history);
  }
}
