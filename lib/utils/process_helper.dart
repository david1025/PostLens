import 'dart:io';
import 'package:flutter/foundation.dart';

class ProcessInfo {
  final String? processId;
  final String? appName;
  final String? appPath;
  final String? iconPath;

  ProcessInfo({this.processId, this.appName, this.appPath, this.iconPath});
}

class ProcessHelper {
  static final Map<String, String?> _iconCache = {};

  static Future<String?> getAppIcon(String exePath) async {
    if (!Platform.isWindows) return null;
    
    if (_iconCache.containsKey(exePath)) {
      return _iconCache[exePath];
    }

    try {
      final safePath = exePath.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      final iconPath = '${Directory.systemTemp.path}\\post_lens_icons\\$safePath.png';
      final iconFile = File(iconPath);
      
      if (await iconFile.exists()) {
        _iconCache[exePath] = iconPath;
        return iconPath;
      }
      
      await iconFile.parent.create(recursive: true);
      
      final safeExePath = exePath.replaceAll("'", "''");
      final safeIconPath = iconPath.replaceAll("'", "''");
      
      final psCommand = '''
        Add-Type -AssemblyName System.Drawing;
        \$icon = [System.Drawing.Icon]::ExtractAssociatedIcon('$safeExePath');
        if (\$icon) {
          \$bmp = \$icon.ToBitmap();
          \$bmp.Save('$safeIconPath', [System.Drawing.Imaging.ImageFormat]::Png);
        }
      ''';
      
      await Process.run('powershell', ['-Command', psCommand]);
      
      if (await iconFile.exists()) {
        _iconCache[exePath] = iconPath;
        return iconPath;
      }
    } catch (e) {
      
    }
    
    _iconCache[exePath] = null;
    return null;
  }

  static final Map<String, ProcessInfo> _pidCache = {};
  static final Map<String, int> _pidCacheTime = {};

  static Future<ProcessInfo> getProcessByPort(int port) async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final result = await Process.run('lsof', ['-i', ':$port', '-t']);
        final pids = result.stdout.toString().trim().split('\n');
        
        // Filter out our own PID so we don't accidentally identify client traffic as our own
        final myPid = pid.toString();
        String? targetPid;
        for (final p in pids) {
          final trimmed = p.trim();
          if (trimmed.isNotEmpty && trimmed != myPid) {
            targetPid = trimmed;
            break;
          }
        }
        
        // Fallback to the first one if we couldn't find another (shouldn't happen for valid client traffic)
        if (targetPid == null && pids.isNotEmpty && pids.first.trim().isNotEmpty) {
          targetPid = pids.first.trim();
        }

        if (targetPid != null) {
          final psResult = await Process.run('ps', ['-p', targetPid, '-o', 'comm=']);
          final appPath = psResult.stdout.toString().trim();
          String appName = appPath;
          if (appPath.contains('/')) {
            appName = appPath.split('/').last;
          }
          return ProcessInfo(
              processId: targetPid, appName: appName, appPath: appPath);
        }
      } else if (Platform.isWindows) {
        final result =
            await Process.run('cmd', ['/c', 'netstat -ano | findstr :$port']);
        final lines = result.stdout.toString().trim().split('\n');
        final myPid = pid.toString();
        for (var line in lines) {
          if (line.contains('ESTABLISHED') || line.contains('LISTENING')) {
            final parts = line.trim().split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              final targetPid = parts.last;
              if (targetPid == myPid) continue;
              
              // Check cache
              final now = DateTime.now().millisecondsSinceEpoch;
              if (_pidCache.containsKey(targetPid)) {
                final cachedTime = _pidCacheTime[targetPid] ?? 0;
                // Cache for 60 seconds
                if (now - cachedTime < 60000) {
                  return _pidCache[targetPid]!;
                }
              }

              // Get full executable path
              String? fullPath;
              try {
                final pathResult = await Process.run('powershell', ['-Command', '(Get-Process -Id $targetPid).Path']);
                final pathStr = pathResult.stdout.toString().trim();
                if (pathStr.isNotEmpty) fullPath = pathStr;
              } catch (_) {}

              final taskResult = await Process.run(
                  'tasklist', ['/FI', 'PID eq $targetPid', '/FO', 'CSV', '/NH']);
              final taskLine = taskResult.stdout.toString().trim();
              if (taskLine.isNotEmpty) {
                final taskParts = taskLine.split('","');
                if (taskParts.isNotEmpty) {
                  final appName = taskParts[0].replaceAll('"', '');
                  
                  String? iconPath;
                  if (fullPath != null) {
                    iconPath = await getAppIcon(fullPath);
                  }
                  
                  final info = ProcessInfo(processId: targetPid, appName: appName, appPath: fullPath, iconPath: iconPath);
                  _pidCache[targetPid] = info;
                  _pidCacheTime[targetPid] = now;
                  return info;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return ProcessInfo();
  }
}
