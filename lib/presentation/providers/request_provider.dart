import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/http_request_model.dart';
import '../../domain/models/http_response_model.dart';
import '../../data/network/dio_client.dart';
import '../../data/local/database_helper.dart';

final networkClientProvider = Provider((ref) => NetworkClient(ref));

final activeRequestIdProvider = StateProvider<String>((ref) => '1');

class RequestNotifier extends StateNotifier<HttpRequestModel> {
  RequestNotifier(Ref ref)
      : _ref = ref,
        super(HttpRequestModel(
            id: '1', url: 'https://jsonplaceholder.typicode.com/todos/1')) {
    state = _normalizeRequest(state);
    _requestsById[state.id] = state;
    _savedRequestSignatures[state.id] = _requestSignature(state);
    ref.read(requestDirtyProvider(state.id).notifier).state = false;
    ref.read(activeRequestIdProvider.notifier).state = state.id;
  }

  final Ref? _ref;
  final Random _rand = Random();
  final Map<String, HttpRequestModel> _requestsById = {};
  final Map<String, String> _savedRequestSignatures = {};

  String _makeRowId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${_rand.nextInt(1 << 32)}';
  }

  Map<String, String> _ensureRowId(Map<String, String> row) {
    if (row.containsKey('id') && (row['id']?.isNotEmpty ?? false)) return row;
    return {
      ...row,
      'id': _makeRowId(),
    };
  }

  List<Map<String, String>> _ensureRowIds(List<Map<String, String>> rows) {
    return rows.map(_ensureRowId).toList();
  }

  HttpRequestModel _normalizeRequest(HttpRequestModel request) {
    return request.copyWith(
      params: _ensureRowIds(List<Map<String, String>>.from(request.params)),
      headers: _ensureRowIds(List<Map<String, String>>.from(request.headers)),
    );
  }

  String _requestSignature(HttpRequestModel request) {
    return jsonEncode(_normalizeRequest(request).toJson());
  }

  void _updateDirtyState(String requestId) {
    final cachedRequest = _requestsById[requestId];
    final savedSignature = _savedRequestSignatures[requestId];
    final isDirty = cachedRequest != null &&
        savedSignature != null &&
        _requestSignature(cachedRequest) != savedSignature;
    _ref?.read(requestDirtyProvider(requestId).notifier).state = isDirty;
  }

  void _setState(HttpRequestModel nextState) {
    final normalized = _normalizeRequest(nextState);
    state = normalized;
    _requestsById[normalized.id] = normalized;
    _savedRequestSignatures.putIfAbsent(
      normalized.id,
      () => _requestSignature(normalized),
    );
    _updateDirtyState(normalized.id);
    _ref?.read(activeRequestIdProvider.notifier).state = normalized.id;
  }

  void updateMethod(String method) {
    _setState(state.copyWith(method: method));
  }

  void updateProtocol(String protocol) {
    if (state.protocol == protocol) return;

    final settings = Map<String, dynamic>.from(state.settings);
    final currentProtocol = state.protocol;
    settings['protocolState_$currentProtocol'] = {
      'url': state.url,
      'method': state.method,
      'params': state.params,
      'headers': state.headers,
      'bodyType': state.bodyType,
      'rawBodyType': state.rawBodyType,
      'authType': state.authType,
      'basicAuthUsername': state.basicAuthUsername,
      'basicAuthPassword': state.basicAuthPassword,
      'bearerToken': state.bearerToken,
      'apiKeyKey': state.apiKeyKey,
      'apiKeyValue': state.apiKeyValue,
      'apiKeyAddTo': state.apiKeyAddTo,
      'authConfig': state.authConfig,
      'body': state.body,
      'graphqlQuery': state.graphqlQuery,
      'graphqlVariables': state.graphqlVariables,
      'formData': state.formData,
      'urlEncodedData': state.urlEncodedData,
      'binaryFilePath': state.binaryFilePath,
    };

    String newMethod = state.method;
    if (protocol.toLowerCase() == 'http') {
      if (['WS', 'WEBSOCKET', 'MQTT', 'SOCKET', 'SOCKET.IO', 'TCP', 'UDP', 'GRPC'].contains(newMethod.toUpperCase())) {
        newMethod = 'GET';
      }
    } else {
      newMethod = protocol.toUpperCase();
    }

    final savedState = settings['protocolState_$protocol'];
    if (savedState != null) {
      _setState(state.copyWith(
        protocol: protocol,
        method: protocol.toLowerCase() == 'http' ? (savedState['method'] ?? newMethod) : newMethod,
        url: savedState['url'] ?? '',
        params: List<Map<String, String>>.from(
            (savedState['params'] as List?)?.map((e) => Map<String, String>.from(e)) ?? []),
        headers: List<Map<String, String>>.from(
            (savedState['headers'] as List?)?.map((e) => Map<String, String>.from(e)) ?? []),
        bodyType: savedState['bodyType'] ?? 'none',
        rawBodyType: savedState['rawBodyType'] ?? 'JSON',
        authType: savedState['authType'] ?? 'No Auth',
        basicAuthUsername: savedState['basicAuthUsername'] ?? '',
        basicAuthPassword: savedState['basicAuthPassword'] ?? '',
        bearerToken: savedState['bearerToken'] ?? '',
        apiKeyKey: savedState['apiKeyKey'] ?? '',
        apiKeyValue: savedState['apiKeyValue'] ?? '',
        apiKeyAddTo: savedState['apiKeyAddTo'] ?? 'Header',
        authConfig: Map<String, dynamic>.from(savedState['authConfig'] ?? {}),
        body: savedState['body'] ?? '',
        graphqlQuery: savedState['graphqlQuery'] ?? '',
        graphqlVariables: savedState['graphqlVariables'] ?? '',
        formData: List<Map<String, String>>.from(
            (savedState['formData'] as List?)?.map((e) => Map<String, String>.from(e)) ?? []),
        urlEncodedData: List<Map<String, String>>.from(
            (savedState['urlEncodedData'] as List?)?.map((e) => Map<String, String>.from(e)) ?? []),
        binaryFilePath: savedState['binaryFilePath'] ?? '',
        settings: settings,
      ));
    } else {
      _setState(state.copyWith(
        protocol: protocol,
        method: newMethod,
        url: '',
        params: const [],
        headers: const [
          {'key': 'Cache-Control', 'value': 'no-cache', 'enabled': 'true'},
          {'key': 'PostLens-Token', 'value': '<calculated when request is sent>', 'enabled': 'true'},
          {'key': 'Host', 'value': '<calculated when request is sent>', 'enabled': 'true'},
          {'key': 'User-Agent', 'value': 'PostLensRuntime/7.53.0', 'enabled': 'true'},
          {'key': 'Accept', 'value': '*/*', 'enabled': 'true'},
          {'key': 'Accept-Encoding', 'value': 'gzip, deflate, br', 'enabled': 'true'},
          {'key': 'Connection', 'value': 'keep-alive', 'enabled': 'true'},
        ],
        bodyType: 'none',
        rawBodyType: 'JSON',
        authType: 'No Auth',
        basicAuthUsername: '',
        basicAuthPassword: '',
        bearerToken: '',
        apiKeyKey: '',
        apiKeyValue: '',
        apiKeyAddTo: 'Header',
        authConfig: const {},
        body: '',
        graphqlQuery: '',
        graphqlVariables: '',
        formData: const [],
        urlEncodedData: const [],
        binaryFilePath: '',
        settings: settings,
      ));
    }
  }

  void updateUrl(String url) {
    final parts = url.split('?');

    // Extract current parameters from state
    final currentParams =
        List<Map<String, String>>.from(state.params).map(_ensureRowId).toList();

    // Parse new query parameters from URL
    final parsedParams = <Map<String, String>>[];
    if (parts.length > 1) {
      final queryString = parts.sublist(1).join('?');
      if (queryString.isNotEmpty) {
        final queryParts = queryString.split('&');
        for (var part in queryParts) {
          if (part.isEmpty) continue;
          final kv = part.split('=');
          try {
            final key = kv[0].isNotEmpty ? Uri.decodeQueryComponent(kv[0]) : '';
            final value = kv.length > 1
                ? Uri.decodeQueryComponent(kv.sublist(1).join('='))
                : '';
            parsedParams.add({
              'id': _makeRowId(),
              'key': key,
              'value': value,
              'enabled': 'true'
            });
          } catch (e) {
            parsedParams.add({
              'id': _makeRowId(),
              'key': kv[0],
              'value': kv.length > 1 ? kv.sublist(1).join('=') : '',
              'enabled': 'true'
            });
          }
        }
      }
    }

    // Merge parsedParams with currentParams to preserve disabled parameters
    // and maintain the order as much as possible.
    final newParams = <Map<String, String>>[];
    int parsedIndex = 0;

    for (var p in currentParams) {
      if ((p['enabled'] ?? 'true') != 'true') {
        newParams.add(p); // Keep disabled params
      } else {
        // Replace enabled param with the parsed one if available
        if (parsedIndex < parsedParams.length) {
          newParams.add(parsedParams[parsedIndex]);
          parsedIndex++;
        }
      }
    }

    // Add any remaining parsed params
    while (parsedIndex < parsedParams.length) {
      newParams.add(parsedParams[parsedIndex]);
      parsedIndex++;
    }

    _setState(state.copyWith(url: url, params: _ensureRowIds(newParams)));
  }

  void updateName(String name) {
    _setState(state.copyWith(name: name));
  }

  void addParam(String key, String value, [String desc = '']) {
    final params = List<Map<String, String>>.from(state.params);
    params.add(
        {'id': _makeRowId(), 'key': key, 'value': value, 'description': desc, 'enabled': 'true'});
    _updateParamsAndSyncUrl(params);
  }

  void updateParam(int index, String key, String value) {
    final params = List<Map<String, String>>.from(state.params);
    if (index >= 0 && index < params.length) {
      final id = params[index]['id'] ?? _makeRowId();
      final enabled = params[index]['enabled'] ?? 'true';
      params[index] = {
        'id': id,
        'key': key,
        'value': value,
        'enabled': enabled
      };
      _updateParamsAndSyncUrl(params);
    }
  }

  void updateParamEnabled(int index, bool enabled) {
    final params = List<Map<String, String>>.from(state.params);
    if (index >= 0 && index < params.length) {
      final id = params[index]['id'] ?? _makeRowId();
      params[index] = {
        ...params[index],
        'id': id,
        'enabled': enabled.toString(),
      };
      _updateParamsAndSyncUrl(params);
    }
  }

  void removeParam(int index) {
    final params = List<Map<String, String>>.from(state.params);
    if (index >= 0 && index < params.length) {
      params.removeAt(index);
      _updateParamsAndSyncUrl(params);
    }
  }

  void _updateParamsAndSyncUrl(List<Map<String, String>> params) {
    params = _ensureRowIds(params);
    final baseUrl = state.url.split('?').first;
    final queryParts = <String>[];
    for (var p in params) {
      if ((p['enabled'] ?? 'true') == 'true' &&
          (p['key']?.isNotEmpty ?? false)) {
        final key = Uri.encodeQueryComponent(p['key']!);
        final value = Uri.encodeQueryComponent(p['value'] ?? '');
        queryParts.add('$key=$value');
      }
    }

    final newUrl =
        queryParts.isEmpty ? baseUrl : '$baseUrl?${queryParts.join('&')}';
    _setState(state.copyWith(params: params, url: newUrl));
  }

  void addHeader(String key, String value, [String desc = '']) {
    final headers = List<Map<String, String>>.from(state.headers);
    headers.add(
        {'id': _makeRowId(), 'key': key, 'value': value, 'description': desc, 'enabled': 'true'});
    _setState(state.copyWith(headers: _ensureRowIds(headers)));
  }

  void updateHeader(int index, String key, String value) {
    final headers = List<Map<String, String>>.from(state.headers);
    if (index >= 0 && index < headers.length) {
      final id = headers[index]['id'] ?? _makeRowId();
      final enabled = headers[index]['enabled'] ?? 'true';
      headers[index] = {
        'id': id,
        'key': key,
        'value': value,
        'enabled': enabled
      };
      _setState(state.copyWith(headers: _ensureRowIds(headers)));
    }
  }

  void updateHeaderEnabled(int index, bool enabled) {
    final headers = List<Map<String, String>>.from(state.headers);
    if (index >= 0 && index < headers.length) {
      final id = headers[index]['id'] ?? _makeRowId();
      headers[index] = {
        ...headers[index],
        'id': id,
        'enabled': enabled.toString(),
      };
      _setState(state.copyWith(headers: _ensureRowIds(headers)));
    }
  }

  void removeHeader(int index) {
    final headers = List<Map<String, String>>.from(state.headers);
    if (index >= 0 && index < headers.length) {
      headers.removeAt(index);
      _setState(state.copyWith(headers: headers));
    }
  }

  void updateBody(String body) {
    _setState(state.copyWith(body: body));
  }

  void updateBodyType(String type) {
    _setState(state.copyWith(bodyType: type));
  }

  void updateRawBodyType(String type) {
    _setState(state.copyWith(rawBodyType: type));
  }

  void updateGraphqlQuery(String query) {
    _setState(state.copyWith(graphqlQuery: query));
  }

  void updateGraphqlVariables(String variables) {
    _setState(state.copyWith(graphqlVariables: variables));
  }

  void updateAuthType(String type) {
    _setState(state.copyWith(authType: type));
  }

  void updateBasicAuthUsername(String username) {
    _setState(state.copyWith(basicAuthUsername: username));
  }

  void updateBasicAuthPassword(String password) {
    _setState(state.copyWith(basicAuthPassword: password));
  }

  void updateBearerToken(String token) {
    _setState(state.copyWith(bearerToken: token));
  }

  void updateApiKey(String key, String value, String addTo) {
    _setState(
      state.copyWith(apiKeyKey: key, apiKeyValue: value, apiKeyAddTo: addTo),
    );
  }

  void updateAuthConfig(String key, dynamic value) {
    final newConfig = Map<String, dynamic>.from(state.authConfig);
    newConfig[key] = value;
    _setState(state.copyWith(authConfig: newConfig));
  }

  void addFormData(String key, String value, {String type = 'Text'}) {
    final formData = List<Map<String, String>>.from(state.formData);
    formData.add({'key': key, 'value': value, 'type': type});
    _setState(state.copyWith(formData: formData));
  }

  void updateFormData(int index, String key, String value, {String? type}) {
    final formData = List<Map<String, String>>.from(state.formData);
    if (index >= 0 && index < formData.length) {
      final oldType = formData[index]['type'] ?? 'Text';
      formData[index] = {'key': key, 'value': value, 'type': type ?? oldType};
      _setState(state.copyWith(formData: formData));
    }
  }

  void removeFormData(int index) {
    final formData = List<Map<String, String>>.from(state.formData);
    if (index >= 0 && index < formData.length) {
      formData.removeAt(index);
      _setState(state.copyWith(formData: formData));
    }
  }

  void addUrlEncodedData(String key, String value) {
    final urlEncodedData = List<Map<String, String>>.from(state.urlEncodedData);
    urlEncodedData.add({'key': key, 'value': value});
    _setState(state.copyWith(urlEncodedData: urlEncodedData));
  }

  void updateUrlEncodedData(int index, String key, String value) {
    final urlEncodedData = List<Map<String, String>>.from(state.urlEncodedData);
    if (index >= 0 && index < urlEncodedData.length) {
      urlEncodedData[index] = {'key': key, 'value': value};
      _setState(state.copyWith(urlEncodedData: urlEncodedData));
    }
  }

  void removeUrlEncodedData(int index) {
    final urlEncodedData = List<Map<String, String>>.from(state.urlEncodedData);
    if (index >= 0 && index < urlEncodedData.length) {
      urlEncodedData.removeAt(index);
      _setState(state.copyWith(urlEncodedData: urlEncodedData));
    }
  }

  void updatePreRequestScript(String script) {
    _setState(state.copyWith(preRequestScript: script));
  }

  void updateTests(String tests) {
    _setState(state.copyWith(tests: tests));
  }

  void updateSettings(String key, dynamic value) {
    final settings = Map<String, dynamic>.from(state.settings);
    settings[key] = value;
    _setState(state.copyWith(settings: settings));
  }

  void updateAllSettings(Map<String, dynamic> newSettings) {
    _setState(state.copyWith(settings: newSettings));
  }

  void updateParams(List<Map<String, String>> params) {
    _updateParamsAndSyncUrl(params);
  }

  void updateHeaders(List<Map<String, String>> headers) {
    _setState(state.copyWith(headers: _ensureRowIds(headers)));
  }

  void updateBinaryFilePath(String path) {
    _setState(state.copyWith(binaryFilePath: path));
  }

  void loadRequest(HttpRequestModel request) {
    final normalizedRequest = _normalizeRequest(request);
    _requestsById.putIfAbsent(request.id, () => normalizedRequest);
    _savedRequestSignatures.putIfAbsent(
      request.id,
      () => _requestSignature(normalizedRequest),
    );
    _setState(_requestsById[request.id] ?? normalizedRequest);
    
    // Load response if available
    if (request.response != null) {
      _ref?.read(responseProvider(request.id).notifier).state = request.response;
    }
  }

  void markSaved([HttpRequestModel? request]) {
    final normalized = _normalizeRequest(request ?? state);
    _requestsById[normalized.id] = normalized;
    _savedRequestSignatures[normalized.id] = _requestSignature(normalized);
    if (state.id == normalized.id) {
      state = normalized;
      _ref?.read(activeRequestIdProvider.notifier).state = normalized.id;
    }
    _ref?.read(requestDirtyProvider(normalized.id).notifier).state = false;
  }

  void removeRequestCache(String requestId) {
    _requestsById.remove(requestId);
    _savedRequestSignatures.remove(requestId);
    if (state.id == requestId) {
      _ref?.read(activeRequestIdProvider.notifier).state = '';
    }
    _ref?.invalidate(requestDirtyProvider(requestId));
  }
}

final requestProvider =
    StateNotifierProvider<RequestNotifier, HttpRequestModel>((ref) {
  return RequestNotifier(ref);
});

final requestDirtyProvider = StateProvider.family<bool, String>((ref, id) {
  return false;
});

class RequestPageUiState {
  final int requestTabIndex;
  final int responseTabIndex;
  final bool showDefaultHeaders;
  final bool showBodySchema;
  final bool showBodyPreview;
  final String responseFormat;
  final bool responseWrapLines;

  const RequestPageUiState({
    this.requestTabIndex = 0,
    this.responseTabIndex = 0,
    this.showDefaultHeaders = false,
    this.showBodySchema = false,
    this.showBodyPreview = false,
    this.responseFormat = 'Auto',
    this.responseWrapLines = true,
  });

  RequestPageUiState copyWith({
    int? requestTabIndex,
    int? responseTabIndex,
    bool? showDefaultHeaders,
    bool? showBodySchema,
    bool? showBodyPreview,
    String? responseFormat,
    bool? responseWrapLines,
  }) {
    return RequestPageUiState(
      requestTabIndex: requestTabIndex ?? this.requestTabIndex,
      responseTabIndex: responseTabIndex ?? this.responseTabIndex,
      showDefaultHeaders: showDefaultHeaders ?? this.showDefaultHeaders,
      showBodySchema: showBodySchema ?? this.showBodySchema,
      showBodyPreview: showBodyPreview ?? this.showBodyPreview,
      responseFormat: responseFormat ?? this.responseFormat,
      responseWrapLines: responseWrapLines ?? this.responseWrapLines,
    );
  }
}

class RequestPageUiNotifier extends StateNotifier<RequestPageUiState> {
  RequestPageUiNotifier() : super(const RequestPageUiState());

  void updateRequestTabIndex(int index) {
    state = state.copyWith(requestTabIndex: index);
  }

  void updateResponseTabIndex(int index) {
    state = state.copyWith(responseTabIndex: index);
  }

  void updateShowDefaultHeaders(bool value) {
    state = state.copyWith(showDefaultHeaders: value);
  }

  void updateShowBodySchema(bool value) {
    state = state.copyWith(showBodySchema: value);
  }

  void updateShowBodyPreview(bool value) {
    state = state.copyWith(showBodyPreview: value);
  }

  void updateResponseFormat(String value) {
    state = state.copyWith(responseFormat: value);
  }

  void updateResponseWrapLines(bool value) {
    state = state.copyWith(responseWrapLines: value);
  }
}

final requestPageUiProvider = StateNotifierProvider.family<
    RequestPageUiNotifier, RequestPageUiState, String>((ref, id) {
  return RequestPageUiNotifier();
});

class HistoryNotifier extends StateNotifier<List<HttpRequestModel>> {
  HistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final data = await DatabaseHelper.instance.getHistory();
      if (data.isNotEmpty) {
        state = data.map((e) {
          final req =
              HttpRequestModel.fromJson(jsonDecode(e['data'] as String));
          // If the request ID is not a valid timestamp, update it to the timestamp from the database
          if (int.tryParse(req.id) == null ||
              int.tryParse(req.id)! < 1000000000000) {
            return HttpRequestModel(
              id: e['timestamp'].toString(),
              name: req.name,
              description: req.description,
              method: req.method,
              url: req.url,
              protocol: req.protocol,
              params: req.params,
              headers: req.headers,
              bodyType: req.bodyType,
              rawBodyType: req.rawBodyType,
              authType: req.authType,
              basicAuthUsername: req.basicAuthUsername,
              basicAuthPassword: req.basicAuthPassword,
              bearerToken: req.bearerToken,
              apiKeyKey: req.apiKeyKey,
              apiKeyValue: req.apiKeyValue,
              apiKeyAddTo: req.apiKeyAddTo,
              authConfig: req.authConfig,
              body: req.body,
              graphqlQuery: req.graphqlQuery,
              graphqlVariables: req.graphqlVariables,
              formData: req.formData,
              urlEncodedData: req.urlEncodedData,
              preRequestScript: req.preRequestScript,
              tests: req.tests,
              binaryFilePath: req.binaryFilePath,
              folderPath: req.folderPath?.map((e) => e.toString()).toList(),
              settings: req.settings,
              collectionId: req.collectionId,
              folderId: req.folderId,
              response: req.response,
            );
          }
          return req;
        }).toList();
      }
    } catch (e) {
      
    }
  }

  Future<void> addHistory(HttpRequestModel request) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // We update the request ID to the current timestamp to ensure it's properly sorted and grouped
      // We just need a new instance with the new ID
      final requestWithTimestamp = HttpRequestModel(
        id: timestamp.toString(),
        name: request.name,
        description: request.description,
        method: request.method,
        url: request.url,
        protocol: request.protocol,
        params: request.params,
        headers: request.headers,
        bodyType: request.bodyType,
        rawBodyType: request.rawBodyType,
        authType: request.authType,
        basicAuthUsername: request.basicAuthUsername,
        basicAuthPassword: request.basicAuthPassword,
        bearerToken: request.bearerToken,
        apiKeyKey: request.apiKeyKey,
        apiKeyValue: request.apiKeyValue,
        apiKeyAddTo: request.apiKeyAddTo,
        authConfig: request.authConfig,
        body: request.body,
        graphqlQuery: request.graphqlQuery,
        graphqlVariables: request.graphqlVariables,
        formData: request.formData,
        urlEncodedData: request.urlEncodedData,
        preRequestScript: request.preRequestScript,
        tests: request.tests,
        binaryFilePath: request.binaryFilePath,
        folderPath: request.folderPath,
        settings: request.settings,
        collectionId: request.collectionId,
        folderId: request.folderId,
        response: request.response,
      );

      state = [requestWithTimestamp, ...state];
      await DatabaseHelper.instance.insertHistory(requestWithTimestamp.id,
          timestamp, jsonEncode(requestWithTimestamp.toJson()));
    } catch (e) {
      
    }
  }

  Future<void> clearHistory() async {
    try {
      await DatabaseHelper.instance.clearHistory();
      state = [];
    } catch (e) {
      
    }
  }

  Future<void> setHistory(List<HttpRequestModel> history) async {
    await clearHistory();
    for (var request in history.reversed) {
      await addHistory(request);
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<HttpRequestModel>>((ref) {
  return HistoryNotifier();
});

final responseProvider =
    StateProvider.family<HttpResponseModel?, String>((ref, id) => null);

final isSendingProvider =
    StateProvider.family<bool, String>((ref, id) => false);
