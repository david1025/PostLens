import 'package:post_lens/core/utils/toast_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_highlight/themes/darcula.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/request_provider.dart';
import '../../utils/code_highlighter.dart';
import '../../utils/formatter.dart';
import '../../domain/models/http_response_model.dart';
import '../providers/settings_provider.dart';
import 'app_code_editor.dart';

class ResponsePane extends ConsumerStatefulWidget {
  const ResponsePane({super.key});

  @override
  ConsumerState<ResponsePane> createState() => _ResponsePaneState();
}

class _ResponsePaneState extends ConsumerState<ResponsePane>
    with SingleTickerProviderStateMixin {
  static const double _compactTableRowHeight = 28;
  static const double _compactTableCellHorizontalPadding = 4;
  static const double _compactTableCellVerticalPadding = 6;
  static const double _compactTableColumnGap = 12;

  late TabController _tabController;

  String _currentFormat = 'Auto';
  bool _wrapLines = true;
  String _lastBody = '';
  late CodeHighlighterController _codeController;
  final GlobalKey<AppCodeEditorState> _editorKey =
      GlobalKey<AppCodeEditorState>();

  @override
  void initState() {
    super.initState();
    final requestId = ref.read(requestProvider).id;
    final uiState = ref.read(requestPageUiProvider(requestId));
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: uiState.responseTabIndex >= 4 ? 3 : uiState.responseTabIndex,
    );
    _tabController.addListener(_handleTabChanged);
    _currentFormat = uiState.responseFormat;
    _wrapLines = uiState.responseWrapLines;
    _codeController = CodeHighlighterController(language: 'json');
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    final requestId = ref.read(requestProvider).id;
    ref
        .read(requestPageUiProvider(requestId).notifier)
        .updateResponseTabIndex(_tabController.index);
  }

  void _updateFormat(String body, Map<String, List<String>> headers,
      {String? forceFormat}) {
    if (body != _lastBody || forceFormat != null) {
      _lastBody = body;

      String format = forceFormat ?? _currentFormat;
      if (format == 'Auto') {
        final contentType = headers['content-type']?.join(' ') ??
            headers['Content-Type']?.join(' ') ??
            '';
        if (contentType.contains('json')) {
          format = 'JSON';
        } else if (contentType.contains('xml')) {
          format = 'XML';
        } else if (contentType.contains('html')) {
          format = 'HTML';
        } else {
          format = 'Text';
        }
        _currentFormat = format;
      }

      String formattedBody = body;
      String lang = 'text';

      switch (format) {
        case 'JSON':
          formattedBody = Formatter.formatJson(body);
          lang = 'json';
          break;
        case 'XML':
          formattedBody = Formatter.formatXml(body);
          lang = 'xml';
          break;
        case 'HTML':
          formattedBody = Formatter.formatXml(body);
          lang = 'xml';
          break;
        case 'Text':
        default:
          lang = 'text';
          break;
      }

      _codeController.language = lang;
      _codeController.text = formattedBody;
    }
  }

  void _setResponseFormat(String value) {
    _currentFormat = value;
    final requestId = ref.read(requestProvider).id;
    ref.read(requestPageUiProvider(requestId).notifier).updateResponseFormat(
          value,
        );
  }

  void _setWrapLines(bool value) {
    _wrapLines = value;
    final requestId = ref.read(requestProvider).id;
    ref
        .read(requestPageUiProvider(requestId).notifier)
        .updateResponseWrapLines(value);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final request = ref.watch(requestProvider);
    final response = ref.watch(responseProvider(request.id));
    final isSending = ref.watch(isSendingProvider(request.id));

    if (response != null) {
      _updateFormat(response.body, response.headers);
    }

    // Update highlighter theme based on current brightness
    _codeController.theme = Theme.of(context).brightness == Brightness.dark
        ? darculaTheme
        : githubTheme;

    if (isSending) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.secondary),
        ),
      );
    }

    if (response == null) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Center(
          child: Text(
              t['enter_url_and_click_send_'] ??
                  'Enter URL and click Send to get a response',
              style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    if (response.statusCode <= 0) {
      return _buildErrorView(response);
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(8.0),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 32,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicatorColor: Theme.of(context).colorScheme.secondary,
                      indicatorWeight: 2.0,
                      labelColor:
                          Theme.of(context).textTheme.bodyMedium!.color!,
                      unselectedLabelColor: Colors.grey,
                      tabAlignment: TabAlignment.start,
                      labelStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
                      dividerColor: Theme.of(context).dividerColor,
                      tabs: [
                        Tab(text: t['body'] ?? 'Body'),
                        Tab(
                            text:
                                '${t['cookies'] ?? 'Cookies'} ${response.cookies.isNotEmpty ? "(${response.cookies.length})" : ""}'),
                        Tab(
                            text:
                                '${t['headers'] ?? 'Headers'} (${response.headers.length})'),
                        Tab(
                            text:
                                'Test Results ${response.testResults?.isNotEmpty == true ? "(${response.testResults!.where((e) => e['passed'] == true).length}/${response.testResults!.length})" : ""}'),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    icon: const FaIcon(FontAwesomeIcons.clockRotateLeft,
                        size: 14, color: Colors.grey),
                    tooltip: 'Request History',
                    position: PopupMenuPosition.under,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'history',
                        height: 32,
                        child: Text(
                            t['requested_1_times'] ?? 'Requested 1 times',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  if (response.statusCode > 0)
                    Tooltip(
                      richMessage:
                          WidgetSpan(child: _buildStatusTooltip(response)),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      padding: EdgeInsets.zero,
                      margin: EdgeInsets.zero,
                      preferBelow: true,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: response.statusCode >= 200 &&
                                  response.statusCode < 300
                              ? const Color(0xFF0CBD7D).withOpacity(0.1)
                              : const Color(0xFFF05050).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${response.statusCode} ${response.statusMessage}',
                          style: TextStyle(
                            color: response.statusCode >= 200 &&
                                    response.statusCode < 300
                                ? const Color(0xFF0CBD7D)
                                : const Color(0xFFF05050),
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF05050).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        t['error'] ?? 'Error',
                        style: TextStyle(
                          color: Color(0xFFF05050),
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  _buildStatusItem(
                      '',
                      '${response.timeMs} ms',
                      Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black,
                      tooltip: _buildTimeTooltip(response)),
                  _buildStatusItem(
                      '',
                      _formatSize(response.sizeBytes),
                      Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black,
                      tooltip: _buildSizeTooltip(response)),
                  const SizedBox(width: 4),
                  Tooltip(
                    richMessage:
                        WidgetSpan(child: _buildNetworkTooltip(response)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.zero,
                    preferBelow: true,
                    child: const FaIcon(FontAwesomeIcons.globe,
                        size: 14, color: Colors.grey),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.circle, size: 4, color: Colors.grey),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const FaIcon(FontAwesomeIcons.ellipsis,
                        size: 14, color: Colors.grey),
                    tooltip: 'More actions',
                    position: PopupMenuPosition.under,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    onSelected: (value) async {
                      if (value == 'clear') {
                        ref.read(responseProvider(request.id).notifier).state =
                            null;
                      } else if (value == 'save_to_file') {
                        final responseBody =
                            ref.read(responseProvider(request.id))?.body;
                        if (responseBody != null && responseBody.isNotEmpty) {
                          String? outputFile =
                              await FilePicker.platform.saveFile(
                            dialogTitle: 'Save Response to File',
                            fileName: 'response.txt',
                          );
                          if (outputFile != null) {
                            final file = File(outputFile);
                            await file.writeAsString(responseBody);
                            if (context.mounted) {
                              ToastUtils.showInfo(
                                  context, 'Response saved to $outputFile');
                            }
                          }
                        } else {
                          if (context.mounted) {
                            ToastUtils.showInfo(
                                context, 'No response body to save');
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'save_to_file',
                        height: 32,
                        child: Text(
                            t['save_response_to_file'] ??
                                'Save response to file',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'clear',
                        height: 32,
                        child: Text(t['clear_response'] ?? 'Clear response',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildResponseBody(response.body),
                _buildCookiesTab(response.cookies),
                _buildResponseHeaders(response.headers),
                _buildTestResultsTab(response.testResults),
              ],
            ),
          )
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(2)} KB';
  }

  Widget _buildStatusTooltip(HttpResponseModel response) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    return Container(
      padding: const EdgeInsets.all(12),
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? const Color(0xFF0CBD7D).withOpacity(0.1)
                      : const Color(0xFFF05050).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(isSuccess ? Icons.check : Icons.close,
                    size: 14,
                    color: isSuccess
                        ? const Color(0xFF0CBD7D)
                        : const Color(0xFFF05050)),
              ),
              const SizedBox(width: 8),
              Text('${response.statusCode} ${response.statusMessage}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.black,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          Text(
              isSuccess
                  ? 'Request successful. The server has responded as required.'
                  : 'The request resulted in an error.',
              style: const TextStyle(
                  color: Colors.grey, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildTimeTooltip(HttpResponseModel response) {
    final t = ref.watch(translationsProvider);
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    return Container(
      padding: const EdgeInsets.all(12),
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const FaIcon(FontAwesomeIcons.clockRotateLeft,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(t['response_time'] ?? 'Response Time',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: textColor)),
                ],
              ),
              Text('${response.timeMs} ms',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          _buildTimeRow(
              'Prepare',
              '${(response.timeMs * 0.05).toStringAsFixed(2)} ms',
              Colors.grey.withOpacity(0.2)),
          _buildTimeRow(
              'Socket Initialization',
              '${(response.timeMs * 0.02).toStringAsFixed(2)} ms',
              Colors.orange),
          _buildTimeRow('DNS Lookup', 'Cache', Colors.transparent),
          _buildTimeRow('TCP Handshake', 'Cache', Colors.transparent),
          _buildTimeRow('SSL Handshake', 'Cache', Colors.transparent),
          _buildTimeRow(
              'Waiting (TTFB)',
              '${(response.timeMs * 0.85).toStringAsFixed(2)} ms',
              Colors.red.withOpacity(0.2),
              isDashed: true),
          _buildTimeRow(
              'Download',
              '${(response.timeMs * 0.05).toStringAsFixed(2)} ms',
              const Color(0xFF0CBD7D)),
          _buildTimeRow(
              'Process',
              '${(response.timeMs * 0.03).toStringAsFixed(2)} ms',
              Colors.grey.withOpacity(0.2)),
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, String value, Color barColor,
      {bool isDashed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildSizeTooltip(HttpResponseModel response) {
    final t = ref.watch(translationsProvider);
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    // Estimate headers size
    int headersSize = 0;
    response.headers.forEach((key, values) {
      headersSize += key.length + 2 + values.join(', ').length + 2;
    });

    return Container(
      padding: const EdgeInsets.all(12),
      width: 280,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_downward,
                        size: 12, color: Colors.blue),
                  ),
                  const SizedBox(width: 8),
                  Text(t['response_size'] ?? 'Response Size',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: textColor)),
                ],
              ),
              Text(_formatSize(response.sizeBytes),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t['headers'] ?? 'Headers',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(_formatSize(headersSize),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t['body'] ?? 'Body',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                    _formatSize(response.sizeBytes > headersSize
                        ? response.sizeBytes - headersSize
                        : response.sizeBytes),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_upward,
                        size: 12, color: Colors.orange),
                  ),
                  const SizedBox(width: 8),
                  Text(t['request_size'] ?? 'Request Size',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                          color: textColor)),
                ],
              ),
              Text('--- B',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t['headers'] ?? 'Headers',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Text('--- B',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24.0, right: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t['body'] ?? 'Body',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const Text('--- B',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkTooltip(HttpResponseModel response) {
    final t = ref.watch(translationsProvider);
    final textColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
    return Container(
      padding: const EdgeInsets.all(12),
      width: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FaIcon(FontAwesomeIcons.globe,
                  size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Text(t['network'] ?? 'Network',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['http_version'] ?? 'HTTP Version',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Text('1.1',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['local_address'] ?? 'Local Address',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(t['style_textstyle_fontsize_'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(t['remote_address'] ?? 'Remote Address',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(t['style_textstyle_fontsize_'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, Color valueColor,
      {IconData? icon, bool showDot = true, Widget? tooltip}) {
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          const SizedBox(width: 8),
          const Icon(Icons.circle, size: 4, color: Colors.grey),
          const SizedBox(width: 8),
        ],
        if (icon != null) ...[
          FaIcon(icon, size: 12, color: valueColor),
          const SizedBox(width: 4),
        ] else if (label.isNotEmpty) ...[
          Text(label, style: TextStyle(color: valueColor, fontSize: 12)),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            value,
            style: TextStyle(
                color: valueColor, fontSize: 12, fontWeight: FontWeight.normal),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    if (tooltip != null) {
      return Tooltip(
        richMessage: WidgetSpan(child: tooltip),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ],
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        padding: EdgeInsets.zero,
        margin: EdgeInsets.zero,
        preferBelow: true,
        child: content,
      );
    }

    return content;
  }

  Widget _buildResponseBody(String body) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              PopupMenuButton<String>(
                tooltip: 'Response Format',
                position: PopupMenuPosition.under,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
                onSelected: (value) {
                  setState(() {
                    final response = ref
                        .read(responseProvider(ref.read(requestProvider).id));
                    if (response != null) {
                      _setResponseFormat(value);
                      _updateFormat(response.body, response.headers,
                          forceFormat: value);
                    }
                  });
                },
                itemBuilder: (context) => <String>[
                  'JSON',
                  'XML',
                  'HTML',
                  'Text',
                  'Auto'
                ].map((String value) {
                  return PopupMenuItem<String>(
                    value: value,
                    height: 32,
                    child: Text(value, style: const TextStyle(fontSize: 12)),
                  );
                }).toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_currentFormat,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 4),
                    const FaIcon(FontAwesomeIcons.chevronDown,
                        size: 10, color: Colors.grey),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: FaIcon(FontAwesomeIcons.rightLeft,
                        size: 12,
                        color: _wrapLines
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.grey),
                    tooltip: 'Wrap lines',
                    onPressed: () {
                      setState(() {
                        _setWrapLines(!_wrapLines);
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.alignLeft,
                        size: 12, color: Colors.grey),
                    tooltip: 'Format',
                    onPressed: () {
                      setState(() {
                        final response = ref.read(
                            responseProvider(ref.read(requestProvider).id));
                        if (response != null) {
                          _updateFormat(response.body, response.headers,
                              forceFormat: _currentFormat);
                        }
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/search.svg',
                      width: 14,
                      height: 14,
                      colorFilter:
                          const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                    ),
                    tooltip: 'Search',
                    onPressed: () {
                      _editorKey.currentState?.showSearch();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.copy,
                        size: 12, color: Colors.grey),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _codeController.text));
                      ToastUtils.showInfo(
                          context, 'Response copied to clipboard');
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: AppCodeEditor(
                key: _editorKey,
                text: _codeController.text,
                wrapLines: _wrapLines,
                readOnly: true,
                language: _codeController.language,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseHeaders(Map<String, List<String>> headers) {
    final t = ref.watch(translationsProvider);
    if (headers.isEmpty) {
      return Center(
          child: Text(t['no_headers'] ?? 'No Headers',
              style: const TextStyle(color: Colors.grey)));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7.0),
            child: Table(
              border: TableBorder(
                horizontalInside:
                    BorderSide(color: Theme.of(context).dividerColor),
                verticalInside:
                    BorderSide(color: Theme.of(context).dividerColor),
              ),
              columnWidths: const {
                0: FlexColumnWidth(1),
                1: FlexColumnWidth(2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _compactTableCellHorizontalPadding,
                        vertical: _compactTableCellVerticalPadding,
                      ),
                      child: Text(t['key'] ?? 'Key',
                          style: TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _compactTableCellHorizontalPadding,
                        vertical: _compactTableCellVerticalPadding,
                      ),
                      child: Text(t['value'] ?? 'Value',
                          style: TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color)),
                    ),
                  ],
                ),
                ...headers.entries.map((entry) {
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _compactTableCellHorizontalPadding,
                          vertical: _compactTableCellVerticalPadding,
                        ),
                        child: SelectableText(entry.key,
                            strutStyle: const StrutStyle(height: 1.4),
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _compactTableCellHorizontalPadding,
                          vertical: _compactTableCellVerticalPadding,
                        ),
                        child: SelectableText(entry.value.join(', '),
                            strutStyle: const StrutStyle(height: 1.4),
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestResultsTab(List<dynamic>? testResults) {
    if (testResults == null || testResults.isEmpty) {
      return Center(
        child: Text(
          ref.watch(translationsProvider)['no_test_results'] ?? 'No test results',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    int passed = testResults.where((t) => t['passed'] == true).length;
    int total = testResults.length;

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              'Tests: $passed/$total passed',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: passed == total ? Colors.green : Colors.red,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: testResults.length,
              itemBuilder: (context, index) {
                final result = testResults[index];
                final isPassed = result['passed'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 12),
                        child: FaIcon(
                          isPassed ? FontAwesomeIcons.checkCircle : FontAwesomeIcons.circleXmark,
                          color: isPassed ? Colors.green : Colors.red,
                          size: 14,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              result['name'] ?? 'Unknown test',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                            if (!isPassed && result['error'] != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                result['error'].toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontFamily: 'Consolas',
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCookiesTab(List<Cookie> cookies) {
    final t = ref.watch(translationsProvider);
    if (cookies == null || cookies.isEmpty) {
      return Center(
          child: Text(t['no_cookies'] ?? 'No Cookies',
              style: const TextStyle(color: Colors.grey)));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowHeight: _compactTableRowHeight,
                      dataRowMinHeight: _compactTableRowHeight,
                      dataRowMaxHeight: _compactTableRowHeight,
                      horizontalMargin: _compactTableCellHorizontalPadding,
                      columnSpacing: _compactTableColumnGap,
                      headingRowColor: WidgetStateProperty.resolveWith(
                          (states) =>
                              Theme.of(context).scaffoldBackgroundColor),
                      border: TableBorder(
                        horizontalInside:
                            BorderSide(color: Theme.of(context).dividerColor),
                        verticalInside:
                            BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      columns: [
                        DataColumn(
                            label: Text(t['name'] ?? 'Name',
                                style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color))),
                        DataColumn(
                            label: Text(t['value'] ?? 'Value',
                                style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color))),
                        DataColumn(
                            label: Text(t['domain'] ?? 'Domain',
                                style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color))),
                        DataColumn(
                            label: Text(t['path'] ?? 'Path',
                                style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color))),
                        DataColumn(
                            label: Text(t['expires'] ?? 'Expires',
                                style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color))),
                        DataColumn(
                            label: Text(t['httponly'] ?? 'HttpOnly',
                                style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color))),
                        DataColumn(
                            label: Text(t['secure'] ?? 'Secure',
                                style: TextStyle(
                                    fontWeight: FontWeight.normal,
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color))),
                      ],
                      rows: cookies.map((cookie) {
                        String value = cookie.value;
                        if (value.length > 20) {
                          value = '${value.substring(0, 20)}...';
                        }
                        String expires = cookie.expires;
                        if (expires.length > 20) {
                          expires = '${expires.substring(0, 20)}...';
                        }
                        return DataRow(
                          cells: [
                            DataCell(SelectableText(cookie.name,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(SelectableText(value,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(SelectableText(cookie.domain,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(SelectableText(cookie.path,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(SelectableText(expires,
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(cookie.httpOnly.toString(),
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(cookie.secure.toString(),
                                style: const TextStyle(fontSize: 12))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(HttpResponseModel response) {
    final t = ref.watch(translationsProvider);
    final request = ref.read(requestProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8.0),
                    child: Text(
                      t['response'] ?? 'Response',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopupMenuButton<String>(
                    icon: const FaIcon(FontAwesomeIcons.clockRotateLeft,
                        size: 14, color: Colors.grey),
                    tooltip: 'Request History',
                    position: PopupMenuPosition.under,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'history',
                        height: 32,
                        child: Text(
                            t['requested_1_times'] ?? 'Requested 1 times',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF05050).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t['error'] ?? 'Error',
                      style: TextStyle(
                        color: Color(0xFFF05050),
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusItem(
                      '',
                      '0 ms',
                      Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black),
                  _buildStatusItem(
                      '',
                      '0 B',
                      Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.black),
                  const SizedBox(width: 4),
                  const FaIcon(FontAwesomeIcons.globe,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  const Icon(Icons.circle, size: 4, color: Colors.grey),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const FaIcon(FontAwesomeIcons.ellipsis,
                        size: 14, color: Colors.grey),
                    tooltip: 'More actions',
                    position: PopupMenuPosition.under,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 16,
                    onSelected: (value) async {
                      if (value == 'clear') {
                        ref.read(responseProvider(request.id).notifier).state =
                            null;
                      } else if (value == 'save_to_file') {
                        final responseBody =
                            ref.read(responseProvider(request.id))?.body;
                        if (responseBody != null && responseBody.isNotEmpty) {
                          String? outputFile =
                              await FilePicker.platform.saveFile(
                            dialogTitle: 'Save Response to File',
                            fileName: 'response.txt',
                          );
                          if (outputFile != null) {
                            final file = File(outputFile);
                            await file.writeAsString(responseBody);
                            if (context.mounted) {
                              ToastUtils.showInfo(
                                  context, 'Response saved to $outputFile');
                            }
                          }
                        } else {
                          if (context.mounted) {
                            ToastUtils.showInfo(
                                context, 'No response body to save');
                          }
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'save_to_file',
                        height: 32,
                        child: Text(
                            t['save_response_to_file'] ??
                                'Save response to file',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      PopupMenuItem(
                        value: 'clear',
                        height: 32,
                        child: Text(t['clear_response'] ?? 'Clear response',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        FaIcon(
                          FontAwesomeIcons.userAstronaut,
                          size: 80,
                          color: isDark ? Colors.grey[700] : Colors.grey[400],
                        ),
                        Positioned(
                          right: -10,
                          bottom: 0,
                          child: FaIcon(
                            FontAwesomeIcons.plugCircleXmark,
                            size: 30,
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t['could_not_send_request'] ?? 'Could not send request',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: 600,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF05050).withOpacity(0.05),
                        border: Border.all(
                            color: const Color(0xFFF05050).withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.circleExclamation,
                            color: Color(0xFFF05050),
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SelectableText(
                              'Error: ${response.statusMessage}',
                              style: TextStyle(
                                fontFamily: 'IBMPlexMono',
                                fontFamilyFallback: const [
                                  'Monaco',
                                  'Courier New',
                                  'monospace'
                                ],
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            ToastUtils.showInfo(
                                context, 'Console is not available yet');
                          },
                          icon: const FaIcon(FontAwesomeIcons.terminal,
                              size: 12, color: Colors.grey),
                          label: Text(t['view_in_console'] ?? 'View in console',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                        ),
                        const Text('•', style: TextStyle(color: Colors.grey)),
                        TextButton(
                          onPressed: () {
                            ToastUtils.showInfo(context,
                                'Troubleshooting guide is not available yet');
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          child: Text(
                              t['learn_about_troubleshooti'] ??
                                  'Learn about troubleshooting requests',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
