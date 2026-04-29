import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../domain/models/collection_model.dart';
import '../domain/models/http_request_model.dart';

class ImportHelper {
  static int _idCounter = 0;

  static String generateId([String suffix = '']) {
    _idCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idCounter${suffix.isNotEmpty ? "_$suffix" : ""}';
  }

  static CollectionModel? parsePostLensCollection(
      String jsonStr, String workspaceId) {
    final data = jsonDecode(jsonStr);
    if (data is! Map<String, dynamic>) return null;
    if (data['info'] == null || data['item'] == null) return null;

    final info = data['info'];
    final collectionName = (info is Map ? info['name'] : null) ??
        'Imported PostLens Collection';

    final items = data['item'];
    if (items is! List) {
      throw const FormatException('Invalid PostLens collection: item must be a list');
    }

    final children = _parsePostLensItems(items);
    return CollectionModel(
      id: generateId(),
      workspaceId: workspaceId,
      name: collectionName.toString(),
      children: children,
    );
  }

  static List<CollectionNode> _parsePostLensItems(List items) {
    List<CollectionNode> nodes = [];
    for (var item in items) {
      if (item['item'] != null) {
        // Folder
        nodes.add(CollectionFolder(
          id: generateId('folder'),
          name: item['name'] ?? 'Folder',
          children: _parsePostLensItems(item['item'] as List),
        ));
      } else if (item['request'] != null) {
        // Request
        final req = item['request'];
        String url = '';
        if (req['url'] is String) {
          url = req['url'];
        } else if (req['url'] is Map && req['url']['raw'] != null) {
          url = req['url']['raw'];
        }

        String method = req['method'] ?? 'GET';

        // Parse headers
        List<Map<String, String>> headers = [];
        if (req['header'] != null && req['header'] is List) {
          for (var h in req['header']) {
            headers.add({'key': h['key'] ?? '', 'value': h['value'] ?? ''});
          }
        }

        // Parse query params
        List<Map<String, String>> params = [];
        if (req['url'] is Map &&
            req['url']['query'] != null &&
            req['url']['query'] is List) {
          for (var q in req['url']['query']) {
            params.add({'key': q['key'] ?? '', 'value': q['value'] ?? ''});
          }
        }

        // Parse body
        String body = '';
        if (req['body'] != null && req['body']['raw'] != null) {
          body = req['body']['raw'];
        }

        final reqId = generateId('reqNode');
        nodes.add(CollectionRequest(
          id: reqId,
          name: item['name'] ?? 'Request',
          request: HttpRequestModel(
            id: reqId,
            name: item['name'] ?? 'Request',
            method: method,
            protocol: 'http',
            url: url,
            headers: headers,
            params: params,
            body: body,
          ),
        ));
      }
    }
    return nodes;
  }

  static dynamic _resolveRef(String ref, Map<String, dynamic> rootData) {
    if (ref.startsWith('#/')) {
      final parts = ref.split('/').skip(1).toList(); // remove '#'
      dynamic current = rootData;
      for (var part in parts) {
        if (current is Map && current.containsKey(part)) {
          current = current[part];
        } else {
          return null;
        }
      }
      return current;
    }
    return null;
  }

  static dynamic _generateSampleFromSchema(
      Map<String, dynamic> schema, Map<String, dynamic> rootData,
      {int depth = 0}) {
    if (depth > 10) return null; // Prevent infinite loops
    if (schema.containsKey('\$ref')) {
      final resolved = _resolveRef(schema['\$ref'], rootData);
      if (resolved is Map<String, dynamic>) {
        return _generateSampleFromSchema(resolved, rootData, depth: depth + 1);
      }
      return null;
    }

    if (schema['example'] != null) return schema['example'];
    if (schema['default'] != null) return schema['default'];

    final type = schema['type'];
    if (type == 'object' || schema.containsKey('properties')) {
      final properties = schema['properties'] as Map<String, dynamic>? ?? {};
      final map = <String, dynamic>{};
      properties.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          map[key] =
              _generateSampleFromSchema(value, rootData, depth: depth + 1) ??
                  '';
        } else {
          map[key] = '';
        }
      });
      return map;
    } else if (type == 'array' || schema.containsKey('items')) {
      final items = schema['items'];
      if (items is Map<String, dynamic>) {
        final sample =
            _generateSampleFromSchema(items, rootData, depth: depth + 1);
        return sample != null ? [sample] : [];
      }
      return [];
    } else if (type == 'string') {
      return '';
    } else if (type == 'integer' || type == 'number') {
      return 0;
    } else if (type == 'boolean') {
      return false;
    }
    return '';
  }

  static CollectionModel? parseSwagger(String jsonStr, String workspaceId) {
    final data = jsonDecode(jsonStr);
    if (data is! Map<String, dynamic>) return null;
    if (data['openapi'] == null && data['swagger'] == null) return null;

    final info = data['info'];
    final collectionName =
        (info is Map ? info['title'] : null) ?? 'Imported Swagger/OpenAPI';

    final paths = data['paths'];
    if (paths is! Map || paths.isEmpty) {
      throw const FormatException('No endpoints found: paths is empty');
    }

    List<CollectionNode> children = [];
    Map<String, List<CollectionNode>> folderMap = {};

    String baseUrl = '';
    final servers = data['servers'];
    if (servers is List && servers.isNotEmpty) {
      final s0 = servers.first;
      if (s0 is Map) baseUrl = (s0['url'] ?? '').toString();
    } else if (data['host'] != null) {
      final schemes = data['schemes'];
      final scheme =
          (schemes is List && schemes.isNotEmpty) ? schemes.first : 'http';
      baseUrl = '$scheme://${data['host']}${data['basePath'] ?? ''}';
    }

    paths.forEach((path, methods) {
      if (methods is! Map) return;

      List<Map<String, dynamic>> pathParamsList = [];
      final pathParams = methods['parameters'];
      if (pathParams is List) {
        for (final p in pathParams) {
          if (p is Map<String, dynamic>) pathParamsList.add(p);
        }
      }

      methods.forEach((method, details) {
        if (details is! Map) return;
        if (![
          'get',
          'post',
          'put',
          'delete',
          'patch',
          'options',
          'head'
        ].contains(method.toString().toLowerCase())) {
          return;
        }

        final reqName = details['summary'] ?? '$method $path';

        List<Map<String, String>> params = [];
        List<Map<String, String>> headers = [];
        String body = '';
        String bodyType = 'none';
        String rawBodyType = 'JSON';

        List<Map<String, dynamic>> allParams = List.from(pathParamsList);
        final methodParams = details['parameters'];
        if (methodParams is List) {
          for (final p in methodParams) {
            if (p is Map<String, dynamic>) allParams.add(p);
          }
        }

        for (final p in allParams) {
          Map<String, dynamic> param = p;
          if (param.containsKey('\$ref')) {
            final resolved = _resolveRef(param['\$ref'], data);
            if (resolved is Map<String, dynamic>) param = resolved;
          }

          final name = param['name']?.toString() ?? '';
          final inLocation = param['in']?.toString() ?? '';
          if (name.isEmpty) continue;

          if (inLocation == 'query') {
            params.add({'key': name, 'value': '', 'enabled': 'true'});
          } else if (inLocation == 'header') {
            headers.add({'key': name, 'value': '', 'enabled': 'true'});
          } else if (inLocation == 'body') {
            bodyType = 'raw';
            rawBodyType = 'JSON';
            headers.add({
              'key': 'Content-Type',
              'value': 'application/json',
              'enabled': 'true'
            });
            final schema = param['schema'];
            if (schema is Map<String, dynamic>) {
              final sample = _generateSampleFromSchema(schema, data);
              if (sample != null) {
                body = const JsonEncoder.withIndent('  ').convert(sample);
              }
            }
          }
        }

        if (details['requestBody'] != null) {
          Map<String, dynamic> reqBody = (details['requestBody'] is Map<String, dynamic>)
              ? details['requestBody'] as Map<String, dynamic>
              : {};
          if (reqBody.containsKey('\$ref')) {
            final resolved = _resolveRef(reqBody['\$ref'], data);
            if (resolved is Map<String, dynamic>) reqBody = resolved;
          }

          if (reqBody['content'] is Map) {
            final content = reqBody['content'] as Map;
            if (content.containsKey('application/json')) {
              bodyType = 'raw';
              rawBodyType = 'JSON';
              headers.add({
                'key': 'Content-Type',
                'value': 'application/json',
                'enabled': 'true'
              });

              final schema = (content['application/json'] is Map)
                  ? (content['application/json'] as Map)['schema']
                  : null;
              if (schema is Map<String, dynamic>) {
                final sample = _generateSampleFromSchema(schema, data);
                if (sample != null) {
                  body =
                      const JsonEncoder.withIndent('  ').convert(sample);
                }
              }
            } else if (content.containsKey('application/x-www-form-urlencoded')) {
              bodyType = 'urlencoded';
              headers.add({
                'key': 'Content-Type',
                'value': 'application/x-www-form-urlencoded',
                'enabled': 'true'
              });
            } else if (content.containsKey('multipart/form-data')) {
              bodyType = 'formdata';
              headers.add({
                'key': 'Content-Type',
                'value': 'multipart/form-data',
                'enabled': 'true'
              });
            }
          }
        }

        final hasContentType =
            headers.any((h) => h['key']?.toLowerCase() == 'content-type');
        if (bodyType == 'raw' && rawBodyType == 'JSON' && !hasContentType) {
          headers.add({
            'key': 'Content-Type',
            'value': 'application/json',
            'enabled': 'true'
          });
        }

        final reqId = generateId('reqNode');
        final requestNode = CollectionRequest(
          id: reqId,
          name: reqName.toString(),
          request: HttpRequestModel(
            id: reqId,
            name: reqName.toString(),
            method: method.toString().toUpperCase(),
            protocol: 'http',
            url: baseUrl + path.toString(),
            params: params,
            headers: headers.isEmpty
                ? [
                    {
                      'key': 'Cache-Control',
                      'value': 'no-cache',
                      'enabled': 'true'
                    },
                    {'key': 'Accept', 'value': '*/*', 'enabled': 'true'},
                    {
                      'key': 'Connection',
                      'value': 'keep-alive',
                      'enabled': 'true'
                    },
                  ]
                : headers,
            bodyType: bodyType,
            rawBodyType: rawBodyType,
            body: body,
          ),
        );

        final tags = details['tags'];
        if (tags is List && tags.isNotEmpty) {
          final tag = tags.first.toString();
          folderMap.putIfAbsent(tag, () => []).add(requestNode);
        } else {
          children.add(requestNode);
        }
      });
    });

    folderMap.forEach((tagName, requests) {
      children.insert(
        0,
        CollectionFolder(
          id: generateId('folder'),
          name: tagName,
          children: requests,
        ),
      );
    });

    if (children.isEmpty) {
      throw const FormatException('No endpoints found: parsed requests is empty');
    }

    return CollectionModel(
      id: generateId('coll'),
      workspaceId: workspaceId,
      name: collectionName.toString(),
      children: children,
    );
  }
}
