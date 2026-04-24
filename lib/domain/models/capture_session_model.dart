class CaptureSessionModel {
  final String id;
  final DateTime startedAt;
  final String protocol;
  final String method;
  final String url;
  final String host;
  final int port;
  final int? statusCode;
  final String? statusMessage;
  final int durationMs;
  final int requestBytes;
  final int responseBytes;
  final Map<String, List<String>> requestHeaders;
  final String requestBody;
  final Map<String, List<String>> responseHeaders;
  final String responseBody;
  final String? error;
  final String? clientIp;
  final int? clientPort;
  final String? serverIp;
  final String? processId;
  final String? appName;
  final String? appPath;
  final String? appIconPath;

  const CaptureSessionModel({
    required this.id,
    required this.startedAt,
    required this.protocol,
    required this.method,
    required this.url,
    required this.host,
    required this.port,
    required this.statusCode,
    required this.statusMessage,
    required this.durationMs,
    required this.requestBytes,
    required this.responseBytes,
    required this.requestHeaders,
    required this.requestBody,
    required this.responseHeaders,
    required this.responseBody,
    required this.error,
    this.clientIp,
    this.clientPort,
    this.serverIp,
    this.processId,
    this.appName,
    this.appPath,
    this.appIconPath,
  });

  CaptureSessionModel copyWith({
    DateTime? startedAt,
    String? protocol,
    String? method,
    String? url,
    String? host,
    int? port,
    int? statusCode,
    String? statusMessage,
    int? durationMs,
    int? requestBytes,
    int? responseBytes,
    Map<String, List<String>>? requestHeaders,
    String? requestBody,
    Map<String, List<String>>? responseHeaders,
    String? responseBody,
    String? error,
    String? clientIp,
    int? clientPort,
    String? serverIp,
    String? processId,
    String? appName,
    String? appPath,
    String? appIconPath,
  }) {
    return CaptureSessionModel(
      id: id,
      startedAt: startedAt ?? this.startedAt,
      protocol: protocol ?? this.protocol,
      method: method ?? this.method,
      url: url ?? this.url,
      host: host ?? this.host,
      port: port ?? this.port,
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      durationMs: durationMs ?? this.durationMs,
      requestBytes: requestBytes ?? this.requestBytes,
      responseBytes: responseBytes ?? this.responseBytes,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: requestBody ?? this.requestBody,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      error: error ?? this.error,
      clientIp: clientIp ?? this.clientIp,
      clientPort: clientPort ?? this.clientPort,
      serverIp: serverIp ?? this.serverIp,
      processId: processId ?? this.processId,
      appName: appName ?? this.appName,
      appPath: appPath ?? this.appPath,
      appIconPath: appIconPath ?? this.appIconPath,
    );
  }
}
