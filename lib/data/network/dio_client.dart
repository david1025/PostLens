import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../../domain/models/http_request_model.dart';
import '../../domain/models/http_response_model.dart';
import '../../domain/models/environment_model.dart';
import '../../presentation/providers/settings_provider.dart';
import '../../presentation/providers/environment_provider.dart';
import '../../presentation/providers/global_variables_provider.dart';

// Top-level function for compute
dynamic _parseAndDecode(String response) {
  return jsonDecode(response);
}

// Function to pass to Dio's transformer
FutureOr<dynamic> parseJson(String text) {
  // Use compute only for large payloads to avoid isolate spawning overhead
  if (text.length < 50 * 1024) {
    return _parseAndDecode(text);
  }
  return compute(_parseAndDecode, text);
}

// Top-level function for json encoding
String _encodeAndPrettyPrint(dynamic data) {
  return const JsonEncoder.withIndent('  ').convert(data);
}

class NetworkClient {
  final Ref ref;

  NetworkClient(this.ref);

  String _replaceVariables(String text, EnvironmentModel? env) {
    if (text.isEmpty) return text;
    String result = text;
    final globalVars = ref.read(globalVariablesProvider);
    for (var variable in globalVars) {
      if (variable.enabled && variable.key.isNotEmpty) {
        result = result.replaceAll('{{${variable.key}}}', variable.value);
      }
    }
    if (env == null) return result;
    for (var variable in env.variables) {
      if (variable.enabled && variable.key.isNotEmpty) {
        result = result.replaceAll('{{${variable.key}}}', variable.value);
      }
    }
    return result;
  }

  HttpRequestModel _interpolateRequest(HttpRequestModel req) {
    final activeEnvironmentId = ref.read(activeEnvironmentIdProvider);
    EnvironmentModel? env;
    if (activeEnvironmentId != null) {
      final environments = ref.read(activeWorkspaceEnvironmentsProvider);
      final envList = environments.where((e) => e.id == activeEnvironmentId).toList();
      if (envList.isNotEmpty) {
        env = envList.first;
      }
    }

    String replace(String val) => _replaceVariables(val, env);

    List<Map<String, String>> replaceMapList(List<Map<String, String>> list) {
      return list.map((item) {
        return item.map((key, value) => MapEntry(key, replace(value)));
      }).toList();
    }

    return req.copyWith(
      url: replace(req.url),
      body: replace(req.body),
      bearerToken: replace(req.bearerToken),
      basicAuthUsername: replace(req.basicAuthUsername),
      basicAuthPassword: replace(req.basicAuthPassword),
      apiKeyValue: replace(req.apiKeyValue),
      graphqlQuery: replace(req.graphqlQuery),
      graphqlVariables: replace(req.graphqlVariables),
      params: replaceMapList(req.params),
      headers: replaceMapList(req.headers),
      formData: replaceMapList(req.formData),
      urlEncodedData: replaceMapList(req.urlEncodedData),
    );
  }

  Future<HttpResponseModel> sendRequest(HttpRequestModel request) async {
    request = _interpolateRequest(request);
    switch (request.protocol) {
      case 'ws':
        return _sendWebSocketRequest(request);
      case 'socket.io':
      case 'socket':
        return _sendSocketRequest(request);
      case 'mqtt':
        return _sendMqttRequest(request);
      case 'grpc':
        return _sendGrpcRequest(request);
      case 'http':
      default:
        return _sendHttpRequest(request);
    }
  }

  Future<HttpResponseModel> _sendHttpRequest(HttpRequestModel request) async {
    final stopwatch = Stopwatch()..start();
    final settings = ref.read(networkSettingsProvider);

    final dio = Dio()
      ..transformer = (BackgroundTransformer()..jsonDecodeCallback = parseJson);

    dio.options.connectTimeout = settings.requestTimeout > 0
        ? Duration(milliseconds: settings.requestTimeout)
        : null;
    dio.options.receiveTimeout = settings.requestTimeout > 0
        ? Duration(milliseconds: settings.requestTimeout)
        : null;

    // Apply request-specific settings
    dio.options.followRedirects = request.settings['followRedirects'] ?? true;
    dio.options.maxRedirects = request.settings['maxRedirects'] ?? 10;

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();

        if (settings.customProxyEnabled && settings.customProxyUrl.isNotEmpty) {
          client.findProxy = (uri) {
            return "PROXY ${settings.customProxyUrl}";
          };
        } else if (!settings.systemProxy) {
          client.findProxy = (uri) {
            return "DIRECT";
          };
        }

        final enableSslVerification =
            request.settings['enableSslVerification'] ?? false;
        if (!settings.sslVerification || !enableSslVerification) {
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
        }

        return client;
      },
    );

    try {
      // Build headers
      Map<String, dynamic> headers = {};
      for (var header in request.headers) {
        if (header.containsKey('key') &&
            header['key']!.isNotEmpty &&
            (header['enabled'] ?? 'true') == 'true') {
          var value = header['value'] ?? '';
          if (value == '<calculated when request is sent>') continue;

          final keyLower = header['key']!.toLowerCase();
          if (keyLower == 'content-length') {
            headers[header['key']!] = int.tryParse(value) ?? value;
          } else if (keyLower == 'accept-encoding') {
            // dart:io automatically decompresses gzip, but not br (brotli).
            // To prevent receiving raw compressed bytes, we force gzip.
            headers[header['key']!] = 'gzip';
          } else {
            headers[header['key']!] = value;
          }
        }
      }

      // Build query parameters
      Map<String, dynamic> queryParameters = {};
      for (var param in request.params) {
        if (param.containsKey('key') &&
            param['key']!.isNotEmpty &&
            (param['enabled'] ?? 'true') == 'true') {
          queryParameters[param['key']!] = param['value'] ?? '';
        }
      }

      if (settings.disableCookies ||
          (request.settings['disableCookieJar'] ?? false)) {
        headers.removeWhere((key, value) => key.toLowerCase() == 'cookie');
      }

      if (settings.sendNoCacheHeader) {
        headers['Cache-Control'] = 'no-cache';
      }

      // Handle Authentication
      if (request.authType == 'Basic Auth') {
        final username = request.basicAuthUsername;
        final password = request.basicAuthPassword;
        final basicAuth =
            'Basic ${base64Encode(utf8.encode('$username:$password'))}';
        headers['Authorization'] = basicAuth;
      } else if (request.authType == 'Bearer Token') {
        final token = request.bearerToken;
        if (token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      } else if (request.authType == 'API Key') {
        final key = request.apiKeyKey;
        final value = request.apiKeyValue;
        if (key.isNotEmpty) {
          if (request.apiKeyAddTo == 'Header') {
            headers[key] = value;
          } else if (request.apiKeyAddTo == 'Query Params') {
            queryParameters[key] = value;
          }
        }
      }

      // Handle Body & Content-Type
      dynamic requestData;

      if (request.method != 'GET' && request.method != 'HEAD') {
        switch (request.bodyType) {
          case 'raw':
            requestData = request.body;
            // Ensure proper Content-Type for raw body types if not already set by user
            if (!headers.keys.any((k) => k.toLowerCase() == 'content-type')) {
              switch (request.rawBodyType) {
                case 'JSON':
                  headers['Content-Type'] = 'application/json';
                  break;
                case 'Text':
                  headers['Content-Type'] = 'text/plain';
                  break;
                case 'JavaScript':
                  headers['Content-Type'] = 'application/javascript';
                  break;
                case 'HTML':
                  headers['Content-Type'] = 'text/html';
                  break;
                case 'XML':
                  headers['Content-Type'] = 'application/xml';
                  break;
              }
            }
            break;

          case 'form-data':
            final Map<String, dynamic> formDataMap = {};
            for (var item in request.formData) {
              if (item.containsKey('key') &&
                  item['key']!.isNotEmpty &&
                  (item['enabled'] ?? 'true') == 'true') {
                if (item['type']?.toLowerCase() == 'file') {
                  final filePath = item['value'];
                  if (filePath != null && filePath.isNotEmpty) {
                    final file = File(filePath);
                    if (file.existsSync()) {
                      formDataMap[item['key']!] = await MultipartFile.fromFile(
                        filePath,
                        filename: filePath.split(Platform.pathSeparator).last,
                      );
                    }
                  }
                } else {
                  formDataMap[item['key']!] = item['value'] ?? '';
                }
              }
            }
            requestData = FormData.fromMap(formDataMap);
            // Dio automatically handles 'multipart/form-data' content-type and boundaries when data is FormData
            headers.removeWhere((k, v) => k.toLowerCase() == 'content-type');
            break;

          case 'x-www-form-urlencoded':
            final Map<String, dynamic> urlEncodedMap = {};
            for (var item in request.urlEncodedData) {
              if (item.containsKey('key') &&
                  item['key']!.isNotEmpty &&
                  (item['enabled'] ?? 'true') == 'true') {
                urlEncodedMap[item['key']!] = item['value'] ?? '';
              }
            }
            requestData = urlEncodedMap;
            if (!headers.keys.any((k) => k.toLowerCase() == 'content-type')) {
              headers['Content-Type'] = 'application/x-www-form-urlencoded';
            }
            break;

          case 'none':
          default:
            requestData = request.body.isNotEmpty ? request.body : null;
            break;
        }
      }

      var url = request.url;
      if (url.isEmpty) {
        return HttpResponseModel.error('URL is empty');
      }
      if (!url.startsWith('http')) {
        url = 'http://$url';
      }

      final response = await dio.request(
        url,
        data: requestData,
        queryParameters: queryParameters,
        options: Options(
          method: request.method,
          headers: headers,
          validateStatus: (status) => true, // Accept all status codes
        ),
      );

      stopwatch.stop();

      String bodyString;
      if (response.data is String) {
        bodyString = response.data;
      } else {
        try {
          // Use compute to prevent main thread blocking during large JSON encoding
          bodyString = await compute(_encodeAndPrettyPrint, response.data);
        } catch (e) {
          bodyString = response.data.toString();
        }
      }
      final sizeBytes = bodyString.length; // Approximate size

      final Map<String, List<String>> responseHeaders = {};
      final List<Cookie> cookies = [];
      response.headers.forEach((name, values) {
        responseHeaders[name] = values;
        if (name.toLowerCase() == 'set-cookie') {
          for (var value in values) {
            final parts = value.split(';');
            if (parts.isNotEmpty) {
              final kv = parts[0].split('=');
              if (kv.length >= 2) {
                final cookieName = kv[0].trim();
                final cookieValue = kv.sublist(1).join('=').trim();

                String domain = '';
                String path = '/';
                String expires = 'Session';
                bool httpOnly = false;
                bool secure = false;

                for (var i = 1; i < parts.length; i++) {
                  final part = parts[i].trim();
                  final lowerPart = part.toLowerCase();
                  if (lowerPart.startsWith('domain=')) {
                    domain = part.substring(7).trim();
                  } else if (lowerPart.startsWith('path=')) {
                    path = part.substring(5).trim();
                  } else if (lowerPart.startsWith('expires=')) {
                    expires = part.substring(8).trim();
                  } else if (lowerPart == 'httponly') {
                    httpOnly = true;
                  } else if (lowerPart == 'secure') {
                    secure = true;
                  }
                }

                cookies.add(Cookie(
                  name: cookieName,
                  value: cookieValue,
                  domain: domain.isEmpty ? Uri.parse(url).host : domain,
                  path: path,
                  expires: expires,
                  httpOnly: httpOnly,
                  secure: secure,
                ));
              }
            }
          }
        }
      });

      return HttpResponseModel(
        statusCode: response.statusCode ?? 0,
        statusMessage: response.statusMessage ?? '',
        timeMs: stopwatch.elapsedMilliseconds,
        sizeBytes: sizeBytes,
        body: bodyString,
        headers: responseHeaders,
        cookies: cookies,
      );
    } catch (e) {
      stopwatch.stop();
      return HttpResponseModel.error(e.toString());
    }
  }

  Future<HttpResponseModel> _sendWebSocketRequest(
      HttpRequestModel request) async {
    final stopwatch = Stopwatch()..start();
    try {
      var url = request.url;
      if (url.isEmpty) return HttpResponseModel.error('URL is empty');
      if (!url.startsWith('ws')) url = 'ws://$url';

      final channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready;

      if (request.body.isNotEmpty) {
        channel.sink.add(request.body);
      }

      // Wait for one message or timeout
      final response =
          await channel.stream.first.timeout(const Duration(seconds: 10));
      channel.sink.close();

      stopwatch.stop();
      return HttpResponseModel(
        statusCode: 200,
        statusMessage: 'OK',
        timeMs: stopwatch.elapsedMilliseconds,
        sizeBytes: response.toString().length,
        body: response.toString(),
        headers: {
          'protocol': ['websocket']
        },
      );
    } catch (e) {
      stopwatch.stop();
      return HttpResponseModel.error(e.toString());
    }
  }

  Future<HttpResponseModel> _sendSocketRequest(HttpRequestModel request) async {
    final stopwatch = Stopwatch()..start();
    try {
      var url = request.url;
      if (url.isEmpty) return HttpResponseModel.error('URL is empty');

      final parts = url.split(':');
      final host = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 80 : 80;

      final socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      if (request.body.isNotEmpty) {
        socket.write(request.body);
      }

      final data = await socket.first.timeout(const Duration(seconds: 10));
      socket.destroy();

      stopwatch.stop();
      final bodyString = utf8.decode(data, allowMalformed: true);
      return HttpResponseModel(
        statusCode: 200,
        statusMessage: 'OK',
        timeMs: stopwatch.elapsedMilliseconds,
        sizeBytes: data.length,
        body: bodyString,
        headers: {
          'protocol': ['tcp socket']
        },
      );
    } catch (e) {
      stopwatch.stop();
      return HttpResponseModel.error(e.toString());
    }
  }

  Future<HttpResponseModel> _sendMqttRequest(HttpRequestModel request) async {
    final stopwatch = Stopwatch()..start();
    try {
      var url = request.url;
      if (url.isEmpty) return HttpResponseModel.error('Broker URL is empty');

      final parts = url.split(':');
      final host = parts[0];
      final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 1883 : 1883;

      final client = MqttServerClient(
          host, 'post_lens_client_${DateTime.now().millisecondsSinceEpoch}');
      client.port = port;
      client.logging(on: false);
      client.keepAlivePeriod = 20;

      final status = await client.connect();
      if (status?.state != MqttConnectionState.connected) {
        client.disconnect();
        return HttpResponseModel.error('MQTT Connection failed');
      }

      // Find topic from params
      String topic = 'test/topic';
      for (var p in request.params) {
        if (p['key'] == 'topic') topic = p['value'] ?? topic;
      }

      final builder = MqttClientPayloadBuilder();
      builder.addString(request.body.isNotEmpty ? request.body : 'ping');
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);

      client.disconnect();
      stopwatch.stop();
      return HttpResponseModel(
        statusCode: 200,
        statusMessage: 'Published',
        timeMs: stopwatch.elapsedMilliseconds,
        sizeBytes: request.body.length,
        body: 'Published message to $topic',
        headers: {
          'protocol': ['mqtt']
        },
      );
    } catch (e) {
      stopwatch.stop();
      return HttpResponseModel.error(e.toString());
    }
  }

  Future<HttpResponseModel> _sendGrpcRequest(HttpRequestModel request) async {
    final stopwatch = Stopwatch()..start();
    try {
      // Basic simulation of gRPC for now, actual gRPC requires compiled protos
      stopwatch.stop();
      return HttpResponseModel(
        statusCode: 200,
        statusMessage: 'OK',
        timeMs: stopwatch.elapsedMilliseconds,
        sizeBytes: 0,
        body:
            'gRPC request to ${request.url} simulated.\n(Requires proto compilation for full dynamic reflection)',
        headers: {
          'protocol': ['grpc']
        },
      );
    } catch (e) {
      stopwatch.stop();
      return HttpResponseModel.error(e.toString());
    }
  }
}
