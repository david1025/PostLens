import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AppBreadcrumbItem {
  final String label;
  final bool isCurrent;
  final VoidCallback? onTap;

  const AppBreadcrumbItem({
    required this.label,
    this.isCurrent = false,
    this.onTap,
  });
}

class AppBreadcrumb extends StatelessWidget {
  final List<AppBreadcrumbItem> items;
  final VoidCallback? onRootTap;

  const AppBreadcrumb({
    super.key,
    required this.items,
    this.onRootTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty && onRootTap == null) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onRootTap != null)
            _buildNode(
              context,
              child: const FaIcon(
                FontAwesomeIcons.networkWired,
                size: 12,
                color: Colors.blue,
              ),
              onTap: onRootTap,
            ),
          for (int i = 0; i < items.length; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                '›',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
            _buildNode(
              context,
              child: Text(
                items[i].label,
                style: TextStyle(
                  fontSize: 12,
                  color: items[i].isCurrent
                      ? Theme.of(context).textTheme.bodyMedium?.color
                      : Colors.grey,
                  fontWeight:
                      items[i].isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              onTap: items[i].onTap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNode(
    BuildContext context, {
    required Widget child,
    VoidCallback? onTap,
  }) {
    if (onTap == null) {
      return child;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: child,
      ),
    );
  }
}
