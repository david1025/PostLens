import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../providers/workspace_provider.dart';

class WorkspaceOverview extends ConsumerWidget {
  const WorkspaceOverview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final activeWorkspace = ref.watch(activeWorkspaceProvider);

    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.fromLTRB(12.0, 20.0, 12.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(activeWorkspace.name.isNotEmpty ? activeWorkspace.name : (t['my_workspace'] ?? 'My Workspace'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'This workspace contains all your collections and environments.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
