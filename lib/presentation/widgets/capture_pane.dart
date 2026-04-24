import "capture_pane_widgets.dart";
import 'package:post_lens/core/utils/toast_utils.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/models/capture_session_model.dart';
import '../../domain/models/capture_filter_condition.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/capture_provider.dart';
import '../providers/settings_provider.dart';
import 'certificate_management_dialog.dart';

import '../../data/local/database_helper.dart';

import '../providers/ui_provider.dart';

class CapturePane extends ConsumerStatefulWidget {
  const CapturePane({super.key});

  @override
  ConsumerState<CapturePane> createState() => CapturePaneState();
}

class CapturePaneState extends ConsumerState<CapturePane> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _sidebarSearchController = TextEditingController();
  String _sidebarSearchText = '';
  bool _isCertInstalled = false;

  double _idWidth = 48;
  double _iconWidth = 36;
  double _methodWidth = 64;
  double _appWidth = 120;
  double _statusWidth = 64;
  double _domainWidth = 120;
  double _ipWidth = 120;
  double _durationWidth = 70;
  double _sizeWidth = 70;

  Map<String, String> get t => ref.read(translationsProvider);

  @override
  void initState() {
    super.initState();
    _checkCertInstalled();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _sidebarSearchController.dispose();
    super.dispose();
  }

  Future<void> _checkCertInstalled() async {
    final val = await DatabaseHelper.instance.getKeyValue('cert_installed');
    if (!mounted) return;
    setState(() {
      _isCertInstalled = val == 'true';
    });
  }

  String formatAppName(String? name) {
    if (name == null || name.isEmpty) return '-';
    if (name.toLowerCase().endsWith('.exe')) {
      return name.substring(0, name.length - 4);
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(translationsProvider);
    final state = ref.watch(captureProvider);
    final notifier = ref.read(captureProvider.notifier);
    final settings = ref.watch(networkSettingsProvider);

    final sessions = _filterSessions(state);
    CaptureSessionModel? selected;
    final selectedId = state.selectedSessionId;
    if (selectedId != null) {
      for (final s in state.sessions) {
        if (s.id == selectedId) {
          selected = s;
          break;
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF222427) : const Color(0xFFEDEFF2);

    return Container(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!ref.watch(isCaptureSidebarCollapsedProvider)) ...[
              _buildSidebar(context, state, notifier),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t['capture'] ?? 'Capture',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    state.isRunning
                                        ? '${t['proxy_port'] ?? 'Proxy port'} ${state.port ?? 'Random'}, ${state.systemProxyEnabled ? (t['system_proxy_enabled'] ?? 'System proxy enabled') : (t['system_proxy_disabled'] ?? 'System proxy not enabled')}'
                                        : t['start_capture_hint'] ??
                                            'After clicking start capture, it will automatically start the local proxy and try to enable the system proxy',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildActionButton(
                              label: state.isRunning
                                  ? (t['stop_capture'] ?? 'Stop Capture')
                                  : (t['start_capture'] ?? 'Start Capture'),
                              icon: state.isRunning
                                  ? FontAwesomeIcons.pause
                                  : FontAwesomeIcons.play,
                              color: state.isRunning
                                  ? const Color(0xFFF05050)
                                  : Theme.of(context).colorScheme.primary,
                              onTap: () async {
                                if (state.isRunning) {
                                  await notifier.stopCapture();
                                } else {
                                  await notifier.startCapture(
                                    preferredPort: 0,
                                    enableSystemProxy: true,
                                    enableSslProxying:
                                        settings.enableSslProxying,
                                  );
                                }
                                if (!context.mounted) return;

                                if (ref
                                    .read(captureProvider)
                                    .proxyConflictWarning) {
                                  ref
                                      .read(captureProvider.notifier)
                                      .clearProxyConflictWarning();
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(t['proxy_conflict_title'] ??
                                          'Other Proxy Software Detected'),
                                      content: Text(t[
                                              'proxy_conflict_content'] ??
                                          'The system currently has other proxy software enabled, which may conflict with the packet capture function. It is recommended that you close other proxy software first, and then try again.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: Text(t['got_it'] ?? 'Got it'),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                if (ref.read(captureProvider).error != null) {
                                  ToastUtils.showInfo(context,
                                      ref.read(captureProvider).error!);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              label: state.systemProxyEnabled
                                  ? (t['system_proxy_is_on'] ??
                                      'System proxy is on')
                                  : (t['only_switch_proxy'] ??
                                      'Only switch proxy'),
                              icon: FontAwesomeIcons.networkWired,
                              color: state.systemProxyEnabled
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              onTap: () async {
                                if (!state.isRunning) {
                                  ToastUtils.showInfo(
                                      context,
                                      t['please_start_capture_first'] ??
                                          'Please start capture first');
                                  return;
                                }
                                if (state.systemProxyEnabled) {
                                  await notifier.disableSystemProxy();
                                } else {
                                  await notifier.enableSystemProxy();
                                }
                                if (!context.mounted) return;
                                if (ref.read(captureProvider).error != null) {
                                  ToastUtils.showInfo(context,
                                      ref.read(captureProvider).error!);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildActionButton(
                              label: _isCertInstalled
                                  ? (t['cert_installed'] ?? 'Cert Installed')
                                  : (t['install_root_cert'] ??
                                      'Install Root Cert'),
                              icon: _isCertInstalled
                                  ? FontAwesomeIcons.circleCheck
                                  : FontAwesomeIcons.shieldHalved,
                              color: _isCertInstalled
                                  ? const Color(0xFF2BAE66)
                                  : Colors.orange,
                              onTap: () async {
                                if (!context.mounted) return;
                                final changed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) =>
                                      const CertificateManagementDialog(),
                                );
                                if (changed == true) {
                                  await _checkCertInstalled();
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildIconAction(
                              icon: FontAwesomeIcons.trashCan,
                              tooltip: t['clear'] ?? 'Clear',
                              onTap: notifier.clear,
                            ),
                            const SizedBox(width: 8),
                            _buildIconAction(
                              icon: FontAwesomeIcons.copy,
                              tooltip:
                                  t['copy_current_item'] ?? 'Copy Current Item',
                              onTap: () {
                                final s = selected;
                                if (s == null) return;
                                Clipboard.setData(
                                  ClipboardData(text: _formatSessionAsText(s)),
                                );
                                ToastUtils.showInfo(
                                    context,
                                    t['copied_to_clipboard'] ??
                                        'Copied to clipboard');
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildChip(
                              label: 'All',
                              isActive: state.protocolFilter == 'All',
                              onTap: () => notifier.setProtocolFilter('All'),
                            ),
                            const SizedBox(width: 6),
                            _buildChip(
                              label: 'HTTP',
                              isActive: state.protocolFilter == 'HTTP',
                              onTap: () => notifier.setProtocolFilter('HTTP'),
                            ),
                            const SizedBox(width: 6),
                            _buildChip(
                              label: 'HTTPS',
                              isActive: state.protocolFilter == 'HTTPS',
                              onTap: () => notifier.setProtocolFilter('HTTPS'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 28,
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: notifier.setSearchText,
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: t['search_url_host'] ??
                                        'Search URL / Host',
                                    hintStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        height: 1.2),
                                    prefixIcon: Container(
                                      padding: const EdgeInsets.only(left: 8, right: 0, top: 8, bottom: 8),
                                      child: SvgPicture.asset(
                                        'assets/icons/search.svg',
                                        width: 12,
                                        height: 12,
                                        colorFilter: const ColorFilter.mode(
                                            Colors.grey, BlendMode.srcIn),
                                      ),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 0),
                                  ),
                                  style: const TextStyle(
                                      fontSize: 12, height: 1.2),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildIconAction(
                              icon: FontAwesomeIcons.filter,
                              tooltip:
                                  t['advanced_filter'] ?? 'Advanced Filter',
                              color: state.isFilterExpanded
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              onTap: () => notifier.toggleFilterExpanded(),
                            ),
                            const SizedBox(width: 12),
                            _buildInfoPill(
                              context,
                              state.isRunning
                                  ? (t['listening'] ?? 'Listening')
                                  : (t['not_started'] ?? 'Not started'),
                              state.isRunning
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            _buildInfoPill(
                              context,
                              '${sessions.length} ${t['items_count'] ?? 'items'}',
                              Colors.grey,
                            ),
                          ],
                        ),
                        if (state.isFilterExpanded) ...[
                          const SizedBox(height: 12),
                          _buildFilterArea(context, state, notifier),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: SessionListTable(
                          sessions: sessions,
                          selectedSessionId: state.selectedSessionId,
                          parentState: this,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(
      BuildContext context, CaptureState state, CaptureNotifier notifier) {
    final apps = <String>{};
    final appIcons = <String, String>{};
    final domains = <String>{};

    for (final s in state.sessions) {
      if (s.appName != null && s.appName!.isNotEmpty) {
        final formattedName = formatAppName(s.appName);
        apps.add(formattedName);
        if (s.appIconPath != null) {
          appIcons[formattedName] = s.appIconPath!;
        }
      }
      domains.add(s.host);
    }

    final sortedApps = apps.toList()..sort();
    final sortedDomains = domains.toList()..sort();

    final filteredApps = sortedApps
        .where((app) =>
            app.toLowerCase().contains(_sidebarSearchText.toLowerCase()))
        .toList();
    final filteredDomains = sortedDomains
        .where((domain) =>
            domain.toLowerCase().contains(_sidebarSearchText.toLowerCase()))
        .toList();

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: _sidebarSearchController,
                onChanged: (val) {
                  setState(() {
                    _sidebarSearchText = val;
                  });
                },
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: t['search'] ?? 'Search...',
                  hintStyle: const TextStyle(
                      fontSize: 12, color: Colors.grey, height: 1.2),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1,
                    ),
                  ),
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
                  prefixIcon: Container(
                    padding: const EdgeInsets.only(left: 8, right: 0, top: 8, bottom: 8),
                    child: SvgPicture.asset(
                      'assets/icons/search.svg',
                      width: 12,
                      height: 12,
                      colorFilter: const ColorFilter.mode(
                          Colors.grey, BlendMode.srcIn),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                  ),
                ),
                style: const TextStyle(fontSize: 12, height: 1.2),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                CollapsibleSection(
                  title: t['filter_application'] ?? 'Application',
                  badgeCount: filteredApps.length,
                  initiallyExpanded: true,
                  children: filteredApps.map((app) {
                    final isSelected = state.selectedApps.contains(app);
                    return _buildSidebarItem(
                      context: context,
                      label: app,
                      iconPath: appIcons[app],
                      isSelected: isSelected,
                      onTap: () => notifier.toggleAppSelection(app),
                    );
                  }).toList(),
                ),
                CollapsibleSection(
                  title: t['filter_domain'] ?? 'Domain',
                  badgeCount: filteredDomains.length,
                  initiallyExpanded: true,
                  children: filteredDomains.map((domain) {
                    final isSelected = state.selectedDomains.contains(domain);
                    return _buildSidebarItem(
                      context: context,
                      label: domain,
                      icon: FontAwesomeIcons.cloud,
                      isSelected: isSelected,
                      onTap: () => notifier.toggleDomainSelection(domain),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required BuildContext context,
    required String label,
    String? iconPath,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            if (iconPath != null) ...[
              Image.file(
                File(iconPath),
                width: 14,
                height: 14,
                errorBuilder: (context, error, stackTrace) => const FaIcon(
                    FontAwesomeIcons.windowMaximize,
                    size: 12,
                    color: Colors.blueGrey),
              ),
              const SizedBox(width: 8),
            ] else if (icon != null) ...[
              FaIcon(icon, size: 12, color: Colors.grey),
              const SizedBox(width: 8),
            ] else ...[
              const FaIcon(FontAwesomeIcons.windowMaximize,
                  size: 12, color: Colors.blueGrey),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              FaIcon(FontAwesomeIcons.check,
                  size: 12, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill(BuildContext context, String label, Color color) {
    return Container(
      height: 28,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          height: 1.0,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFilterArea(
      BuildContext context, CaptureState state, CaptureNotifier notifier) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.filters.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(t['no_filters'] ?? 'No filters added yet.',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),
          ...state.filters.asMap().entries.map((e) {
            final index = e.key;
            final filter = e.value;
            return _buildFilterRow(context, index, filter, notifier);
          }),
          const SizedBox(height: 4),
          InkWell(
            onTap: () {
              notifier.addFilter(const CaptureFilterCondition(
                field: FilterField.all,
                operator: FilterOperator.contains,
                value: '',
              ));
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(FontAwesomeIcons.plus,
                      size: 12, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(t['add_filter_condition'] ?? 'Add Filter Condition',
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context, int index,
      CaptureFilterCondition filter, CaptureNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Field Dropdown
          _buildDropdown<FilterField>(
            context,
            value: filter.field,
            items: FilterField.values,
            itemLabel: (f) => _getFilterFieldLabel(f),
            onChanged: (v) {
              if (v != null)
                notifier.updateFilter(index, filter.copyWith(field: v));
            },
            width: 120,
          ),
          const SizedBox(width: 8),
          // Operator Dropdown
          _buildDropdown<FilterOperator>(
            context,
            value: filter.operator,
            items: FilterOperator.values,
            itemLabel: (o) => _getFilterOperatorLabel(o),
            onChanged: (v) {
              if (v != null)
                notifier.updateFilter(index, filter.copyWith(operator: v));
            },
            width: 100,
          ),
          const SizedBox(width: 8),
          // Value Input
          Expanded(
            child: SizedBox(
              height: 28,
              child: TextFormField(
                initialValue: filter.value,
                onChanged: (v) =>
                    notifier.updateFilter(index, filter.copyWith(value: v)),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1,
                    ),
                  ),
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
                ),
                style: const TextStyle(fontSize: 12, height: 1.2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildIconAction(
            icon: FontAwesomeIcons.minus,
            tooltip: t['remove_filter'] ?? 'Remove',
            onTap: () => notifier.removeFilter(index),
          ),
          _buildIconAction(
            icon: FontAwesomeIcons.plus,
            tooltip: t['add_filter'] ?? 'Add',
            onTap: () {
              notifier.addFilter(const CaptureFilterCondition(
                field: FilterField.all,
                operator: FilterOperator.contains,
                value: '',
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    BuildContext context, {
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    required double width,
  }) {
    return PopupMenuButton<T>(
      tooltip: '',
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      splashRadius: 16,
      onSelected: onChanged,
      itemBuilder: (context) => items.map((T e) {
        return PopupMenuItem<T>(
          value: e,
          height: 32,
          child: Text(itemLabel(e), style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      child: Container(
        width: width,
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                itemLabel(value),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const FaIcon(FontAwesomeIcons.chevronDown,
                size: 10, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  String _getFilterFieldLabel(FilterField f) {
    switch (f) {
      case FilterField.all:
        return t['filter_all'] ?? 'All';
      case FilterField.application:
        return t['filter_application'] ?? 'Application';
      case FilterField.domain:
        return t['filter_domain'] ?? 'Domain';
      case FilterField.method:
        return t['filter_method'] ?? 'Method';
      case FilterField.statusCode:
        return t['filter_status_code'] ?? 'Status Code';
      case FilterField.resourceType:
        return t['filter_resource_type'] ?? 'Resource Type';
    }
  }

  String _getFilterOperatorLabel(FilterOperator o) {
    switch (o) {
      case FilterOperator.contains:
        return t['filter_contains'] ?? 'Contains';
      case FilterOperator.equals:
        return t['filter_equals'] ?? 'Equals';
      case FilterOperator.notEquals:
        return t['filter_not_equals'] ?? 'Not Equals';
      case FilterOperator.notContains:
        return t['filter_not_contains'] ?? 'Not Contains';
    }
  }

  List<CaptureSessionModel> _filterSessions(CaptureState state) {
    Iterable<CaptureSessionModel> it = state.sessions;
    if (state.protocolFilter != 'All') {
      it = it.where((s) =>
          s.protocol.toUpperCase() == state.protocolFilter.toUpperCase());
    }
    final q = state.searchText.trim().toLowerCase();
    if (q.isNotEmpty) {
      it = it.where((s) =>
          s.url.toLowerCase().contains(q) || s.host.toLowerCase().contains(q));
    }
    for (final filter in state.filters) {
      if (filter.value.isEmpty) continue;
      it = it.where((s) => _applyFilter(s, filter));
    }
    if (state.selectedApps.isNotEmpty) {
      it = it.where((s) =>
          s.appName != null &&
          state.selectedApps.contains(formatAppName(s.appName)));
    }
    if (state.selectedDomains.isNotEmpty) {
      it = it.where((s) =>
          state.selectedDomains.contains(s.host) ||
          (s.serverIp != null && state.selectedDomains.contains(s.serverIp)));
    }
    return it.toList(growable: false);
  }

  bool _applyFilter(CaptureSessionModel s, CaptureFilterCondition filter) {
    String targetValue = '';
    
    if (filter.field == FilterField.all) {
      final filterValue = filter.value.toLowerCase();
      if (filterValue.isEmpty) return true;
      
      final checks = [
        formatAppName(s.appName),
        s.host,
        s.method,
        s.statusCode?.toString() ?? '',
        _getResourceType(s),
        s.url,
      ];
      
      bool matches = filter.operator == FilterOperator.notEquals || filter.operator == FilterOperator.notContains;
      for (final c in checks) {
        final target = c.toLowerCase();
        if (filter.operator == FilterOperator.contains && target.contains(filterValue)) return true;
        if (filter.operator == FilterOperator.equals && target == filterValue) return true;
        if (filter.operator == FilterOperator.notContains && target.contains(filterValue)) return false;
        if (filter.operator == FilterOperator.notEquals && target == filterValue) return false;
      }
      return matches;
    }

    switch (filter.field) {
      case FilterField.all:
        break; // Handled above
      case FilterField.application:
        targetValue = formatAppName(s.appName);
        break;
      case FilterField.domain:
        targetValue = s.host;
        break;
      case FilterField.method:
        targetValue = s.method;
        break;
      case FilterField.statusCode:
        targetValue = s.statusCode?.toString() ?? '';
        break;
      case FilterField.resourceType:
        targetValue = _getResourceType(s);
        break;
    }

    targetValue = targetValue.toLowerCase();
    final filterValue = filter.value.toLowerCase();

    switch (filter.operator) {
      case FilterOperator.contains:
        return targetValue.contains(filterValue);
      case FilterOperator.equals:
        return targetValue == filterValue;
      case FilterOperator.notEquals:
        return targetValue != filterValue;
      case FilterOperator.notContains:
        return !targetValue.contains(filterValue);
    }
    return false;
  }

  Widget buildResourceIcon(CaptureSessionModel s) {
    final type = _getResourceType(s);
    switch (type) {
      case 'api':
        return const Text('{}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey));
      case 'js':
        return const Text('JS',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey));
      case 'css':
        return const Text('CSS',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey));
      case 'image':
        return const FaIcon(FontAwesomeIcons.image,
            size: 12, color: Colors.grey);
      case 'html':
        return const FaIcon(FontAwesomeIcons.globe,
            size: 12, color: Colors.grey);
      case 'media':
        return const FaIcon(FontAwesomeIcons.circlePlay,
            size: 12, color: Colors.grey);
      case 'file':
      default:
        return const FaIcon(FontAwesomeIcons.bullseye,
            size: 12, color: Colors.grey);
    }
  }

  String _getResourceType(CaptureSessionModel s) {
    final contentType = s.responseHeaders['content-type']?.join(';') ??
        s.requestHeaders['content-type']?.join(';') ??
        '';
    final urlLower = s.url.toLowerCase();

    if (contentType.contains('application/json') ||
        contentType.contains('application/xml') ||
        contentType.contains('text/xml')) {
      return 'api';
    } else if (contentType.contains('text/css') || urlLower.endsWith('.css')) {
      return 'css';
    } else if (contentType.contains('javascript') || urlLower.endsWith('.js')) {
      return 'js';
    } else if (contentType.contains('image/')) {
      return 'image';
    } else if (contentType.contains('text/html')) {
      return 'html';
    } else if (contentType.contains('audio/') ||
        contentType.contains('video/')) {
      return 'media';
    } else {
      return 'file';
    }
  }

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void showContextMenu(
      BuildContext context, CaptureSessionModel s, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          position.dx, position.dy, position.dx, position.dy),
      constraints: const BoxConstraints(minWidth: 160),
      items: <PopupMenuEntry>[
        PopupMenuItem(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(t['copy_curl'] ?? 'Copy cURL',
              style: const TextStyle(fontSize: 12)),
          onTap: () {
            Clipboard.setData(ClipboardData(text: _generateCurl(s)));
            ToastUtils.showInfo(context, t['curl_copied'] ?? 'cURL copied');
          },
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(t['view_details'] ?? 'View Details',
              style: const TextStyle(fontSize: 12)),
          onTap: () {
            Future.delayed(Duration.zero, () {
              showDetailsDialog(context, s);
            });
          },
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(t['delete'] ?? 'Delete',
              style: TextStyle(fontSize: 12, color: Colors.red)),
          onTap: () {
            ref.read(captureProvider.notifier).removeSession(s.id);
          },
        ),
      ],
    );
  }

  String _generateCurl(CaptureSessionModel s) {
    final b = StringBuffer('curl -X ${s.method} "${s.url}"');
    s.requestHeaders.forEach((k, v) {
      for (final vv in v) {
        b.write(' -H "$k: $vv"');
      }
    });
    if (s.requestBody.isNotEmpty) {
      final body = s.requestBody.replaceAll('"', '\\"');
      b.write(' -d "$body"');
    }
    return b.toString();
  }

  void showDetailsDialog(BuildContext context, CaptureSessionModel s) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: Container(
            width: 900,
            height: 700,
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t['request_and_response'] ?? 'Request & Response',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildDetails(context, s, isDialog: true),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _buildDetails(BuildContext context, CaptureSessionModel s,
      {bool isDialog = false}) {
    return Column(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.method,
                  style: TextStyle(
                      fontSize: 12,
                      color: methodColor(s.method),
                      fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  s.url,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                s.statusCode?.toString() ?? '-',
                style:
                    TextStyle(fontSize: 12, color: statusColor(s.statusCode)),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildRequestPane(context, s),
              ),
              Container(
                width: 1,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: _buildResponsePane(context, s),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRequestPane(BuildContext context, CaptureSessionModel s) {
    final int headerCount =
        s.requestHeaders.values.fold(0, (sum, list) => sum + list.length);
    final contentType = s.requestHeaders['content-type']?.join(';') ?? '';
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            labelColor: Theme.of(context).textTheme.bodyMedium?.color,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 2.0,
            tabs: [
              Tab(text: t['overview_tab'] ?? 'Overview'),
              Tab(text: t['raw_tab'] ?? 'Raw'),
              Tab(text: '${t['headers_tab'] ?? 'Headers'}($headerCount)'),
              Tab(text: t['body_tab'] ?? 'Body'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOverview(context, s),
                _buildRawRequest(context, s),
                _buildHeadersTable(context, s.requestHeaders),
                _buildBodyView(context, s.requestBody,
                    emptyHint: s.method == 'CONNECT'
                        ? (t['connect_tunnel_no_body'] ??
                            'CONNECT tunnel has no readable request body')
                        : (t['no_request_body'] ?? 'No Request Body'),
                    isRequest: true,
                    contentType: contentType),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsePane(BuildContext context, CaptureSessionModel s) {
    final int headerCount =
        s.responseHeaders.values.fold(0, (sum, list) => sum + list.length);
    final contentType = s.responseHeaders['content-type']?.join(';') ?? '';
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            labelColor: Theme.of(context).textTheme.bodyMedium?.color,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 2.0,
            tabs: [
              Tab(text: t['raw_tab'] ?? 'Raw'),
              Tab(
                  text:
                      '${t['response_headers'] ?? 'Response Headers'}($headerCount)'),
              Tab(text: t['response_body'] ?? 'Response Body'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRawResponse(context, s),
                _buildHeadersTable(context, s.responseHeaders),
                _buildBodyView(context, s.responseBody,
                    emptyHint: s.method == 'CONNECT'
                        ? (t['https_not_decrypted'] ??
                            'HTTPS content not decrypted (currently in tunnel mode)')
                        : (t['no_response_body'] ?? 'No Response Body'),
                    isRequest: false,
                    contentType: contentType),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(BuildContext context, CaptureSessionModel s) {
    final contentType = s.responseHeaders['content-type']?.join('; ') ??
        s.requestHeaders['content-type']?.join('; ') ??
        '-';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              _buildOverviewRow(
                  t['status'] ?? 'Status',
                  s.error != null
                      ? 'Error'
                      : (s.statusCode != null ? 'Completed' : 'Pending')),
              _buildOverviewRow(t['method'] ?? 'Method', s.method),
              _buildOverviewRow(
                  t['protocol'] ?? 'Protocol', s.protocol.toUpperCase()),
              _buildOverviewRow('Code', s.statusCode?.toString() ?? '-'),
              _buildOverviewRow(t['server_address'] ?? 'Server Address',
                  '${s.host}:${s.port}'),
              _buildOverviewRow(
                  'Keep Alive',
                  s.requestHeaders['connection']?.contains('keep-alive') == true
                      ? 'true'
                      : '-'),
              _buildOverviewRow(t['stream'] ?? 'Stream', '-'),
              _buildOverviewRow('Content Type', contentType),
              _buildOverviewRow(
                  t['proxy_protocol'] ?? 'Proxy Protocol', s.protocol),
            ],
          ),
        ),
        CollapsibleSection(
          title: t['application'] ?? 'Application',
          children: [
            _buildOverviewRow(t['name'] ?? 'Name', formatAppName(s.appName)),
            _buildOverviewRow('ID', '-'),
            _buildOverviewRow(t['path'] ?? 'Path', s.appPath ?? '-'),
            _buildOverviewRow(
                t['process_id'] ?? 'Process ID', s.processId ?? '-'),
          ],
        ),
        CollapsibleSection(
          title: t['connection'] ?? 'Connection',
          children: [
            _buildOverviewRow('ID', s.id),
            _buildOverviewRow(t['time'] ?? 'Time', s.startedAt.toString()),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(t['frontend'] ?? 'Frontend',
                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
            _buildOverviewRow(t['client_address'] ?? '- Client Address',
                s.clientIp ?? 'Unknown'),
            _buildOverviewRow(t['client_port'] ?? '- Client Port',
                s.clientPort?.toString() ?? '-'),
            _buildOverviewRow(
                t['server_address_sub'] ?? '- Server Address', '127.0.0.1'),
            _buildOverviewRow(t['server_port'] ?? '- Server Port', '-'),
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(t['backend'] ?? 'Backend',
                    style: const TextStyle(fontSize: 12, color: Colors.grey))),
            _buildOverviewRow(
                t['client_address'] ?? '- Client Address', 'Unknown'),
            _buildOverviewRow(t['client_port'] ?? '- Client Port', '-'),
            _buildOverviewRow(t['server_address_sub'] ?? '- Server Address',
                s.serverIp ?? s.host),
            _buildOverviewRow(
                t['server_port'] ?? '- Server Port', s.port.toString()),
          ],
        ),
        CollapsibleSection(
          title: 'TLS',
          children: [
            _buildOverviewRow(t['version'] ?? 'Version',
                s.protocol == 'https' ? 'TLS (Encrypted)' : '-'),
            _buildOverviewRow('SNI', s.protocol == 'https' ? s.host : '-'),
            _buildOverviewRow('ALPN', '-'),
            _buildOverviewRow(t['select_alpn'] ?? 'Select ALPN', '-'),
            _buildOverviewRow(
                t['cipher_suite_list'] ?? 'Cipher Suite List', '-'),
            _buildOverviewRow(
                t['select_cipher_suite'] ?? 'Select Cipher Suite', '-'),
          ],
        ),
        CollapsibleSection(
          title: t['time'] ?? 'Time',
          children: [
            _buildOverviewRow(
                t['request_start'] ?? 'Request Start', s.startedAt.toString()),
            _buildOverviewRow(t['request_end'] ?? 'Request End', '-'),
            _buildOverviewRow(t['request_duration'] ?? 'Request Duration', '-'),
            _buildOverviewRow(t['response_start'] ?? 'Response Start', '-'),
            _buildOverviewRow(t['response_end'] ?? 'Response End', '-'),
            _buildOverviewRow(
                t['response_duration'] ?? 'Response Duration', '-'),
            _buildOverviewRow(
                t['total_duration'] ?? 'Total Duration', '${s.durationMs}ms'),
          ],
        ),
        CollapsibleSection(
          title: t['size'] ?? 'Size',
          children: [
            _buildOverviewRow(
                t['request'] ?? 'Request', formatSize(s.requestBytes)),
            _buildOverviewRow(t['request_headers'] ?? '- Request Headers', '-'),
            _buildOverviewRow(t['request_body_sub'] ?? '- Request Body', '-'),
            _buildOverviewRow(
                t['response'] ?? 'Response', formatSize(s.responseBytes)),
            _buildOverviewRow(
                t['response_headers_sub'] ?? '- Response Headers', '-'),
            _buildOverviewRow(t['response_body_sub'] ?? '- Response Body', '-'),
            _buildOverviewRow(t['total'] ?? 'Total',
                formatSize(s.requestBytes + s.responseBytes)),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(
              child:
                  SelectableText(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildRawRequest(BuildContext context, CaptureSessionModel s) {
    final spans = <TextSpan>[];
    Uri uri;
    try {
      uri = Uri.parse(s.url);
    } catch (_) {
      uri = Uri(path: s.url);
    }
    String path = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    if (path.isEmpty) path = '/';

    // Method and URL
    spans.add(TextSpan(
        text: '${s.method} ',
        style: const TextStyle(
            color: Color(0xFFC678DD), fontWeight: FontWeight.bold)));
    spans.add(
        TextSpan(text: path, style: const TextStyle(color: Color(0xFF98C379))));
    spans.add(const TextSpan(
        text: ' HTTP/1.1\n', style: TextStyle(color: Color(0xFF61AFEF))));

    // Headers
    s.requestHeaders.forEach((k, v) {
      for (final vv in v) {
        spans.add(TextSpan(
            text: '$k: ',
            style: const TextStyle(
                color: Color(0xFF98C379), fontWeight: FontWeight.bold)));
        spans.add(TextSpan(text: '$vv\n'));
      }
    });

    spans.add(const TextSpan(text: '\n'));

    // Body
    if (s.requestBody.isNotEmpty) {
      spans.add(TextSpan(text: s.requestBody));
    }

    return _highlightedCodeBlock(context, spans);
  }

  Widget _buildRawResponse(BuildContext context, CaptureSessionModel s) {
    final spans = <TextSpan>[];

    // Status line
    spans.add(const TextSpan(
        text: 'HTTP/1.1 ',
        style:
            TextStyle(color: Color(0xFF61AFEF), fontWeight: FontWeight.bold)));
    final statusColor = s.statusCode != null && s.statusCode! >= 400
        ? const Color(0xFFE06C75)
        : const Color(0xFF98C379);
    spans.add(TextSpan(
        text: '${s.statusCode ?? 200} ',
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)));
    spans.add(TextSpan(
        text: '${s.statusMessage ?? ''}\n',
        style: TextStyle(color: statusColor)));

    // Headers
    s.responseHeaders.forEach((k, v) {
      for (final vv in v) {
        spans.add(TextSpan(
            text: '$k: ',
            style: const TextStyle(
                color: Color(0xFF98C379), fontWeight: FontWeight.bold)));
        spans.add(TextSpan(text: '$vv\n'));
      }
    });

    spans.add(const TextSpan(text: '\n'));

    // Body
    if (s.responseBody.isNotEmpty) {
      spans.add(TextSpan(text: s.responseBody));
    }

    return _highlightedCodeBlock(context, spans);
  }

  Widget _highlightedCodeBlock(BuildContext context, List<TextSpan> spans) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        child: SelectableText.rich(
          TextSpan(children: spans),
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
            fontSize: 12,
            height: 1.5,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildHeadersTable(
      BuildContext context, Map<String, List<String>> headers) {
    if (headers.isEmpty) {
      return Center(
        child: Text(t['no'] ?? 'No',
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }

    final rows = <TableRow>[];
    headers.forEach((k, v) {
      for (final vv in v) {
        rows.add(TableRow(
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: Theme.of(context).dividerColor.withOpacity(0.5))),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SelectableText(k,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SelectableText(vv, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ));
      }
    });

    return SingleChildScrollView(
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        children: rows,
      ),
    );
  }

  Widget _buildBodyView(BuildContext context, String body,
      {required String emptyHint,
      required bool isRequest,
      required String contentType}) {
    if (body.isEmpty) {
      return Center(
        child: Text(emptyHint,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
      );
    }
    return BodyTabsView(
      body: body,
      isRequest: isRequest,
      contentType: contentType,
    );
  }

  Widget _codeBlock(BuildContext context, String text) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(12),
        width: double.infinity,
        child: SelectableText(
          text,
          style: TextStyle(
            fontFamily: 'IBMPlexMono',
            fontFamilyFallback: const ['Monaco', 'Courier New', 'monospace'],
            fontSize: 12,
            height: 1.5,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        t['select_request_view_details'] ?? 'Select a request to view details',
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }

  Widget _buildChip(
      {required String label,
      required bool isActive,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.secondary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isActive
                  ? Theme.of(context).colorScheme.secondary.withOpacity(0.35)
                  : Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              height: 1.0,
              color: isActive
                  ? Theme.of(context).textTheme.bodyMedium?.color
                  : Colors.grey),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 28,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            FaIcon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, height: 1.0, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildIconAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: FaIcon(icon, size: 12, color: color ?? Colors.grey),
        ),
      ),
    );
  }

  Color statusColor(int? code) {
    if (code == null) return Colors.grey;
    if (code >= 200 && code < 300) return const Color(0xFF2BAE66);
    if (code >= 300 && code < 400) return const Color(0xFFB8860B);
    return const Color(0xFFF05050);
  }

  Color methodColor(String method) {
    final m = method.toUpperCase();
    if (m == 'GET') return const Color(0xFF2BAE66);
    if (m == 'POST') return const Color(0xFF3B82F6);
    if (m == 'PUT' || m == 'PATCH') return const Color(0xFFB8860B);
    if (m == 'DELETE') return const Color(0xFFF05050);
    if (m == 'CONNECT') return const Color(0xFF7C3AED);
    return Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
  }

  String _formatSessionAsText(CaptureSessionModel s) {
    final b = StringBuffer();
    b.writeln('${s.method} ${s.url}');
    if (s.requestHeaders.isNotEmpty) {
      b.writeln();
      b.writeln('Request Headers:');
      s.requestHeaders.forEach((k, v) {
        for (final vv in v) {
          b.writeln('$k: $vv');
        }
      });
    }
    if (s.requestBody.isNotEmpty) {
      b.writeln();
      b.writeln('Request Body:');
      b.writeln(s.requestBody);
    }
    if (s.responseHeaders.isNotEmpty) {
      b.writeln();
      b.writeln('Response Headers:');
      s.responseHeaders.forEach((k, v) {
        for (final vv in v) {
          b.writeln('$k: $vv');
        }
      });
    }
    if (s.responseBody.isNotEmpty) {
      b.writeln();
      b.writeln('Response Body:');
      b.writeln(s.responseBody);
    }
    if (s.error != null && s.error!.isNotEmpty) {
      b.writeln();
      b.writeln('Error: ${s.error}');
    }
    return b.toString();
  }
}

