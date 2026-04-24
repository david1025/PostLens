import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/global_variables_provider.dart';
import '../providers/settings_provider.dart';
import 'package:post_lens/presentation/widgets/common/custom_controls.dart';

class _GlobalVarRow {
  bool enabled;
  final TextEditingController keyController;
  final TextEditingController valueController;

  _GlobalVarRow({
    required this.enabled,
    required this.keyController,
    required this.valueController,
  });

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class GlobalVariablesDialog extends ConsumerStatefulWidget {
  const GlobalVariablesDialog({super.key});

  @override
  ConsumerState<GlobalVariablesDialog> createState() =>
      _GlobalVariablesDialogState();
}

class _GlobalVariablesDialogState extends ConsumerState<GlobalVariablesDialog> {
  final List<_GlobalVarRow> _rows = [];
  bool _initialized = false;

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _ensureTrailingEmptyRow() {
    if (_rows.isEmpty || _rows.last.keyController.text.trim().isNotEmpty) {
      _rows.add(
        _GlobalVarRow(
          enabled: true,
          keyController: TextEditingController(),
          valueController: TextEditingController(),
        ),
      );
    }
  }

  void _initFromState() {
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();
    final variables = ref.read(globalVariablesProvider);
    for (final v in variables) {
      _rows.add(
        _GlobalVarRow(
          enabled: v.enabled,
          keyController: TextEditingController(text: v.key),
          valueController: TextEditingController(text: v.value),
        ),
      );
    }
    _ensureTrailingEmptyRow();
  }

  void _save() {
    final validVars = _rows
        .where((r) => r.keyController.text.trim().isNotEmpty)
        .map((r) => GlobalVariable(
              key: r.keyController.text.trim(),
              value: r.valueController.text,
              enabled: r.enabled,
            ))
        .toList();
    ref.read(globalVariablesProvider.notifier).setVariables(validVars);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);

    if (!_initialized) {
      _initFromState();
      _initialized = true;
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    t['global_variables'] ?? 'Global Variables',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const FaIcon(FontAwesomeIcons.xmark,
                        size: 16, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 16,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                t['global_variables_desc'] ??
                    'These variables are available in all requests. Use {{variable_name}} syntax to reference them.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          border: Border(
                              bottom: BorderSide(
                                  color: Theme.of(context).dividerColor)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(width: 32),
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.centerLeft,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                    t['variable'] ?? 'Variable',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ),
                            ),
                            Container(
                                width: 1,
                                color: Theme.of(context).dividerColor),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Container(
                                alignment: Alignment.centerLeft,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                    t['value'] ?? 'Value',
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                              ),
                            ),
                            const SizedBox(width: 32),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 320,
                        child: ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            final isLast = index == _rows.length - 1;
                            return Container(
                              height: 32,
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                            color: Theme.of(context)
                                                .dividerColor)),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: 32,
                                    child: Center(
                                      child: CustomCheckbox(
                                        value: row.enabled,
                                        onChanged: (val) {
                                          setState(() {
                                            row.enabled = val ?? true;
                                          });
                                        },
                                        materialTapTargetSize:
                                            MaterialTapTargetSize
                                                .shrinkWrap,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: row.keyController,
                                      onChanged: (val) {
                                        if (isLast &&
                                            val.trim().isNotEmpty) {
                                          setState(() {
                                            _ensureTrailingEmptyRow();
                                          });
                                        }
                                      },
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Consolas'),
                                      decoration: const InputDecoration(
                                        hintText: 'Variable',
                                        hintStyle: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  Container(
                                      width: 1,
                                      color:
                                          Theme.of(context).dividerColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: row.valueController,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Consolas'),
                                      decoration: const InputDecoration(
                                        hintText: 'Value',
                                        hintStyle: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (!isLast)
                                    Center(
                                      child: SizedBox(
                                        width: 32,
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
                                    const SizedBox(width: 32),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).textTheme.bodyMedium!.color,
                        side: BorderSide(
                            color: Theme.of(context).dividerColor),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(t['cancel'] ?? 'Cancel',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(t['save'] ?? 'Save',
                          style: const TextStyle(fontSize: 12)),
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
}
