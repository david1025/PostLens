import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CustomCheckbox extends StatelessWidget {
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final BorderSide? side;
  final MaterialTapTargetSize? materialTapTargetSize;
  final double? splashRadius;

  const CustomCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.side,
    this.materialTapTargetSize,
    this.splashRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bool isChecked = value ?? false;
    final bool enabled = onChanged != null;
    
    return InkWell(
      onTap: enabled ? () => onChanged!(!isChecked) : null,
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: 16,
        child: Center(
          child: FaIcon(
            isChecked ? FontAwesomeIcons.squareCheck : FontAwesomeIcons.square,
            size: 16,
            color: enabled
                ? (isChecked ? Theme.of(context).colorScheme.primary : Colors.grey)
                : Colors.grey.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class CustomCheckboxListTile extends StatelessWidget {
  final Widget title;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final ListTileControlAffinity controlAffinity;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense;

  const CustomCheckboxListTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.contentPadding,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isChecked = value ?? false;
    final bool enabled = onChanged != null;

    final Widget control = CustomCheckbox(
      value: isChecked,
      onChanged: onChanged,
    );

    return InkWell(
      onTap: enabled ? () => onChanged!(!isChecked) : null,
      child: Padding(
        padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            if (controlAffinity == ListTileControlAffinity.leading) ...[
              control,
              const SizedBox(width: 8),
              Expanded(child: title),
            ] else ...[
              Expanded(child: title),
              const SizedBox(width: 8),
              control,
            ],
          ],
        ),
      ),
    );
  }
}

class CustomRadio<T> extends StatelessWidget {
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final MaterialTapTargetSize? materialTapTargetSize;

  const CustomRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.materialTapTargetSize,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    final bool selected = value == groupValue;

    return InkWell(
      onTap: enabled ? () => onChanged!(value) : null,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 16,
        child: Center(
          child: FaIcon(
            selected ? FontAwesomeIcons.circleDot : FontAwesomeIcons.circle,
            size: 16,
            color: enabled
                ? (selected ? Theme.of(context).colorScheme.primary : Colors.grey)
                : Colors.grey.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

class CustomRadioListTile<T> extends StatelessWidget {
  final Widget title;
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Color? activeColor;
  final EdgeInsetsGeometry? contentPadding;

  const CustomRadioListTile({
    super.key,
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.activeColor,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    
    return InkWell(
      onTap: enabled ? () => onChanged!(value) : null,
      child: Padding(
        padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            CustomRadio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
            ),
            const SizedBox(width: 8),
            Expanded(child: title),
          ],
        ),
      ),
    );
  }
}
