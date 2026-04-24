part of 'sidebar.dart';

extension SidebarToolsExt on _SidebarState {
  Widget _buildToolCategorySection(
      ToolCategory category, void Function(String, String)? onToolTap) {
    final controller = _tileControllers.putIfAbsent(
      'tool_cat_${category.name}',
      () => TreeController(isExpanded: true),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => controller.toggle(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    AnimatedRotation(
                      turns: controller.isExpanded ? 0 : -0.25,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        FontAwesomeIcons.chevronDown,
                        size: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (controller.isExpanded)
              Padding(
                padding: const EdgeInsets.only(
                    left: 12.0, right: 12.0, bottom: 16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double maxWidth = constraints.maxWidth;
                    if (maxWidth.isInfinite) maxWidth = 250.0;

                    final double itemWidth = 65.0;
                    final double minSpacing = 0.0;
                    
                    int crossAxisCount = ((maxWidth + minSpacing) / (itemWidth + minSpacing)).floor();
                    if (crossAxisCount < 1) crossAxisCount = 1;
                    
                    double spacing = 0.0;
                    if (crossAxisCount > 1) {
                      spacing = (maxWidth - (crossAxisCount * itemWidth)) / (crossAxisCount - 1);
                      spacing = spacing.floorToDouble();
                    }

                    return Wrap(
                      alignment: WrapAlignment.start,
                      spacing: spacing,
                      runSpacing: 12,
                      children: category.items.map((item) {
                    return HoverContainer(
                      builder: (isHovered) {
                        return InkWell(
                          onTap: () {
                            if (onToolTap != null) {
                              onToolTap(item.id, item.name);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 65,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? Colors.grey.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 18,
                                      color: item.color,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color ??
                                        Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

}
