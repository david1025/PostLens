enum LogLevel { log, info, warning, error, network }

class ConsoleLog {
  final String id;
  final String message;
  final LogLevel level;
  final DateTime timestamp;
  final String? method;
  final String? url;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, List<String>>? requestHeaders;
  final String? requestBody;
  final Map<String, List<String>>? responseHeaders;
  final String? responseBody;
  final String? proxyInfo;
  final int? durationMs;

  ConsoleLog({
    required this.id,
    required this.message,
    required this.level,
    required this.timestamp,
    this.method,
    this.url,
    this.statusCode,
    this.statusMessage,
    this.requestHeaders,
    this.requestBody,
    this.responseHeaders,
    this.responseBody,
    this.proxyInfo,
    this.durationMs,
  });

  bool get isNetworkLog => level == LogLevel.network;

  ConsoleLog copyWith({
    String? id,
    String? message,
    LogLevel? level,
    DateTime? timestamp,
    String? method,
    String? url,
    int? statusCode,
    String? statusMessage,
    Map<String, List<String>>? requestHeaders,
    String? requestBody,
    Map<String, List<String>>? responseHeaders,
    String? responseBody,
    String? proxyInfo,
    int? durationMs,
  }) {
    return ConsoleLog(
      id: id ?? this.id,
      message: message ?? this.message,
      level: level ?? this.level,
      timestamp: timestamp ?? this.timestamp,
      method: method ?? this.method,
      url: url ?? this.url,
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: requestBody ?? this.requestBody,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      proxyInfo: proxyInfo ?? this.proxyInfo,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}
