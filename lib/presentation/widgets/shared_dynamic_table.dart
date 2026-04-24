import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'table_cell_text_field.dart';

class SharedDynamicTable extends StatelessWidget {
  final List<Map<String, String>> items;
  final List<Map<String, String>>? mockItems;
  final void Function(String key, String value, String desc) onAdd;
  final void Function(int index, String key, String value) onUpdate;
  final void Function(int index) onRemove;
  final void Function(int index, bool enabled) onToggle;
  final void Function(int index, String desc)? onUpdateDesc;

  const SharedDynamicTable({
    super.key,
    required this.items,
    this.mockItems,
    required this.onAdd,
    required this.onUpdate,
    required this.onRemove,
    required this.onToggle,
    this.onUpdateDesc,
  });

  static const double _compactTableRowHeight = 28;
  static const double _compactTableOuterHorizontalPadding = 6;
  static const double _compactTableCellHorizontalPadding = 4;
  static const double _compactTableColumnGap = 6;
  static const double _compactTableSideSlotWidth = 28;
  static const double _compactTableLeadingSlotWidth = 22;

  Widget _buildTableCell(
    BuildContext context,
    String text, {
    required bool isHeader,
    required String hint,
    bool readOnly = false,
    required Function(String) onChanged,
  }) {
    if (isHeader) {
      return Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
          horizontal: _compactTableCellHorizontalPadding,
        ),
        child: Text(text,
            style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 12,
                fontWeight: FontWeight.normal)),
      );
    }
    return Container(
      alignment: Alignment.centerLeft,
      child: TableCellTextField(
        text: text,
        hint: hint,
        readOnly: readOnly,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String key,
    String value,
    String desc, {
    required bool isHeader,
    int? index,
    bool isNew = false,
    bool enabled = true,
    bool readOnly = false,
    bool isLast = false,
  }) {
    return Container(
      height: _compactTableRowHeight,
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
        color: isHeader || readOnly
            ? Theme.of(context).scaffoldBackgroundColor
            : Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: _compactTableOuterHorizontalPadding,
        vertical: 0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isHeader) ...[
            SizedBox(
              width: 16,
              child: isNew
                  ? null
                  : (readOnly
                      ? const Center(
                          child: FaIcon(FontAwesomeIcons.circleInfo,
                              size: 14, color: Colors.grey),
                        )
                      : InkWell(
                          onTap: () {
                            if (index != null) {
                              onToggle(index, !enabled);
                            }
                          },
                          child: Center(
                            child: FaIcon(
                              enabled
                                  ? FontAwesomeIcons.squareCheck
                                  : FontAwesomeIcons.square,
                              size: 16,
                              color: enabled
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                          ),
                        )),
            ),
            const SizedBox(width: _compactTableColumnGap),
          ] else
            const SizedBox(width: _compactTableLeadingSlotWidth),
          Expanded(
            flex: 2,
            child: _buildTableCell(context, key, isHeader: isHeader, hint: 'Key',
                readOnly: readOnly, onChanged: (v) {
              if (isNew) {
                onAdd(v, '', '');
              } else if (index != null && !readOnly) {
                onUpdate(index, v, value);
              }
            }),
          ),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 2,
              child: _buildTableCell(context, value,
                  isHeader: isHeader,
                  hint: 'Value',
                  readOnly: readOnly, onChanged: (v) {
                if (isNew) {
                  onAdd(key, v, '');
                } else if (index != null && !readOnly) {
                  onUpdate(index, key, v);
                }
              })),
          Container(width: 1, color: Theme.of(context).dividerColor),
          const SizedBox(width: _compactTableColumnGap),
          Expanded(
              flex: 3,
              child: _buildTableCell(context, desc,
                  isHeader: isHeader,
                  hint: 'Description',
                  readOnly: readOnly,
                  onChanged: (v) {
                if (isNew) {
                  onAdd(key, value, v);
                } else if (index != null && onUpdateDesc != null) {
                  onUpdateDesc!(index, v);
                }
              })),
          if (!isHeader)
            SizedBox(
              width: _compactTableSideSlotWidth,
              child: (isNew || readOnly)
                  ? null
                  : Center(
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const FaIcon(FontAwesomeIcons.xmark,
                            size: 16, color: Colors.grey),
                        onPressed: () {
                          if (index != null) {
                            onRemove(index);
                          }
                        },
                      ),
                    ),
            )
          else
            const SizedBox(width: _compactTableSideSlotWidth),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRow(context, 'Key', 'Value', 'Description', isHeader: true),
            if (mockItems != null)
              ...mockItems!.map((mock) => _buildRow(
                    context,
                    mock['key'] ?? '',
                    mock['value'] ?? '',
                    mock['description'] ?? 'Auto-generated',
                    isHeader: false,
                    readOnly: true,
                  )),
            ...items.asMap().entries.map((entry) {
              return _buildRow(
                context,
                entry.value['key'] ?? '',
                entry.value['value'] ?? '',
                entry.value['description'] ?? '',
                isHeader: false,
                index: entry.key,
                enabled: (entry.value['enabled'] ?? 'true') == 'true',
              );
            }),
            _buildRow(context, '', '', '',
                isHeader: false, isNew: true, isLast: true),
          ],
        ),
      ),
    );
  }
}
