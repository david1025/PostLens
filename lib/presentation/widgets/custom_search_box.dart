import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomSearchBox extends StatelessWidget {
  final double? width;
  final double? height;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final Color? borderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const CustomSearchBox({
    super.key,
    this.width,
    this.height = 30,
    this.hintText = 'Filter',
    this.onChanged,
    this.controller,
    this.focusNode,
    this.borderColor,
    this.borderWidth = 1.0,
    this.borderRadius = 4.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderCol = borderColor ?? Colors.grey.withOpacity(0.5);

    return Padding(
      padding: padding,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderCol, width: borderWidth),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 6.0),
              child: SvgPicture.asset(
                'assets/icons/search.svg',
                width: 14,
                height: 14,
                colorFilter: const ColorFilter.mode(
                    Colors.grey, BlendMode.srcIn),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  maxLines: 1,
                  cursorWidth: 1,
                  decoration: InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    hintText: hintText,
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Colors.grey),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
