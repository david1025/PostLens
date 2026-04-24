import 'package:post_lens/core/utils/toast_utils.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'shortcuts_data.dart';
import '../providers/settings_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/request_provider.dart';
import '../../data/local/import_export_service.dart';
import 'package:post_lens/presentation/widgets/common/custom_controls.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const SettingsDialog({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  late int _selectedTabIndex;
  late TextEditingController _timeoutController;
  late TextEditingController _maxSizeController;
  late TextEditingController _proxyUrlController;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
    final settings = ref.read(networkSettingsProvider);
    _timeoutController =
        TextEditingController(text: settings.requestTimeout.toString());
    _maxSizeController =
        TextEditingController(text: settings.maxResponseSize.toString());
    _proxyUrlController = TextEditingController(text: settings.customProxyUrl);
  }

  @override
  void dispose() {
    _timeoutController.dispose();
    _maxSizeController.dispose();
    _proxyUrlController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getTabs(Map<String, String> t) {
    return [
      {'title': t['general'] ?? 'General', 'icon': FontAwesomeIcons.gear, 'key': 'General'},
      {'title': t['themes'] ?? 'Themes', 'icon': FontAwesomeIcons.palette, 'key': 'Themes'},
      {'title': t['shortcuts'] ?? 'Shortcuts', 'icon': FontAwesomeIcons.keyboard, 'key': 'Shortcuts'},
      {'title': t['data'] ?? 'Data', 'icon': FontAwesomeIcons.database, 'key': 'Data'},
      {'title': t['proxy'] ?? 'Proxy', 'icon': FontAwesomeIcons.networkWired, 'key': 'Proxy'},
      {'title': t['about'] ?? 'About', 'icon': FontAwesomeIcons.circleInfo, 'key': 'About'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final tabs = _getTabs(t);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 880,
        height: 720,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Sidebar
            Container(
              width: 220,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8)),
                border: Border(
                    right: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: ListView.builder(
                itemCount: tabs.length,
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  final isSelected = _selectedTabIndex == index;
                  return InkWell(
                    onTap: () => setState(() => _selectedTabIndex = index),
                    borderRadius: BorderRadius.circular(8.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.grey.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        children: [
                          Icon(tab['icon'],
                              size: 14,
                              color: isSelected
                                  ? Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .color
                                  : Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            tab['title'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected
                                  ? Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .color
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Main Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 24, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tabs[_selectedTabIndex]['title'],
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const FaIcon(FontAwesomeIcons.xmark,
                                size: 20, color: Colors.grey),
                            onPressed: () => Navigator.of(context).pop(),
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // Content Scroll View
                    Expanded(
                      child: _buildTabContent(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    final t = ref.watch(translationsProvider);
    final tabs = _getTabs(t);
    final key = tabs[_selectedTabIndex]['key'];
    switch (key) {
      case 'General':
        return _buildGeneralTab();
      case 'Themes':
        return _buildThemesTab();
      case 'Shortcuts':
        return _buildShortcutsTab();
      case 'Data':
        return _buildDataTab();
      case 'Proxy':
        return _buildProxyTab();
      case 'About':
        return _buildAboutTab();
      default:
        return Center(
            child: Text(t['under_construction'] ?? 'Under construction...',
                style: const TextStyle(color: Colors.grey, fontSize: 12)));
    }
  }

  Widget _buildShortcutsTab() {
    final t = ref.watch(translationsProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        Text(t['keyboard_shortcuts'] ?? 'Keyboard Shortcuts',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ...shortcutCategories.expand((category) {
          return [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                category.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            ...category.items.map((item) {
              return Column(
                children: [
                  _buildSettingRow(
                    title: item.title,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: item.keys.map((k) {
                        if (k == 'through') {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(t['through'] ?? 'through',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          );
                        }
                        return _buildKeycap(k);
                      }).toList(),
                    ),
                  ),
                  _buildDivider(),
                ],
              );
            }),
            const SizedBox(height: 16),
          ];
        }),
      ],
    );
  }

  Widget _buildKeycap(String keyText) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        keyText,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'IBMPlexMono',
          color: Colors.grey,
        ),
      ),
    );
  }

  void _exportData() async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Data',
      fileName: 'post_lens_export.json',
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
    );

    if (outputFile != null) {
      try {
        final collections = ref.read(collectionsProvider);
        final history = ref.read(historyProvider);
        final data = ExportData(collections: collections, history: history);

        if (outputFile.endsWith('.csv')) {
          await ImportExportService.exportToCsv(outputFile, data);
        } else {
          // If no extension provided or something else, default to json
          final path =
              outputFile.endsWith('.json') ? outputFile : '$outputFile.json';
          await ImportExportService.exportToJson(path, data);
        }

        if (mounted) {
          ToastUtils.showInfo(context, 'Data exported successfully!');
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showInfo(context, 'Failed to export data: $e');
        }
      }
    }
  }

  void _importData() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Import Data',
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      try {
        ExportData data;
        if (file.path.endsWith('.csv')) {
          data = await ImportExportService.importFromCsv(file.path);
        } else {
          data = await ImportExportService.importFromJson(file.path);
        }

        final collectionNotifier = ref.read(collectionsProvider.notifier);
        for (var collection in data.collections) {
          await collectionNotifier.addCollection(collection);
        }

        final historyNotifier = ref.read(historyProvider.notifier);
        for (var req in data.history) {
          await historyNotifier.addHistory(req);
        }

        if (mounted) {
          ToastUtils.showInfo(context, 'Data imported successfully!');
        }
      } catch (e) {
        if (mounted) {
          ToastUtils.showInfo(context, 'Failed to import data: $e');
        }
      }
    }
  }

  Widget _buildDataTab() {
    final t = ref.watch(translationsProvider);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        Text(t['export_data'] ?? 'Export data',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(t['export_all_your_collectio'] ?? 'Export all your collections, environments, globals and header presets to a single dump file.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _exportData,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
              side: BorderSide(color: Theme.of(context).dividerColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
            ),
            child: Text(t['export_data'] ?? 'Export Data', style: TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(height: 32),
        Text(t['import_data'] ?? 'Import data',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(t['import_your_data_from_a_p'] ?? 'Import your data from a previous export.',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: _importData,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).textTheme.bodyMedium!.color,
              side: BorderSide(color: Theme.of(context).dividerColor),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
            ),
            child: Text(t['import_data'] ?? 'Import Data', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildProxyTab() {
    final t = ref.watch(translationsProvider);
    final settings = ref.watch(networkSettingsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        Text(t['capture_proxy_mitm'] ?? 'Capture Proxy (MITM)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSettingRow(
          title: 'Enable SSL Proxying',
          subtitle:
              'Decrypt HTTPS traffic. Requires installing the CA certificate.',
          trailing: _buildSwitch(
            settings.enableSslProxying,
            onChanged: (v) {
              ref.read(networkSettingsProvider.notifier).updateSettings(
                    settings.copyWith(enableSslProxying: v),
                  );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(t['root_certificate_manageme'] ?? 'Root certificate management has moved to the capture page.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 32),
        Text(t['system_proxy'] ?? 'System Proxy',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSettingRow(
          title: 'Use System Proxy',
          subtitle: 'Use the system proxy for sending requests.',
          trailing: _buildSwitch(
            settings.systemProxy,
            onChanged: (v) {
              ref.read(networkSettingsProvider.notifier).updateSettings(
                    settings.copyWith(systemProxy: v),
                  );
            },
          ),
        ),
        const SizedBox(height: 32),
        Text(t['custom_proxy'] ?? 'Custom Proxy',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSettingRow(
          title: 'Add a custom proxy configuration',
          trailing: _buildSwitch(
            settings.customProxyEnabled,
            onChanged: (v) {
              ref.read(networkSettingsProvider.notifier).updateSettings(
                    settings.copyWith(customProxyEnabled: v),
                  );
            },
          ),
        ),
        if (settings.customProxyEnabled) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text(t['proxy_server'] ?? 'Proxy Server', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: TextFormField(
                    controller: _proxyUrlController,
                    onChanged: (v) {
                      ref.read(networkSettingsProvider.notifier).updateSettings(
                            settings.copyWith(customProxyUrl: v),
                          );
                    },
                    decoration: const InputDecoration(
                      hintText: 'e.g. 127.0.0.1:8080 or http://proxy:80',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAboutTab() {
    final t = ref.watch(translationsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        Center(
          child: Column(
            children: [
              const SizedBox(height: 48),
              Icon(FontAwesomeIcons.rocket,
                  size: 64, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(height: 24),
              Text(t['postlens'] ?? 'PostLens',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(t['version_1_0_0'] ?? 'Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    final t = ref.watch(translationsProvider);
    final settings = ref.watch(networkSettingsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        Text(t['request'] ?? 'Request',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSettingRow(
          title: t['request_timeout'] ?? 'Request timeout',
          subtitle:
              t['request_timeout_desc'] ?? 'Set how long a request should wait for a response before timing out. To never time out, set to 0.',
          trailing: _buildNumberInput(
            _timeoutController,
            'ms',
            onChanged: (v) {
              final val = int.tryParse(v) ?? 0;
              ref.read(networkSettingsProvider.notifier).updateSettings(
                    settings.copyWith(requestTimeout: val),
                  );
            },
          ),
        ),
        _buildDivider(),
        _buildSettingRow(
          title: t['max_response_size'] ?? 'Max response size',
          subtitle:
              t['max_response_size_desc'] ?? 'Set the maximum size of a response to download. To download a response of any size, set to 0.',
          trailing: _buildNumberInput(
            _maxSizeController,
            'MB',
            onChanged: (v) {
              final val = int.tryParse(v) ?? 50;
              ref.read(networkSettingsProvider.notifier).updateSettings(
                    settings.copyWith(maxResponseSize: val),
                  );
            },
          ),
        ),
        _buildDivider(),
        _buildSettingRow(
          title: t['ssl_cert_verification'] ?? 'SSL certificate verification',
          trailing: _buildSwitch(
            settings.sslVerification,
            onChanged: (v) {
              ref.read(networkSettingsProvider.notifier).updateSettings(
                    settings.copyWith(sslVerification: v),
                  );
            },
          ),
        ),
        _buildDivider(),
        _buildSettingRow(
          title: t['disable_cookies_setting'] ?? 'Disable cookies',
          subtitle: t['disable_cookies_desc'] ?? 'Disable cookie jar for all requests.',
          trailing: _buildSwitch(
            settings.disableCookies,
            onChanged: (v) {
              ref.read(networkSettingsProvider.notifier).updateSettings(
                    settings.copyWith(disableCookies: v),
                  );
            },
          ),
        ),
        const SizedBox(height: 32),
        Text(t['headers'] ?? 'Headers',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _buildSettingRow(
          title: t['send_no_cache_header'] ?? 'Send no-cache header',
          trailing: _buildSwitch(
            settings.sendNoCacheHeader,
            onChanged: (v) {
              ref.read(networkSettingsProvider.notifier).updateSettings(
                    settings.copyWith(sendNoCacheHeader: v),
                  );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildThemesTab() {
    final t = ref.watch(translationsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      children: [
        Text(t['theme'] ?? 'Theme',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomRadioListTile<ThemeMode>(
                title: Text(t['system_mode'] ?? 'Follow System',
                    style: const TextStyle(fontSize: 12)),
                value: ThemeMode.system,
                groupValue: themeMode,
                activeColor: Theme.of(context).colorScheme.secondary,
                contentPadding: EdgeInsets.zero,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                  }
                },
              ),
            ),
            Expanded(
              child: CustomRadioListTile<ThemeMode>(
                title: Text(t['light_mode'] ?? 'Light Mode',
                    style: const TextStyle(fontSize: 12)),
                value: ThemeMode.light,
                groupValue: themeMode,
                activeColor: Theme.of(context).colorScheme.secondary,
                contentPadding: EdgeInsets.zero,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                  }
                },
              ),
            ),
            Expanded(
              child: CustomRadioListTile<ThemeMode>(
                title: Text(t['dark_mode'] ?? 'Dark Mode',
                    style: const TextStyle(fontSize: 12)),
                value: ThemeMode.dark,
                groupValue: themeMode,
                activeColor: Theme.of(context).colorScheme.secondary,
                contentPadding: EdgeInsets.zero,
                onChanged: (ThemeMode? value) {
                  if (value != null) {
                    ref.read(themeModeProvider.notifier).setThemeMode(value);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text(t['language'] ?? 'Language',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: CustomRadioListTile<Locale>(
                title: Text(t['english'] ?? 'English',
                    style: const TextStyle(fontSize: 12)),
                value: const Locale('en'),
                groupValue: locale,
                activeColor: Theme.of(context).colorScheme.secondary,
                contentPadding: EdgeInsets.zero,
                onChanged: (Locale? value) {
                  if (value != null) {
                    ref.read(localeProvider.notifier).setLocale(value);
                  }
                },
              ),
            ),
            Expanded(
              child: CustomRadioListTile<Locale>(
                title: Text(t['chinese'] ?? 'Chinese',
                    style: const TextStyle(fontSize: 12)),
                value: const Locale('zh'),
                groupValue: locale,
                activeColor: Theme.of(context).colorScheme.secondary,
                contentPadding: EdgeInsets.zero,
                onChanged: (Locale? value) {
                  if (value != null) {
                    ref.read(localeProvider.notifier).setLocale(value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingRow({
    required String title,
    String? subtitle,
    Widget? badge,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12)),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      badge,
                    ],
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          trailing,
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Divider(
          color: Theme.of(context).dividerColor, height: 1, thickness: 1),
    );
  }

  Widget _buildNumberInput(TextEditingController controller, String suffix,
      {void Function(String)? onChanged}) {
    return Container(
      height: 36,
      width: 100,
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: 32,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                  left: BorderSide(color: Theme.of(context).dividerColor)),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Text(suffix,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(bool value, {void Function(bool)? onChanged}) {
    return SizedBox(
      height: 24,
      child: Transform.scale(
        scale: 0.65,
        child: Switch(
          value: value,
          onChanged: onChanged ?? (v) {},
          activeThumbColor: Colors.blue,
        ),
      ),
    );
  }
}
