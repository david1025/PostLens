import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/console_provider.dart';
import '../providers/ui_provider.dart';
import '../providers/capture_provider.dart';
import '../providers/settings_provider.dart';
import 'global_variables_dialog.dart';

const _topBackgroundColor = Color(0xFFEDEFF2);

class StatusBar extends ConsumerWidget {
  final VoidCallback? onOpenTools;
  const StatusBar({super.key, this.onOpenTools});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSidebarCollapsed = ref.watch(isSidebarContentCollapsedProvider);
    final isCaptureOpen = ref.watch(isCaptureOpenProvider);
    final captureState = ref.watch(captureProvider);
    final t = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusBarBgColor = isDark ? const Color(0xFF2B2E31) : _topBackgroundColor;

    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: statusBarBgColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              StatefulBuilder(
                builder: (context, setState) {
                  bool isHovered = false;
                  return InkWell(
                    onTap: () {
                      if (isCaptureOpen) {
                        final isCaptureSidebarCollapsed = ref.read(isCaptureSidebarCollapsedProvider);
                        ref.read(isCaptureSidebarCollapsedProvider.notifier).state = !isCaptureSidebarCollapsed;
                      } else {
                        ref.read(isSidebarContentCollapsedProvider.notifier).state = !isSidebarCollapsed;
                      }
                    },
                    onHover: (value) => setState(() => isHovered = value),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: SvgPicture.asset(
                        (isCaptureOpen ? ref.watch(isCaptureSidebarCollapsedProvider) : isSidebarCollapsed)
                            ? 'assets/icons/layout-sidebar-left-off.svg'
                            : (isHovered
                                ? 'assets/icons/layout-sidebar-left-dock.svg'
                                : 'assets/icons/layout-sidebar-left.svg'),
                        width: 12,
                        height: 12,
                        colorFilter: const ColorFilter.mode(
                            Colors.grey, BlendMode.srcIn),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildStatusItem(
                FontAwesomeIcons.terminal,
                'Console',
                onTap: () {
                  final isOpen = ref.read(isConsoleOpenProvider);
                  ref.read(isConsoleOpenProvider.notifier).state = !isOpen;
                },
              ),
            ],
          ),
          Row(
            children: [
              _buildStatusItem(
                FontAwesomeIcons.globe,
                t['globals'] ?? 'Globals',
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => const GlobalVariablesDialog(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    IconData icon,
    String label, {
    bool iconRight = false,
    VoidCallback? onTap,
    Color? color,
  }) {
    final itemColor = color ?? Colors.grey;
    return InkWell(
      onTap: onTap ?? () {},
      child: Row(
        children: [
          if (!iconRight) ...[
            Icon(icon, size: 12, color: itemColor),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(fontSize: 10, color: itemColor)),
          if (iconRight) ...[
            const SizedBox(width: 4),
            Icon(icon, size: 12, color: itemColor),
          ],
        ],
      ),
    );
  }
}
