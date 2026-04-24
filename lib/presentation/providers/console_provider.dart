import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/console_log.dart';

class ConsoleNotifier extends StateNotifier<List<ConsoleLog>> {
  ConsoleNotifier() : super([]);

  void addLog(String message, LogLevel level) {
    final log = ConsoleLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_${state.length}',
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );
    state = [...state, log];
  }

  void addNetworkLog({
    required String method,
    required String url,
    required int statusCode,
    String? statusMessage,
    Map<String, List<String>>? requestHeaders,
    String? requestBody,
    Map<String, List<String>>? responseHeaders,
    String? responseBody,
    String? proxyInfo,
    int? durationMs,
  }) {
    final log = ConsoleLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_${state.length}',
      message: '$method $url - $statusCode${durationMs != null ? ' ${durationMs}ms' : ''}',
      level: LogLevel.network,
      timestamp: DateTime.now(),
      method: method,
      url: url,
      statusCode: statusCode,
      statusMessage: statusMessage,
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      responseHeaders: responseHeaders,
      responseBody: responseBody,
      proxyInfo: proxyInfo,
      durationMs: durationMs,
    );
    state = [...state, log];
  }

  void addNetworkErrorLog({
    required String method,
    required String url,
    required String errorMessage,
    Map<String, List<String>>? requestHeaders,
    String? requestBody,
    String? proxyInfo,
  }) {
    final log = ConsoleLog(
      id: '${DateTime.now().millisecondsSinceEpoch}_${state.length}',
      message: '$method $url\n$errorMessage',
      level: LogLevel.network,
      timestamp: DateTime.now(),
      method: method,
      url: url,
      statusCode: null,
      statusMessage: errorMessage,
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      proxyInfo: proxyInfo,
    );
    state = [...state, log];
  }

  void clearLogs() {
    state = [];
  }
}

final consoleProvider =
    StateNotifierProvider<ConsoleNotifier, List<ConsoleLog>>((ref) {
  return ConsoleNotifier();
});

final isConsoleOpenProvider = StateProvider<bool>((ref) => false);
