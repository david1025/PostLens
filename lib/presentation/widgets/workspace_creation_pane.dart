import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/workspace_model.dart';
import '../providers/workspace_provider.dart';
import '../providers/settings_provider.dart';

class WorkspaceCreationPane extends ConsumerStatefulWidget {
  final VoidCallback onSaved;

  const WorkspaceCreationPane({super.key, required this.onSaved});

  @override
  ConsumerState<WorkspaceCreationPane> createState() =>
      _WorkspaceCreationPaneState();
}

class _WorkspaceCreationPaneState extends ConsumerState<WorkspaceCreationPane> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) return;

    final newWorkspace = WorkspaceModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descController.text.trim(),
    );

    ref.read(workspacesProvider.notifier).addWorkspace(newWorkspace);
    ref.read(activeWorkspaceProvider.notifier).setActiveWorkspace(newWorkspace);

    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t['create_new_workspace'] ?? 'CREATE NEW WORKSPACE',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(t['name'] ?? 'Name',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                hintText: t['my_workspace'] ?? 'My Workspace',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.secondary),
                ),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(t['summary'] ?? 'Summary',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            maxLines: 3,
            textAlignVertical: TextAlignVertical.top,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              hintText: 'What is this workspace for?',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide:
                    BorderSide(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 28,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.secondary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0)),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                elevation: 0,
              ),
              child: Text(t['create_workspace'] ?? 'Create Workspace',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
