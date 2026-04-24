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
    try {
      final data = jsonDecode(jsonStr);
      if (data['info'] != null && data['item'] != null) {
        final collectionName =
            data['info']['name'] ?? 'Imported PostLens Collection';
        final items = data['item'] as List;

        final children = _parsePostLensItems(items);

        return CollectionModel(
          id: generateId(),
          workspaceId: workspaceId,
          name: collectionName,
          children: children,
        );
      }
    } catch (e) {
      
    }
    return null;
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

        nodes.add(CollectionRequest(
          id: generateId('reqNode'),
          name: item['name'] ?? 'Request',
          request: HttpRequestModel(
            id: generateId('req'),
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
    try {
      final data = jsonDecode(jsonStr);
      if (data['openapi'] != null || data['swagger'] != null) {
        final info = data['info'] ?? {};
        final collectionName = info['title'] ?? 'Imported Swagger/OpenAPI';
        final paths = data['paths'] ?? {};

        List<CollectionNode> children = [];
        Map<String, List<CollectionNode>> folderMap = {};

        String baseUrl = '';
        if (data['servers'] != null && (data['servers'] as List).isNotEmpty) {
          baseUrl = data['servers'][0]['url'] ?? '';
        } else if (data['host'] != null) {
          final scheme =
              (data['schemes'] != null && (data['schemes'] as List).isNotEmpty)
                  ? data['schemes'][0]
                  : 'http';
          baseUrl = '$scheme://${data['host']}${data['basePath'] ?? ''}';
        }

        paths.forEach((path, methods) {
          if (methods is Map) {
            // Collect path-level parameters
            List<Map<String, dynamic>> pathParamsList = [];
            if (methods['parameters'] is List) {
              for (var p in methods['parameters']) {
                if (p is Map<String, dynamic>) pathParamsList.add(p);
              }
            }

            methods.forEach((method, details) {
              if (['get', 'post', 'put', 'delete', 'patch', 'options', 'head']
                  .contains(method.toLowerCase())) {
                final reqName = details['summary'] ?? '$method $path';

                List<Map<String, String>> params = [];
                List<Map<String, String>> headers = [];
                String body = '';
                String bodyType = 'none';
                String rawBodyType = 'JSON';

                // Merge path-level and method-level parameters
                List<Map<String, dynamic>> allParams =
                    List.from(pathParamsList);
                if (details['parameters'] is List) {
                  for (var p in details['parameters']) {
                    if (p is Map<String, dynamic>) allParams.add(p);
                  }
                }

                for (var p in allParams) {
                  // Resolve ref if it's a parameter ref
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
                    // Swagger 2.0 body parameter
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
                        body =
                            const JsonEncoder.withIndent('  ').convert(sample);
                      }
                    }
                  }
                }

                // OpenAPI 3.0 requestBody
                if (details['requestBody'] != null) {
                  Map<String, dynamic> reqBody = details['requestBody'];
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

                      final schema = content['application/json']['schema'];
                      if (schema is Map<String, dynamic>) {
                        final sample = _generateSampleFromSchema(schema, data);
                        if (sample != null) {
                          body = const JsonEncoder.withIndent('  ')
                              .convert(sample);
                        }
                      }
                    } else if (content
                        .containsKey('application/x-www-form-urlencoded')) {
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

                // If no Content-Type was set but bodyType is raw/JSON, ensure it
                bool hasContentType = headers
                    .any((h) => h['key']?.toLowerCase() == 'content-type');
                if (bodyType == 'raw' &&
                    rawBodyType == 'JSON' &&
                    !hasContentType) {
                  headers.add({
                    'key': 'Content-Type',
                    'value': 'application/json',
                    'enabled': 'true'
                  });
                }

                final requestNode = CollectionRequest(
                  id: generateId('reqNode'),
                  name: reqName,
                  request: HttpRequestModel(
                    id: generateId('req'),
                    name: reqName,
                    method: method.toUpperCase(),
                    protocol: 'http',
                    url: baseUrl + path,
                    params: params,
                    headers: headers.isEmpty
                        ? [
                            {
                              'key': 'Cache-Control',
                              'value': 'no-cache',
                              'enabled': 'true'
                            },
                            {
                              'key': 'Accept',
                              'value': '*/*',
                              'enabled': 'true'
                            },
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

                List tags = details['tags'] ?? [];
                if (tags.isNotEmpty) {
                  String tag = tags.first.toString();
                  folderMap.putIfAbsent(tag, () => []).add(requestNode);
                } else {
                  children.add(requestNode);
                }
              }
            });
          }
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

        return CollectionModel(
          id: generateId('coll'),
          workspaceId: workspaceId,
          name: collectionName,
          children: children,
        );
      }
    } catch (e) {
      
    }
    return null;
  }
}
