import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

class RequestDetailView extends ConsumerWidget {
  final Map<String, dynamic> requestData;

  const RequestDetailView({super.key, required this.requestData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    return DefaultTabController(
      length: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabBar(
            isScrollable: true,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: t['overview_tab'] ?? 'Overview'),
              Tab(text: t['raw_tab'] ?? 'Raw'),
              Tab(text: '${t['headers_tab'] ?? 'Headers'}(23)'),
              Tab(text: t['body_tab'] ?? 'Body'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildOverviewTab(t),
                Center(child: Text(t['raw_request_data'] ?? 'Raw Request Data')),
                _buildHeadersTab(t),
                Center(child: Text(t['body_empty_or_binary'] ?? 'Body is empty or binary')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(Map<String, String> t) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildSectionHeader('https://api.trae.com.cn/icube/api/v2/asr/get/a'),
        _buildInfoRow(t['status'] ?? 'Status', 'Completed'),
        _buildInfoRow(t['method'] ?? 'Method', 'POST'),
        _buildInfoRow(t['protocol'] ?? 'Protocol', 'h2'),
        _buildInfoRow('Code', '200'),
        _buildInfoRow(t['server_address'] ?? 'Server Address', '198.18.0.32:443'),
        _buildInfoRow('Keep Alive', 'true'),
        _buildInfoRow(t['stream'] ?? 'Stream', '#1'),
        _buildInfoRow('Content Type', 'application/json'),
        _buildInfoRow(t['proxy_protocol'] ?? 'Proxy Protocol', 'https'),
        _buildSectionHeader(t['application'] ?? 'Application'),
        _buildInfoRow(t['name'] ?? 'Name', 'TRAE CN'),
        _buildInfoRow('ID', 'cn.trae.app'),
        _buildInfoRow(t['path'] ?? 'Path', '/Applications/Trae CN.app'),
        _buildInfoRow(t['process_id'] ?? 'Process ID', '36009'),
        _buildSectionHeader(t['connection'] ?? 'Connection'),
        _buildInfoRow('ID', '36'),
        _buildInfoRow(t['time'] ?? 'Time', '2026-04-13 23:39:53.319339'),
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Text(t['frontend'] ?? 'Frontend',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        _buildInfoRow(t['client_address'] ?? ' - Client Address', '127.0.0.1'),
        _buildInfoRow(t['client_port'] ?? ' - Client Port', '54346'),
        _buildInfoRow(t['server_address_sub'] ?? ' - Server Address', '127.0.0.1'),
        _buildInfoRow(t['server_port'] ?? ' - Server Port', '9000'),
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Text(t['backend'] ?? 'Backend',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        _buildInfoRow(t['client_address'] ?? ' - Client Address', '198.18.0.1'),
        _buildInfoRow(t['client_port'] ?? ' - Client Port', '54347'),
        _buildInfoRow(t['server_address_sub'] ?? ' - Server Address', '198.18.0.32'),
        _buildInfoRow(t['server_port'] ?? ' - Server Port', '443'),
        _buildSectionHeader('TLS'),
        _buildInfoRow(t['version'] ?? 'Version', 'TLSv1.3'),
        _buildInfoRow('SNI', 'api.trae.com.cn'),
        _buildInfoRow('ALPN', 'h2 http/1.1'),
        _buildInfoRow(t['select_alpn'] ?? 'Select ALPN', 'h2'),
        _buildInfoRow(t['cipher_suite_list'] ?? 'Cipher Suite List', '3 ${t['items_3'] ?? 'items'}'),
        _buildInfoRow(t['select_cipher_suite'] ?? 'Select Cipher Suite', 'TLS_AES_128_GCM_SHA256'),
        _buildSectionHeader(t['time'] ?? 'Time'),
        _buildInfoRow(t['request_start'] ?? 'Request Start', '2026-04-13 23:39:53.356931'),
        _buildInfoRow(t['request_end'] ?? 'Request End', '2026-04-13 23:39:53.357602'),
        _buildInfoRow(t['total_duration'] ?? 'Total Duration', '164ms'),
        _buildSectionHeader(t['size'] ?? 'Size'),
        _buildInfoRow(t['request'] ?? 'Request', '1.77 KB'),
        _buildInfoRow(t['response'] ?? 'Response', '1.34 KB'),
        _buildInfoRow(t['total'] ?? 'Total', '3.12 KB'),
      ],
    );
  }

  Widget _buildHeadersTab(Map<String, String> t) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildInfoRow(':method', 'POST'),
        _buildInfoRow(':authority', 'api.trae.com.cn'),
        _buildInfoRow(':path', '/icube/api/v2/asr/get/a'),
        _buildInfoRow(':scheme', 'https'),
        _buildInfoRow('content-length', '0'),
        _buildInfoRow('accept', '*/*'),
        _buildInfoRow('accept-encoding', 'gzip, deflate, br, zstd'),
        _buildInfoRow('content-type', 'application/json'),
        _buildInfoRow('user-agent',
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ...'),
        _buildInfoRow('x-icube-token', 'eyJhbGciOiJSUzI1NiIs...'),
        _buildInfoRow('app-version', '3.3.47'),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.3))),
      ),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
