import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../providers/settings_provider.dart';
import '../providers/environment_provider.dart';
import '../../domain/models/environment_model.dart';

class HoverActionSurface extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const HoverActionSurface({
    super.key,
    required this.child,
    required this.onTap,
    required this.padding,
    required this.borderRadius,
  });

  @override
  State<HoverActionSurface> createState() => HoverActionSurfaceState();
}

class HoverActionSurfaceState extends State<HoverActionSurface> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05))
              : Colors.transparent,
          borderRadius: widget.borderRadius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: widget.borderRadius,
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class HoverQuickActionCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double width;

  const HoverQuickActionCard({
    super.key,
    required this.child,
    required this.onTap,
    required this.width,
  });

  @override
  State<HoverQuickActionCard> createState() => HoverQuickActionCardState();
}

class HoverQuickActionCardState extends State<HoverQuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _isHovered
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.025)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              width: widget.width,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class ShortcutKeyCap extends StatelessWidget {
  final String label;

  const ShortcutKeyCap({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2130) : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

// ─── Environment Dropdown Content (matches screenshot UI) ───

class EnvironmentDropdownContent extends ConsumerStatefulWidget {
  final void Function(String? envId) onSelected;
  final VoidCallback onAddNew;
  final VoidCallback onClose;

  const EnvironmentDropdownContent({
    super.key,
    required this.onSelected,
    required this.onAddNew,
    required this.onClose,
  });

  @override
  ConsumerState<EnvironmentDropdownContent> createState() =>
      EnvironmentDropdownContentState();
}

class EnvironmentDropdownContentState
    extends ConsumerState<EnvironmentDropdownContent> {
  String _searchQuery = '';
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(translationsProvider);
    final environments = ref.watch(activeWorkspaceEnvironmentsProvider);
    final activeEnvironmentId = ref.watch(activeEnvironmentIdProvider);

    final filtered = environments.where((e) {
      if (_searchQuery.isEmpty) return true;
      return e.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Theme.of(context).dialogTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF313236)
              : const Color(0xFFE9EDF1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search row with + button
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 26,
                      child: TextField(
                        focusNode: _focusNode,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                BorderSide(color: Colors.grey.withOpacity(0.5)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                BorderSide(color: Colors.grey.withOpacity(0.5)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide:
                                BorderSide(color: Colors.grey.withOpacity(0.5)),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 26,
                    width: 26,
                    child: InkWell(
                      onTap: widget.onAddNew,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child:
                            const Icon(Icons.add, size: 14, color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: Theme.of(context).dividerColor),

          // Environment list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: filtered.length + 1, // +1 for "No environment"
              itemBuilder: (context, index) {
                // First item: No environment
                if (index == 0) {
                  final isSelected = activeEnvironmentId == null;
                  return _buildEnvListItem(
                    context: context,
                    label: t['no_environment'] ?? 'No Environment',
                    isSelected: isSelected,
                    onTap: () => widget.onSelected(null),
                  );
                }
                // Environment items
                final env = filtered[index - 1];
                final isSelected = activeEnvironmentId == env.id;
                return _buildEnvListItem(
                  context: context,
                  label: env.name,
                  isSelected: isSelected,
                  onTap: () => widget.onSelected(env.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvListItem({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return HoverableEnvListItem(
      label: label,
      isSelected: isSelected,
      onTap: onTap,
    );
  }
}

/// Hoverable environment list item with hover effect
class HoverableEnvListItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const HoverableEnvListItem({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<HoverableEnvListItem> createState() => HoverableEnvListItemState();
}

class HoverableEnvListItemState extends State<HoverableEnvListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? bgColor;
    if (widget.isSelected || _isHovered) {
      bgColor = theme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.05);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: bgColor,
          child: Row(
            children: [
              if (widget.isSelected)
                const FaIcon(FontAwesomeIcons.check,
                    size: 14, color: Colors.grey)
              else
                const SizedBox(width: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        widget.isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
