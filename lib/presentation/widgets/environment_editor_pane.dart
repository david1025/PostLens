import 'package:post_lens/core/utils/toast_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../domain/models/environment_model.dart';
import '../providers/environment_provider.dart';
import '../providers/workspace_provider.dart';
import '../providers/settings_provider.dart';

class _EnvVarRow {
  bool enabled;
  bool isAutoManaged;
  final TextEditingController keyController;
  final TextEditingController valueController;
  String type;

  _EnvVarRow({
    required this.enabled,
    this.isAutoManaged = false,
    required this.keyController,
    required this.valueController,
    this.type = 'default',
  });

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class EnvironmentEditorPane extends ConsumerStatefulWidget {
  final String? environmentId;
  final VoidCallback? onSaved;

  const EnvironmentEditorPane({super.key, this.environmentId, this.onSaved});

  @override
  ConsumerState<EnvironmentEditorPane> createState() =>
      _EnvironmentEditorPaneState();
}

class _EnvironmentEditorPaneState extends ConsumerState<EnvironmentEditorPane> {
  static const double _compactTableRowHeight = 28;
  static const double _compactTableOuterHorizontalPadding = 6;
  static const double _compactTableCellHorizontalPadding = 4;
  static const double _compactTableColumnGap = 6;
  static const double _compactTableSideSlotWidth = 28;

  final _nameController = TextEditingController();
  final List<_EnvVarRow> _rows = [];
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _ensureTrailingEmptyRow() {
    if (_rows.isEmpty || _rows.last.keyController.text.trim().isNotEmpty) {
      _rows.add(
        _EnvVarRow(
          enabled: false,
          isAutoManaged: true,
          keyController: TextEditingController(),
          valueController: TextEditingController(),
        ),
      );
    }
  }

  void _handleRowTextChanged(_EnvVarRow row) {
    if (!row.isAutoManaged) return;

    final hasText = row.keyController.text.trim().isNotEmpty ||
        row.valueController.text.trim().isNotEmpty;
    if (row.enabled != hasText || (hasText && row.isAutoManaged)) {
      setState(() {
        row.enabled = hasText;
        if (hasText) {
          row.isAutoManaged = false;
        }
      });
    }
  }

  void _initFromEnvironment(EnvironmentModel env) {
    _nameController.text = env.name;
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
    for (final v in env.variables) {
      _rows.add(
        _EnvVarRow(
          enabled: v.enabled,
          keyController: TextEditingController(text: v.key),
          valueController: TextEditingController(text: v.value),
          type: v.type,
        ),
      );
    }
    _ensureTrailingEmptyRow();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ToastUtils.showInfo(context, 'Please enter an environment name');
      return;
    }

    final activeWorkspace = ref.read(activeWorkspaceProvider);
    var workspaceId = activeWorkspace.id;
    if (widget.environmentId != null) {
      final envs = ref.read(environmentsProvider);
      for (final e in envs) {
        if (e.id == widget.environmentId) {
          workspaceId = e.workspaceId;
          break;
        }
      }
    }
    final validVars = _rows
        .where((r) => r.keyController.text.trim().isNotEmpty)
        .map((r) => EnvironmentVariable(
              key: r.keyController.text,
              value: r.valueController.text,
              enabled: r.enabled,
              type: r.type,
            ))
        .toList();

    if (widget.environmentId == null) {
      final newEnv = EnvironmentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        workspaceId: workspaceId,
        variables: validVars,
      );
      await ref.read(environmentsProvider.notifier).addEnvironment(newEnv);
      widget.onSaved?.call();
      return;
    }

    final updatedEnv = EnvironmentModel(
      id: widget.environmentId!,
      name: _nameController.text.trim(),
      workspaceId: workspaceId,
      variables: validVars,
    );
    await ref.read(environmentsProvider.notifier).updateEnvironment(updatedEnv);
    ToastUtils.showInfo(context, 'Saved');
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    if (!_initialized) {
      if (widget.environmentId != null) {
        EnvironmentModel? env;
        final envs = ref.read(activeWorkspaceEnvironmentsProvider);
        for (final e in envs) {
          if (e.id == widget.environmentId) {
            env = e;
            break;
          }
        }
        if (env != null) {
          _initFromEnvironment(env);
        } else {
          _ensureTrailingEmptyRow();
        }
      } else {
        _nameController.text = t['new_environment'] ?? 'New Environment';
        _ensureTrailingEmptyRow();
      }
      _initialized = true;
    }

    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 12.0),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 28,
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.environmentId == null
                              ? (t['new_environment'] ?? 'New Environment')
                              : (t['environment'] ?? 'Environment'),
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4.0),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.5),
                              width: 1.0,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4.0),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.5),
                              width: 1.0,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4.0),
                            borderSide: BorderSide(
                              color: Colors.grey.withOpacity(0.5),
                              width: 1.0,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 28,
                      child: OutlinedButton.icon(
                        onPressed: _save,
                        icon:
                            const FaIcon(FontAwesomeIcons.floppyDisk, size: 14),
                        label: Text(t['save'] ?? 'Save',
                            style: const TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).textTheme.bodyMedium!.color,
                          side:
                              BorderSide(color: Theme.of(context).dividerColor),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(t['variables'] ?? 'Variables',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: _compactTableRowHeight,
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            border: Border(
                                bottom: BorderSide(
                                    color: Theme.of(context).dividerColor)),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: _compactTableOuterHorizontalPadding,
                            vertical: 0,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(width: _compactTableSideSlotWidth),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal:
                                        _compactTableCellHorizontalPadding,
                                  ),
                                  child: Text(t['variable'] ?? 'Variable',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ),
                              ),
                              Container(
                                  width: 1,
                                  color: Theme.of(context).dividerColor),
                              const SizedBox(width: _compactTableColumnGap),
                              Expanded(
                                flex: 2,
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal:
                                        _compactTableCellHorizontalPadding,
                                  ),
                                  child: Text(t['value'] ?? 'Value',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey)),
                                ),
                              ),
                              const SizedBox(width: _compactTableSideSlotWidth),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            final isLast = index == _rows.length - 1;
                            return Container(
                              height: _compactTableRowHeight,
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                            color: Theme.of(context)
                                                .dividerColor)),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: _compactTableOuterHorizontalPadding,
                                vertical: 0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: _compactTableSideSlotWidth,
                                    child: Center(
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            row.enabled = !row.enabled;
                                          });
                                        },
                                        child: FaIcon(
                                          row.enabled
                                              ? FontAwesomeIcons.squareCheck
                                              : FontAwesomeIcons.square,
                                          size: 16,
                                          color: row.enabled
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: row.keyController,
                                      onChanged: (val) {
                                        _handleRowTextChanged(row);
                                        if (isLast && val.trim().isNotEmpty) {
                                          setState(() {
                                            _ensureTrailingEmptyRow();
                                          });
                                        }
                                      },
                                      style: const TextStyle(
                                          fontSize: 12, fontFamily: 'Consolas'),
                                      decoration: const InputDecoration(
                                        hintText: 'Variable',
                                        hintStyle: TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal:
                                              _compactTableCellHorizontalPadding,
                                          vertical: 8,
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  Container(
                                      width: 1,
                                      color: Theme.of(context).dividerColor),
                                  const SizedBox(width: _compactTableColumnGap),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: row.valueController,
                                      onChanged: (_) {
                                        _handleRowTextChanged(row);
                                      },
                                      style: const TextStyle(
                                          fontSize: 12, fontFamily: 'Consolas'),
                                      decoration: const InputDecoration(
                                        hintText: 'Value',
                                        hintStyle: TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal:
                                              _compactTableCellHorizontalPadding,
                                          vertical: 8,
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Center(
                                      child: SizedBox(
                                        width: _compactTableSideSlotWidth,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          icon: const FaIcon(
                                              FontAwesomeIcons.xmark,
                                              size: 16,
                                              color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              final removed =
                                                  _rows.removeAt(index);
                                              removed.dispose();
                                            });
                                          },
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(
                                        width: _compactTableSideSlotWidth),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
