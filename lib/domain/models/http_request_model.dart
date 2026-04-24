import 'http_response_model.dart';

class HttpRequestModel {
  final String id;
  final String name;
  final String method;
  final String url;
  final String protocol; // 'http', 'grpc', 'ws', 'socket', 'mqtt'
  final List<Map<String, String>> params;
  final List<Map<String, String>> headers;
  final String bodyType;
  final String rawBodyType; // 'JSON', 'Text', 'JavaScript', 'HTML', 'XML'
  final String authType;
  final String basicAuthUsername;
  final String basicAuthPassword;
  final String bearerToken;
  final String apiKeyKey;
  final String apiKeyValue;
  final String apiKeyAddTo; // 'Header' or 'Query Params'
  final Map<String, dynamic> authConfig;
  final String body;
  final String graphqlQuery;
  final String graphqlVariables;
  final List<Map<String, String>> formData;
  final List<Map<String, String>> urlEncodedData;
  final String preRequestScript;
  final String tests;
  final String binaryFilePath;
  final List<String>? folderPath;
  final String? collectionId;
  final String? folderId;
  final String description;
  final Map<String, dynamic> settings;
  final HttpResponseModel? response;

  HttpRequestModel({
    required this.id,
    this.name = 'New Request',
    this.description = '',
    this.method = 'GET',
    this.url = '',
    this.protocol = 'http',
    this.params = const [],
    this.headers = const [
      {'key': 'Cache-Control', 'value': 'no-cache', 'enabled': 'true'},
      {
        'key': 'PostLens-Token',
        'value': '<calculated when request is sent>',
        'enabled': 'true'
      },
      {
        'key': 'Host',
        'value': '<calculated when request is sent>',
        'enabled': 'true'
      },
      {
        'key': 'User-Agent',
        'value': 'PostLensRuntime/7.53.0',
        'enabled': 'true'
      },
      {'key': 'Accept', 'value': '*/*', 'enabled': 'true'},
      {
        'key': 'Accept-Encoding',
        'value': 'gzip, deflate, br',
        'enabled': 'true'
      },
      {'key': 'Connection', 'value': 'keep-alive', 'enabled': 'true'},
    ],
    this.bodyType = 'none',
    this.rawBodyType = 'JSON',
    this.authType = 'No Auth',
    this.basicAuthUsername = '',
    this.basicAuthPassword = '',
    this.bearerToken = '',
    this.apiKeyKey = '',
    this.apiKeyValue = '',
    this.apiKeyAddTo = 'Header',
    this.authConfig = const {},
    this.body = '',
    this.graphqlQuery = '',
    this.graphqlVariables = '',
    this.formData = const [],
    this.urlEncodedData = const [],
    this.preRequestScript = '',
    this.tests = '',
    this.binaryFilePath = '',
    this.folderPath,
    this.collectionId,
    this.folderId,
    this.settings = const {},
    this.response,
  });

  HttpRequestModel copyWith({
    String? name,
    String? description,
    String? method,
    String? url,
    String? protocol,
    List<Map<String, String>>? params,
    List<Map<String, String>>? headers,
    String? bodyType,
    String? rawBodyType,
    String? authType,
    String? basicAuthUsername,
    String? basicAuthPassword,
    String? bearerToken,
    String? apiKeyKey,
    String? apiKeyValue,
    String? apiKeyAddTo,
    Map<String, dynamic>? authConfig,
    String? body,
    String? graphqlQuery,
    String? graphqlVariables,
    List<Map<String, String>>? formData,
    List<Map<String, String>>? urlEncodedData,
    String? preRequestScript,
    String? tests,
    String? binaryFilePath,
    List<String>? folderPath,
    String? collectionId,
    String? folderId,
    Map<String, dynamic>? settings,
    HttpResponseModel? response,
  }) {
    return HttpRequestModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      method: method ?? this.method,
      url: url ?? this.url,
      protocol: protocol ?? this.protocol,
      params: params ?? this.params,
      headers: headers ?? this.headers,
      bodyType: bodyType ?? this.bodyType,
      rawBodyType: rawBodyType ?? this.rawBodyType,
      authType: authType ?? this.authType,
      basicAuthUsername: basicAuthUsername ?? this.basicAuthUsername,
      basicAuthPassword: basicAuthPassword ?? this.basicAuthPassword,
      bearerToken: bearerToken ?? this.bearerToken,
      apiKeyKey: apiKeyKey ?? this.apiKeyKey,
      apiKeyValue: apiKeyValue ?? this.apiKeyValue,
      apiKeyAddTo: apiKeyAddTo ?? this.apiKeyAddTo,
      authConfig: authConfig ?? this.authConfig,
      body: body ?? this.body,
      graphqlQuery: graphqlQuery ?? this.graphqlQuery,
      graphqlVariables: graphqlVariables ?? this.graphqlVariables,
      formData: formData ?? this.formData,
      urlEncodedData: urlEncodedData ?? this.urlEncodedData,
      preRequestScript: preRequestScript ?? this.preRequestScript,
      tests: tests ?? this.tests,
      binaryFilePath: binaryFilePath ?? this.binaryFilePath,
      folderPath: folderPath ?? this.folderPath,
      collectionId: collectionId ?? this.collectionId,
      folderId: folderId ?? this.folderId,
      settings: settings ?? this.settings,
      response: response ?? this.response,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'method': method,
      'url': url,
      'protocol': protocol,
      'params': params,
      'headers': headers,
      'bodyType': bodyType,
      'rawBodyType': rawBodyType,
      'authType': authType,
      'basicAuthUsername': basicAuthUsername,
      'basicAuthPassword': basicAuthPassword,
      'bearerToken': bearerToken,
      'apiKeyKey': apiKeyKey,
      'apiKeyValue': apiKeyValue,
      'apiKeyAddTo': apiKeyAddTo,
      'authConfig': authConfig,
      'body': body,
      'graphqlQuery': graphqlQuery,
      'graphqlVariables': graphqlVariables,
      'formData': formData,
      'urlEncodedData': urlEncodedData,
      'preRequestScript': preRequestScript,
      'tests': tests,
      'binaryFilePath': binaryFilePath,
      'folderPath': folderPath,
      'collectionId': collectionId,
      'folderId': folderId,
      'settings': settings,
      'response': response?.toJson(),
    };
  }

  factory HttpRequestModel.fromJson(Map<String, dynamic> json) {
    return HttpRequestModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'New Request',
      description: json['description'] as String? ?? '',
      method: json['method'] as String? ?? 'GET',
      url: json['url'] as String? ?? '',
      protocol: json['protocol'] as String? ?? 'http',
      params: (json['params'] as List?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      headers: (json['headers'] as List?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      bodyType: json['bodyType'] as String? ?? 'none',
      rawBodyType: json['rawBodyType'] as String? ?? 'JSON',
      authType: json['authType'] as String? ?? 'No Auth',
      basicAuthUsername: json['basicAuthUsername'] as String? ?? '',
      basicAuthPassword: json['basicAuthPassword'] as String? ?? '',
      bearerToken: json['bearerToken'] as String? ?? '',
      apiKeyKey: json['apiKeyKey'] as String? ?? '',
      apiKeyValue: json['apiKeyValue'] as String? ?? '',
      apiKeyAddTo: json['apiKeyAddTo'] as String? ?? 'Header',
      authConfig: json['authConfig'] as Map<String, dynamic>? ?? const {},
      body: json['body'] as String? ?? '',
      graphqlQuery: json['graphqlQuery'] as String? ?? '',
      graphqlVariables: json['graphqlVariables'] as String? ?? '',
      formData: (json['formData'] as List?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      urlEncodedData: (json['urlEncodedData'] as List?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
      preRequestScript: json['preRequestScript'] as String? ?? '',
      tests: json['tests'] as String? ?? '',
      binaryFilePath: json['binaryFilePath'] as String? ?? '',
      folderPath: json['folderPath'] != null
          ? List<String>.from(json['folderPath'] as List)
          : null,
      collectionId: json['collectionId'] as String?,
      folderId: json['folderId'] as String?,
      settings: json['settings'] as Map<String, dynamic>? ?? const {},
      response: json['response'] != null 
          ? HttpResponseModel.fromJson(json['response'] as Map<String, dynamic>)
          : null,
    );
  }
}
