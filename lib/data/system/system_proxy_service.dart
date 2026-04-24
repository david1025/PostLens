import 'dart:io';

class SystemProxyService {
  Future<void> setSystemHttpProxy(
      {required String host, required int port}) async {
    final proxyServer = '$host:$port';
    if (Platform.isWindows) {
      await _runCommand('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '1',
        '/f'
      ]);
      await _runCommand('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyServer',
        '/t',
        'REG_SZ',
        '/d',
        proxyServer,
        '/f'
      ]);
      await _runCommand('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyOverride',
        '/t',
        'REG_SZ',
        '/d',
        '<local>',
        '/f'
      ]);
      return;
    } else if (Platform.isMacOS) {
      final interfaces = await _getActiveMacInterfaces();
      if (interfaces.isEmpty) {
        throw Exception('No active network interfaces found');
      }
      var appliedToAtLeastOneInterface = false;
      final failures = <String>[];
      for (final iface in interfaces) {
        try {
          await _runCommand(
              'networksetup', ['-setwebproxy', iface, host, port.toString()]);
          await _runCommand('networksetup', ['-setwebproxystate', iface, 'on']);
          await _runCommand('networksetup',
              ['-setsecurewebproxy', iface, host, port.toString()]);
          await _runCommand(
              'networksetup', ['-setsecurewebproxystate', iface, 'on']);

          final matches = await _isExpectedMacProxyEnabled(
            iface: iface,
            host: host,
            port: port,
          );
          appliedToAtLeastOneInterface =
              appliedToAtLeastOneInterface || matches;
        } catch (e) {
          failures.add('$iface: $e');
        }
      }
      if (!appliedToAtLeastOneInterface) {
        final failureDetail =
            failures.isEmpty ? '' : '\n${failures.join('\n')}';
        throw Exception(
          'System proxy was not applied successfully. macOS did not report any network service using $proxyServer.$failureDetail',
        );
      }
      return;
    } else if (Platform.isLinux) {
      // using gsettings for GNOME
      try {
        await _runCommand(
            'gsettings', ['set', 'org.gnome.system.proxy', 'mode', "'manual'"]);
        await _runCommand('gsettings',
            ['set', 'org.gnome.system.proxy.http', 'host', "'$host'"]);
        await _runCommand('gsettings',
            ['set', 'org.gnome.system.proxy.http', 'port', port.toString()]);
        await _runCommand('gsettings',
            ['set', 'org.gnome.system.proxy.https', 'host', "'$host'"]);
        await _runCommand('gsettings',
            ['set', 'org.gnome.system.proxy.https', 'port', port.toString()]);
      } catch (_) {
        // ignore errors on non-gnome systems
      }
      return;
    }
  }

  Future<void> clearSystemHttpProxy() async {
    if (Platform.isWindows) {
      await _runCommand('reg', [
        'add',
        r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
        '/v',
        'ProxyEnable',
        '/t',
        'REG_DWORD',
        '/d',
        '0',
        '/f'
      ]);
      return;
    } else if (Platform.isMacOS) {
      final interfaces = await _getActiveMacInterfaces();
      for (final iface in interfaces) {
        try {
          await _runCommand(
              'networksetup', ['-setwebproxystate', iface, 'off']);
          await _runCommand(
              'networksetup', ['-setsecurewebproxystate', iface, 'off']);
        } catch (_) {
          // Ignore cleanup failures so stop() can still complete.
        }
      }
      return;
    } else if (Platform.isLinux) {
      try {
        await _runCommand(
            'gsettings', ['set', 'org.gnome.system.proxy', 'mode', "'none'"]);
      } catch (_) {}
      return;
    }
  }

  Future<bool> isSystemHttpProxyEnabledFor(
      {required String host, required int port}) async {
    if (Platform.isWindows) {
      try {
        final enabled = await Process.run('reg', [
          'query',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyEnable',
        ]);
        if (!enabled.stdout.toString().contains('0x1')) {
          return false;
        }
        final server = await Process.run('reg', [
          'query',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyServer',
        ]);
        final output = server.stdout.toString();
        return output.contains('$host:$port');
      } catch (_) {
        return false;
      }
    } else if (Platform.isMacOS) {
      final interfaces = await _getActiveMacInterfaces();
      for (final iface in interfaces) {
        if (await _isExpectedMacProxyEnabled(
            iface: iface, host: host, port: port)) {
          return true;
        }
      }
      return false;
    } else if (Platform.isLinux) {
      try {
        final mode = await Process.run(
            'gsettings', ['get', 'org.gnome.system.proxy', 'mode']);
        if (!mode.stdout.toString().contains('manual')) {
          return false;
        }
        final hostResult = await Process.run(
            'gsettings', ['get', 'org.gnome.system.proxy.http', 'host']);
        final portResult = await Process.run(
            'gsettings', ['get', 'org.gnome.system.proxy.http', 'port']);
        return hostResult.stdout.toString().contains(host) &&
            portResult.stdout.toString().contains(port.toString());
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  Future<bool> checkOtherProxyEnabled(int currentPort) async {
    if (Platform.isWindows) {
      try {
        final result = await Process.run('reg', [
          'query',
          r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
          '/v',
          'ProxyEnable'
        ]);
        if (result.stdout.toString().contains('0x1')) {
          final serverResult = await Process.run('reg', [
            'query',
            r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
            '/v',
            'ProxyServer'
          ]);
          final serverStr = serverResult.stdout.toString();
          if (!serverStr.contains('127.0.0.1:$currentPort') &&
              !serverStr.contains('localhost:$currentPort')) {
            return true;
          }
        }
      } catch (_) {}
    } else if (Platform.isMacOS) {
      final interfaces = await _getActiveMacInterfaces();
      for (final iface in interfaces) {
        try {
          final result =
              await Process.run('networksetup', ['-getwebproxy', iface]);
          final output = result.stdout.toString();
          if (output.contains('Enabled: Yes')) {
            if ((!output.contains('127.0.0.1') &&
                    !output.contains('localhost')) ||
                !output.contains(currentPort.toString())) {
              return true;
            }
          }

          final secureResult =
              await Process.run('networksetup', ['-getsecurewebproxy', iface]);
          final secureOutput = secureResult.stdout.toString();
          if (secureOutput.contains('Enabled: Yes')) {
            if ((!secureOutput.contains('127.0.0.1') &&
                    !secureOutput.contains('localhost')) ||
                !secureOutput.contains(currentPort.toString())) {
              return true;
            }
          }
        } catch (_) {}
      }
    } else if (Platform.isLinux) {
      try {
        final result = await Process.run(
            'gsettings', ['get', 'org.gnome.system.proxy', 'mode']);
        if (result.stdout.toString().contains('manual')) {
          final hostResult = await Process.run(
              'gsettings', ['get', 'org.gnome.system.proxy.http', 'host']);
          final portResult = await Process.run(
              'gsettings', ['get', 'org.gnome.system.proxy.http', 'port']);
          final hostStr = hostResult.stdout.toString();
          if ((!hostStr.contains('127.0.0.1') &&
                  !hostStr.contains('localhost')) ||
              !portResult.stdout.toString().contains(currentPort.toString())) {
            return true;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  Future<List<String>> _getActiveMacInterfaces() async {
    try {
      final result =
          await Process.run('networksetup', ['-listallnetworkservices']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        final interfaces = <String>[];
        for (var line in lines) {
          line = line.trim();
          if (line.isEmpty) continue;
          if (line.contains('asterisk') || line.startsWith('*')) continue;
          interfaces.add(line);
        }
        if (interfaces.isNotEmpty) {
          return interfaces;
        }
      }
    } catch (_) {}
    return ['Wi-Fi', 'Ethernet'];
  }

  Future<bool> _isExpectedMacProxyEnabled({
    required String iface,
    required String host,
    required int port,
  }) async {
    try {
      final webProxy =
          await Process.run('networksetup', ['-getwebproxy', iface]);
      final secureProxy =
          await Process.run('networksetup', ['-getsecurewebproxy', iface]);
      return _macProxyOutputMatches(webProxy.stdout.toString(), host, port) ||
          _macProxyOutputMatches(secureProxy.stdout.toString(), host, port);
    } catch (_) {
      return false;
    }
  }

  bool _macProxyOutputMatches(String output, String host, int port) {
    return output.contains('Enabled: Yes') &&
        output.contains('Server: $host') &&
        output.contains('Port: $port');
  }

  Future<void> _runCommand(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(executable, arguments);
      if (result.exitCode != 0) {
        final errorMsg = '${result.stderr}\n${result.stdout}'.trim();
        if (Platform.isMacOS &&
            errorMsg.toLowerCase().contains('you cannot set')) {
          
          return;
        }
        throw Exception(errorMsg);
      }
    } catch (e) {
      throw Exception('Failed to run $executable ${arguments.join(' ')}: $e');
    }
  }
}
