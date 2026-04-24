class HttpResponseModel {
  final int statusCode;
  final String statusMessage;
  final int timeMs;
  final int sizeBytes;
  final String body;
  final Map<String, List<String>> headers;
  final List<Cookie> cookies;
  final List<dynamic>? testResults;

  HttpResponseModel({
    required this.statusCode,
    required this.statusMessage,
    required this.timeMs,
    required this.sizeBytes,
    required this.body,
    required this.headers,
    this.cookies = const [],
    this.testResults,
  });

  factory HttpResponseModel.error(String message) {
    return HttpResponseModel(
      statusCode: 0,
      statusMessage: message,
      timeMs: 0,
      sizeBytes: 0,
      body: message,
      headers: {},
      cookies: [],
      testResults: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'statusMessage': statusMessage,
      'timeMs': timeMs,
      'sizeBytes': sizeBytes,
      'body': body,
      'headers': headers,
      'cookies': cookies.map((c) => c.toJson()).toList(),
      'testResults': testResults,
    };
  }

  factory HttpResponseModel.fromJson(Map<String, dynamic> json) {
    return HttpResponseModel(
      statusCode: json['statusCode'] as int,
      statusMessage: json['statusMessage'] as String,
      timeMs: json['timeMs'] as int,
      sizeBytes: json['sizeBytes'] as int,
      body: json['body'] as String,
      headers: (json['headers'] as Map?)?.map(
            (k, v) => MapEntry(k as String, List<String>.from(v as List)),
          ) ??
          {},
      cookies: (json['cookies'] as List?)
              ?.map((e) => Cookie.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      testResults: json['testResults'] as List<dynamic>?,
    );
  }

  HttpResponseModel copyWith({
    int? statusCode,
    String? statusMessage,
    int? timeMs,
    int? sizeBytes,
    String? body,
    Map<String, List<String>>? headers,
    List<Cookie>? cookies,
    List<dynamic>? testResults,
  }) {
    return HttpResponseModel(
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      timeMs: timeMs ?? this.timeMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      body: body ?? this.body,
      headers: headers ?? this.headers,
      cookies: cookies ?? this.cookies,
      testResults: testResults ?? this.testResults,
    );
  }
}

class Cookie {
  final String name;
  final String value;
  final String domain;
  final String path;
  final String expires;
  final bool httpOnly;
  final bool secure;

  Cookie({
    required this.name,
    required this.value,
    this.domain = '',
    this.path = '/',
    this.expires = 'Session',
    this.httpOnly = false,
    this.secure = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'domain': domain,
      'path': path,
      'expires': expires,
      'httpOnly': httpOnly,
      'secure': secure,
    };
  }

  factory Cookie.fromJson(Map<String, dynamic> json) {
    return Cookie(
      name: json['name'] as String,
      value: json['value'] as String,
      domain: json['domain'] as String? ?? '',
      path: json['path'] as String? ?? '/',
      expires: json['expires'] as String? ?? 'Session',
      httpOnly: json['httpOnly'] as bool? ?? false,
      secure: json['secure'] as bool? ?? false,
    );
  }
}
