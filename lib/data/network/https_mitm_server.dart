import 'dart:io';
import 'certificate_manager.dart';

class HttpsMitmServer {
  final int port;
  final Function(HttpRequest request, String id, DateTime startedAt,
      Stopwatch stopwatch) onHttpRequest;
  final Function(String error)? onError;
  HttpServer? _server;

  HttpsMitmServer({
    required this.port,
    required this.onHttpRequest,
    this.onError,
  });

  Future<void> start() async {
    if (_server != null) return;

    try {
      final certManager = CertificateManager.instance;
      // Start a generic secure server without context initially?
      // Actually dart HttpServer.bindSecure requires a default context.
      // We will create a default context for 'localhost' and use SNI callback.
      final defaultContext =
          await certManager.getCertificateForDomain('localhost');

      final server = await HttpServer.bindSecure(
        InternetAddress.loopbackIPv4,
        port,
        defaultContext,
      );

      _server = server;

      // Use SNI to serve domain-specific certificates dynamically
      // Dart's HttpServer does not expose SNI callbacks directly in older versions,
      // but it does have `request.connectionInfo` after handshake.
      // Wait, dart's HttpServer does not support dynamic SNI context switching per request out of the box in `bindSecure`.
      // It supports `SecurityContext.setAlpnProtocols` but not SNI callback to return different certs.
      // Wait, since Dart 2.x `SecureServerSocket.bind` doesn't have an SNI callback parameter.
      // Wait, we CANNOT use HttpServer.bindSecure for MITM if it doesn't support SNI.
      // BUT we can accept raw sockets and do `SecureSocket.secureServer(socket, context)` AFTER parsing the TLS ClientHello SNI.
    } catch (e) {
      onError?.call(e.toString());
    }
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }
}
