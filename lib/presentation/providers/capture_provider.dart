import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../data/network/certificate_manager.dart';
import '../../data/system/system_proxy_service.dart';
import '../../domain/models/capture_session_model.dart';
import '../../domain/models/capture_filter_condition.dart';
import '../../src/rust/api/proxy.dart';
import '../../utils/process_helper.dart';

class CaptureState {
  final bool isRunning;
  final int? port;
  final bool systemProxyEnabled;
  final List<CaptureSessionModel> sessions;
  final String? selectedSessionId;
  final String protocolFilter;
  final String searchText;
  final int maxEntries;
  final String? error;
  final bool proxyConflictWarning;
  final bool isFilterExpanded;
  final List<CaptureFilterCondition> filters;
  final Set<String> selectedApps;
  final Set<String> selectedDomains;

  const CaptureState({
    required this.isRunning,
    required this.port,
    required this.systemProxyEnabled,
    required this.sessions,
    required this.selectedSessionId,
    required this.protocolFilter,
    required this.searchText,
    required this.maxEntries,
    required this.error,
    required this.proxyConflictWarning,
    required this.isFilterExpanded,
    required this.filters,
    required this.selectedApps,
    required this.selectedDomains,
  });

  factory CaptureState.initial() {
    return const CaptureState(
      isRunning: false,
      port: null,
      systemProxyEnabled: false,
      sessions: [],
      selectedSessionId: null,
      protocolFilter: 'All',
      searchText: '',
      maxEntries: 1000,
      error: null,
      proxyConflictWarning: false,
      isFilterExpanded: false,
      filters: [],
      selectedApps: {},
      selectedDomains: {},
    );
  }

  CaptureState copyWith({
    bool? isRunning,
    int? port,
    bool? systemProxyEnabled,
    List<CaptureSessionModel>? sessions,
    String? selectedSessionId,
    String? protocolFilter,
    String? searchText,
    int? maxEntries,
    String? error,
    bool? proxyConflictWarning,
    bool? isFilterExpanded,
    List<CaptureFilterCondition>? filters,
    Set<String>? selectedApps,
    Set<String>? selectedDomains,
  }) {
    return CaptureState(
      isRunning: isRunning ?? this.isRunning,
      port: port ?? this.port,
      systemProxyEnabled: systemProxyEnabled ?? this.systemProxyEnabled,
      sessions: sessions ?? this.sessions,
      selectedSessionId: selectedSessionId ?? this.selectedSessionId,
      protocolFilter: protocolFilter ?? this.protocolFilter,
      searchText: searchText ?? this.searchText,
      maxEntries: maxEntries ?? this.maxEntries,
      error: error,
      proxyConflictWarning: proxyConflictWarning ?? this.proxyConflictWarning,
      isFilterExpanded: isFilterExpanded ?? this.isFilterExpanded,
      filters: filters ?? this.filters,
      selectedApps: selectedApps ?? this.selectedApps,
      selectedDomains: selectedDomains ?? this.selectedDomains,
    );
  }
}

class CaptureNotifier extends StateNotifier<CaptureState> {
  final SystemProxyService _systemProxyService;
  ProxyCore? _proxy;

  CaptureNotifier(this._systemProxyService) : super(CaptureState.initial());

  Future<void> start(
      {int preferredPort = 8888, bool enableSslProxying = false}) async {
    if (state.isRunning) return;

    try {
      final proxy = ProxyCore();
      String? caCert;
      String? caKey;
      if (enableSslProxying) {
        await CertificateManager.instance.initialize();
        caCert = CertificateManager.instance.caCertificatePem;
        caKey = CertificateManager.instance.caKeyPem;
      }
      final config = ProxyConfig(
        port: preferredPort,
        enableSslProxying: enableSslProxying,
        caCert: caCert,
        caKey: caKey,
      );

      final stream = proxy.setupStream();
      stream.listen((session) async {
        String? processId = session.processId;
        String? appName = session.appName;
        String? appPath = session.appPath;
        String? appIconPath;

        if (session.clientPort != null && processId == null) {
          final pInfo = await ProcessHelper.getProcessByPort(session.clientPort!);
          processId = pInfo.processId;
          appName = pInfo.appName;
          appPath = pInfo.appPath;
          appIconPath = pInfo.iconPath;
        }

        // Ignore our own traffic
        if (processId == pid.toString()) {
          return;
        }

        String? serverIp = session.serverIp;
        if (serverIp == null) {
          try {
            final addresses = await InternetAddress.lookup(session.host);
            if (addresses.isNotEmpty) {
              serverIp = addresses.first.address;
            }
          } catch (_) {}
        }

        final model = CaptureSessionModel(
          id: session.id,
          startedAt: DateTime.fromMillisecondsSinceEpoch(session.startedAt),
          protocol: session.protocol,
          method: session.method,
          url: session.url,
          host: session.host,
          port: session.port,
          statusCode: session.statusCode,
          statusMessage: session.statusMessage ?? '',
          durationMs: session.durationMs,
          requestBytes: session.requestBytes,
          responseBytes: session.responseBytes,
          requestHeaders: session.requestHeaders.map((k, v) => MapEntry(k, v)),
          requestBody: session.requestBody,
          responseHeaders:
              session.responseHeaders.map((k, v) => MapEntry(k, v)),
          responseBody: session.responseBody,
          error: session.error,
          clientIp: session.clientIp,
          clientPort: session.clientPort,
          serverIp: serverIp,
          processId: processId,
          appName: appName,
          appPath: appPath,
          appIconPath: appIconPath,
        );
        _onSession(model);
      }, onError: (e) {
        state = state.copyWith(error: e.toString());
      });

      final actualPort = await proxy.start(config: config);
      if (actualPort == 0) {
        throw Exception('Failed to start proxy server');
      }

      _proxy = proxy;
      state = state.copyWith(
        isRunning: true,
        port: actualPort,
        error: null,
      );
    } catch (e) {
      if (preferredPort != 0) {
        await start(preferredPort: 0, enableSslProxying: enableSslProxying);
      } else {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  Future<void> startCapture({
    int preferredPort = 0,
    bool enableSystemProxy = true,
    bool enableSslProxying = false,
  }) async {
    // Check if another proxy is already running
    final isConflict =
        await _systemProxyService.checkOtherProxyEnabled(preferredPort);
    if (isConflict) {
      state = state.copyWith(proxyConflictWarning: true);
    } else {
      state = state.copyWith(proxyConflictWarning: false);
    }

    await start(
        preferredPort: preferredPort, enableSslProxying: enableSslProxying);
    if (!state.isRunning) return;

    if (enableSystemProxy && !state.systemProxyEnabled) {
      await this.enableSystemProxy();
      if (state.error != null) {
        await stop();
      }
    }
  }

  void clearProxyConflictWarning() {
    state = state.copyWith(proxyConflictWarning: false);
  }

  Future<void> stop() async {
    final proxy = _proxy;
    _proxy = null;
    if (proxy != null) {
      await proxy.stop();
    }

    if (state.systemProxyEnabled) {
      await disableSystemProxy();
    }

    state = state.copyWith(
      isRunning: false,
      port: null,
      error: null,
    );
  }

  void clear() {
    state = state.copyWith(sessions: const [], selectedSessionId: null, selectedApps: {}, selectedDomains: {});
  }

  void removeSession(String id) {
    final newList = List<CaptureSessionModel>.from(state.sessions);
    newList.removeWhere((s) => s.id == id);
    String? newSelected = state.selectedSessionId;
    if (newSelected == id) newSelected = null;
    state = state.copyWith(sessions: newList, selectedSessionId: newSelected);
  }

  void select(String? id) {
    state = state.copyWith(selectedSessionId: id);
  }

  void setProtocolFilter(String filter) {
    state = state.copyWith(protocolFilter: filter);
  }

  void setSearchText(String text) {
    state = state.copyWith(searchText: text);
  }

  void toggleFilterExpanded() {
    var newState = state.copyWith(isFilterExpanded: !state.isFilterExpanded);
    if (newState.isFilterExpanded && newState.filters.isEmpty) {
      newState = newState.copyWith(filters: [
        const CaptureFilterCondition(
          field: FilterField.all,
          operator: FilterOperator.contains,
          value: '',
        )
      ]);
    }
    state = newState;
  }

  void addFilter(CaptureFilterCondition filter) {
    state = state.copyWith(filters: [...state.filters, filter]);
  }

  void updateFilter(int index, CaptureFilterCondition filter) {
    final newList = List<CaptureFilterCondition>.from(state.filters);
    if (index >= 0 && index < newList.length) {
      newList[index] = filter;
      state = state.copyWith(filters: newList);
    }
  }

  void removeFilter(int index) {
    final newList = List<CaptureFilterCondition>.from(state.filters);
    if (index >= 0 && index < newList.length) {
      newList.removeAt(index);
      state = state.copyWith(filters: newList);
    }
  }

  void clearFilters() {
    state = state.copyWith(filters: []);
  }

  void toggleAppSelection(String app) {
    final newSet = Set<String>.from(state.selectedApps);
    if (newSet.contains(app)) {
      newSet.remove(app);
    } else {
      newSet.add(app);
    }
    state = state.copyWith(selectedApps: newSet);
  }

  void toggleDomainSelection(String domain) {
    final newSet = Set<String>.from(state.selectedDomains);
    if (newSet.contains(domain)) {
      newSet.remove(domain);
    } else {
      newSet.add(domain);
    }
    state = state.copyWith(selectedDomains: newSet);
  }

  Future<void> enableSystemProxy() async {
    final p = state.port;
    if (!state.isRunning || p == null) {
      state = state.copyWith(error: 'Proxy is not running');
      return;
    }

    try {
      await _systemProxyService.setSystemHttpProxy(host: '127.0.0.1', port: p);
      final verified = await _systemProxyService.isSystemHttpProxyEnabledFor(
        host: '127.0.0.1',
        port: p,
      );
      if (!verified) {
        throw Exception(
          'System proxy verification failed. The UI was not allowed to mark capture as enabled.',
        );
      }
      state = state.copyWith(systemProxyEnabled: true, error: null);
    } catch (e) {
      state = state.copyWith(systemProxyEnabled: false, error: e.toString());
    }
  }

  Future<void> disableSystemProxy() async {
    try {
      await _systemProxyService.clearSystemHttpProxy();
      state = state.copyWith(systemProxyEnabled: false, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> stopCapture() async {
    await stop();
  }

  void _onSession(CaptureSessionModel session) {
    final newList = List<CaptureSessionModel>.from(state.sessions);
    final existingIndex = newList.indexWhere((s) => s.id == session.id);
    if (existingIndex >= 0) {
      newList[existingIndex] = session;
    } else {
      newList.insert(0, session);
      if (newList.length > state.maxEntries) {
        newList.removeRange(state.maxEntries, newList.length);
      }
    }
    state = state.copyWith(
      sessions: newList,
      selectedSessionId: state.selectedSessionId ?? session.id,
    );
  }
}

final captureProvider =
    StateNotifierProvider<CaptureNotifier, CaptureState>((ref) {
  return CaptureNotifier(SystemProxyService());
});

final isCaptureOpenProvider = StateProvider<bool>((ref) => false);
