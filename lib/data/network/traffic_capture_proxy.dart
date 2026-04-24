import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'certificate_manager.dart';
import '../../domain/models/capture_session_model.dart';

import '../../utils/process_helper.dart';

class TrafficCaptureProxy {
  int port = 0;
  bool enableSslProxying = false;
  HttpServer? _server;
  final Function(CaptureSessionModel session)? onSession;
  final Function(String error)? onError;
  final Map<String, HttpServer> _secureServers = {};
  final Map<int, ProcessInfo> _mitmPortToProcessInfo = {};
  final Map<int, String> _mitmPortToClientIp = {};
  final Map<int, int> _mitmPortToClientPort = {};

  TrafficCaptureProxy(
      {this.onSession, this.onError, this.enableSslProxying = false});

  Future<void> start({int preferredPort = 8888}) async {
    if (_server != null) return;

    await CertificateManager.instance.initialize();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    port = _server!.port;
    

    _server!.listen(_handleRequest, onError: (e) {
      
      onError?.call(e.toString());
    });
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) await server.close(force: true);

    for (final s in _secureServers.values) {
      await s.close(force: true);
    }
    _secureServers.clear();
  }

  Future<HttpServer> _getSecureServerForHost(String host) async {
    if (_secureServers.containsKey(host)) {
      return _secureServers[host]!;
    }
    final context =
        await CertificateManager.instance.getCertificateForDomain(host);
    final secureServer = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    secureServer.listen((req) {
      _handleHttp(request: req, isMitm: true, mitmHost: host);
    }, onError: (e) {
      
    });
    _secureServers[host] = secureServer;
    return secureServer;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.method.toUpperCase() == 'CONNECT') {
      await _handleConnect(request);
    } else {
      await _handleHttp(request: request, isMitm: false);
    }
  }

  Future<void> _handleConnect(HttpRequest request) async {
    final hostPort = request.uri.authority.isNotEmpty
        ? request.uri.authority
        : request.uri.toString();
    final separatorIndex = hostPort.lastIndexOf(':');
    final host =
        separatorIndex >= 0 ? hostPort.substring(0, separatorIndex) : hostPort;

    Socket? clientSocket;
    Socket? upstreamSocket;

    try {
      clientSocket = await request.response.detachSocket(writeHeaders: false);
      clientSocket.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      await clientSocket.flush();

      if (enableSslProxying) {
        final secureServer = await _getSecureServerForHost(host);
        upstreamSocket = await Socket.connect('127.0.0.1', secureServer.port);

        // Save the client info to use later in MITM HTTP requests
        final clientIp = request.connectionInfo?.remoteAddress.address;
        final clientPort = request.connectionInfo?.remotePort;
        if (clientPort != null) {
          final pInfo = await ProcessHelper.getProcessByPort(clientPort);
          final mitmPort = upstreamSocket.port;
          _mitmPortToProcessInfo[mitmPort] = pInfo;
          _mitmPortToClientIp[mitmPort] = clientIp ?? '';
          _mitmPortToClientPort[mitmPort] = clientPort;

          upstreamSocket.done.then((_) {
            _mitmPortToProcessInfo.remove(mitmPort);
            _mitmPortToClientIp.remove(mitmPort);
            _mitmPortToClientPort.remove(mitmPort);
          }).catchError((_) {
            _mitmPortToProcessInfo.remove(mitmPort);
            _mitmPortToClientIp.remove(mitmPort);
            _mitmPortToClientPort.remove(mitmPort);
          });
        }
      } else {
        final targetPort = separatorIndex >= 0
            ? int.parse(hostPort.substring(separatorIndex + 1))
            : 443;
        upstreamSocket = await Socket.connect(host, targetPort);

        // Log a tunneled session
        if (onSession != null) {
          final clientIp = request.connectionInfo?.remoteAddress.address;
          final clientPort = request.connectionInfo?.remotePort;

          String? processId;
          String? appName;
          String? appPath;

          if (clientPort != null) {
            final pInfo = await ProcessHelper.getProcessByPort(clientPort);
            processId = pInfo.processId;
            appName = pInfo.appName;
            appPath = pInfo.appPath;
          }

          String? serverIp;
          try {
            final addresses = await InternetAddress.lookup(host);
            if (addresses.isNotEmpty) {
              serverIp = addresses.first.address;
            }
          } catch (_) {}

          final session = CaptureSessionModel(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            startedAt: DateTime.now(),
            protocol: 'TUNNEL',
            method: 'CONNECT',
            url: 'https://$hostPort',
            host: host,
            port: targetPort,
            statusCode: 200,
            statusMessage: 'Tunneled',
            durationMs: 0,
            requestBytes: 0,
            responseBytes: 0,
            requestHeaders: const {},
            requestBody: '',
            responseHeaders: const {},
            responseBody: '',
            error: null,
            clientIp: clientIp,
            clientPort: clientPort,
            serverIp: serverIp,
            processId: processId,
            appName: appName,
            appPath: appPath,
          );
          onSession!(session);
        }
      }

      clientSocket.listen(
        upstreamSocket.add,
        onDone: () => upstreamSocket?.close(),
        onError: (_) => upstreamSocket?.destroy(),
        cancelOnError: true,
      );
      upstreamSocket.listen(
        clientSocket.add,
        onDone: () => clientSocket?.close(),
        onError: (_) => clientSocket?.destroy(),
        cancelOnError: true,
      );
    } catch (e) {
      
      clientSocket?.destroy();
      upstreamSocket?.destroy();
    }
  }

  Future<void> _handleHttp({
    required HttpRequest request,
    required bool isMitm,
    String? mitmHost,
  }) async {
    final startTime = DateTime.now();
    final sessionId = startTime.microsecondsSinceEpoch.toString();

    Uri targetUri;
    try {
      if (request.uri.hasScheme) {
        targetUri = request.uri;
      } else {
        final hostHeader = request.headers.host ?? mitmHost ?? 'localhost';
        final scheme = isMitm ? 'https' : 'http';
        targetUri = Uri.parse('$scheme://$hostHeader${request.uri}');
      }
    } catch (_) {
      targetUri = Uri.parse('http://localhost/');
    }

    final reqHeaders = <String, List<String>>{};
    request.headers.forEach((name, values) {
      reqHeaders[name] = values;
    });

    String? clientIp;
    int? clientPort;
    String? processId;
    String? appName;
    String? appPath;

    if (isMitm) {
      final mitmPort = request.connectionInfo?.remotePort;
      if (mitmPort != null) {
        final pInfo = _mitmPortToProcessInfo[mitmPort];
        if (pInfo != null) {
          processId = pInfo.processId;
          appName = pInfo.appName;
          appPath = pInfo.appPath;
        }
        clientIp = _mitmPortToClientIp[mitmPort];
        clientPort = _mitmPortToClientPort[mitmPort];
      }
    } else {
      clientIp = request.connectionInfo?.remoteAddress.address;
      clientPort = request.connectionInfo?.remotePort;
      if (clientPort != null) {
        final pInfo = await ProcessHelper.getProcessByPort(clientPort);
        processId = pInfo.processId;
        appName = pInfo.appName;
        appPath = pInfo.appPath;
      }
    }

    String? serverIp;
    try {
      final addresses = await InternetAddress.lookup(targetUri.host);
      if (addresses.isNotEmpty) {
        serverIp = addresses.first.address;
      }
    } catch (_) {}

    CaptureSessionModel session = CaptureSessionModel(
      id: sessionId,
      startedAt: startTime,
      protocol: targetUri.scheme,
      method: request.method,
      url: targetUri.toString(),
      host: targetUri.host,
      port: targetUri.port,
      statusCode: null,
      statusMessage: 'Pending...',
      durationMs: 0,
      requestBytes: 0,
      responseBytes: 0,
      requestHeaders: reqHeaders,
      requestBody: '',
      responseHeaders: const {},
      responseBody: '',
      error: null,
      clientIp: clientIp,
      clientPort: clientPort,
      serverIp: serverIp,
      processId: processId,
      appName: appName,
      appPath: appPath,
    );

    if (onSession != null) {
      onSession!(session);
    }

    final client = HttpClient();
    client.autoUncompress = false;
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;

    try {
      final upstreamRequest = await client.openUrl(request.method, targetUri);
      upstreamRequest.followRedirects = false; // Important for proxies
      _copyHeadersToUpstream(request.headers, upstreamRequest.headers);

      final requestBytesBuilder = BytesBuilder(copy: false);
      await for (final data in request) {
        requestBytesBuilder.add(data);
        upstreamRequest.add(data);
      }
      final requestBytes = requestBytesBuilder.takeBytes();
      String reqBodyStr = _decodeBody(requestBytes, reqHeaders);

      session = session.copyWith(
        requestBytes: requestBytes.length,
        requestBody: reqBodyStr,
      );
      if (onSession != null) {
        onSession!(session);
      }

      final upstreamResponse = await upstreamRequest.close();

      request.response.statusCode = upstreamResponse.statusCode;
      if (upstreamResponse.reasonPhrase.isNotEmpty) {
        request.response.reasonPhrase = upstreamResponse.reasonPhrase;
      }

      final resHeaders = <String, List<String>>{};
      upstreamResponse.headers.forEach((name, values) {
        resHeaders[name] = values;
        if (_isHopByHopHeader(name)) return;
        for (final v in values) {
          try {
            request.response.headers.add(name, v);
          } catch (_) {}
        }
      });

      final responseBytesBuilder = BytesBuilder(copy: false);
      await for (final data in upstreamResponse) {
        responseBytesBuilder.add(data);
        request.response.add(data);
      }
      await request.response.close();

      if (onSession != null) {
        final endTime = DateTime.now();
        final resBytes = responseBytesBuilder.takeBytes();
        String resBodyStr = _decodeBody(resBytes, resHeaders);

        session = session.copyWith(
          statusCode: upstreamResponse.statusCode,
          statusMessage: upstreamResponse.reasonPhrase,
          responseHeaders: resHeaders,
          responseBytes: resBytes.length,
          responseBody: resBodyStr,
          durationMs: endTime.difference(startTime).inMilliseconds,
        );
        onSession!(session);
      }
    } catch (e) {
      
      if (onSession != null) {
        final endTime = DateTime.now();
        session = session.copyWith(
          statusMessage: 'Error',
          error: e.toString(),
          durationMs: endTime.difference(startTime).inMilliseconds,
        );
        onSession!(session);
      }
      try {
        request.response.statusCode = HttpStatus.badGateway;
        request.response.write('Proxy Error: $e');
        await request.response.close();
      } catch (_) {}
    } finally {
      client.close(force: true);
    }
  }

  void _copyHeadersToUpstream(HttpHeaders from, HttpHeaders to) {
    from.forEach((name, values) {
      if (_isHopByHopHeader(name)) return;
      if (name.toLowerCase() == 'accept-encoding') {
        final newValues = values
            .map((v) {
              return v
                  .split(',')
                  .map((s) => s.trim())
                  .where((s) => s != 'br' && s != 'zstd')
                  .join(', ');
            })
            .where((v) => v.isNotEmpty)
            .toList();
        if (newValues.isNotEmpty) {
          for (final v in newValues) {
            try {
              to.add(name, v);
            } catch (_) {}
          }
        }
        return;
      }
      for (final v in values) {
        try {
          to.add(name, v);
        } catch (_) {}
      }
    });
  }

  bool _isHopByHopHeader(String name) {
    final n = name.toLowerCase();
    return n == 'connection' ||
        n == 'proxy-connection' ||
        n == 'keep-alive' ||
        n == 'proxy-authenticate' ||
        n == 'proxy-authorization' ||
        n == 'te' ||
        n == 'trailers' ||
        n == 'transfer-encoding' ||
        n == 'upgrade';
  }

  String _decodeBody(List<int> bytes, Map<String, List<String>> headers) {
    if (bytes.isEmpty) return '';
    try {
      List<int> decodedBytes = bytes;
      final contentEncoding =
          headers['content-encoding']?.join(',').toLowerCase() ?? '';
      if (contentEncoding.contains('gzip')) {
        decodedBytes = gzip.decode(bytes);
      } else if (contentEncoding.contains('deflate')) {
        decodedBytes = zlib.decode(bytes);
      }

      final contentType =
          headers['content-type']?.join(',').toLowerCase() ?? '';
      if (contentType.isEmpty ||
          contentType.contains('text') ||
          contentType.contains('json') ||
          contentType.contains('xml') ||
          contentType.contains('urlencoded') ||
          contentType.contains('javascript')) {
        return utf8.decode(decodedBytes, allowMalformed: true);
      }
      return '<!-- Binary data (${bytes.length} bytes) -->';
    } catch (e) {
      return '<!-- Failed to decode body: $e -->';
    }
  }
}
