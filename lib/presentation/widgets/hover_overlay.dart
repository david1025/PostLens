import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef OverlayContentBuilder = Widget Function(
  BuildContext context,
  VoidCallback hide,
);

typedef HoverOverlayContentBuilder = OverlayContentBuilder;

/// 精简版日志：只记录关键事件
/// - insert: entry 被插入 overlay
/// - remove: entry 被移除
/// - evict: 同组旧控制器被踢出
/// - show-aborted: 显示失败（异常情况）
void _logOverlay({
  required String type,
  String? label,
  Object? group,
  required String event,
}) {
  if (!kDebugMode) return;
  final tag = label != null ? '[$type][$label]' : '[$type]';
  final grp = group != null ? ' #g$group' : '';
  
}

enum DropdownOverlayPlacement {
  bottomLeft,
  bottomCenter,
  bottomRight,
  topLeft,
  topCenter,
  topRight,
}

class HoverOverlayController {
  static final Map<Object, HoverOverlayController> _activeControllers = {};

  HoverOverlayController({String? debugLabel}) : _debugLabel = debugLabel;

  OverlayEntry? _entry;
  BuildContext? _anchorContext;
  LayerLink? _layerLink;
  Offset _offset = Offset.zero;
  Alignment _alignment = Alignment.topLeft;
  bool _showWhenUnlinked = false;
  bool _hideOnExit = true;
  HoverOverlayContentBuilder? _contentBuilder;
  Object? _groupId;
  final String? _debugLabel;
  final int _controllerId = identityHashCode(Object());

  bool get isShowing => _entry?.mounted ?? false;

  void show({
    required BuildContext context,
    required LayerLink layerLink,
    required Offset offset,
    required HoverOverlayContentBuilder contentBuilder,
    Alignment alignment = Alignment.topLeft,
    bool showWhenUnlinked = false,
    bool hideOnExit = true,
    Object? groupId,
    bool rootOverlay = true,
  }) {
    _activateGroup(groupId);
    _anchorContext = context;
    _layerLink = layerLink;
    _offset = offset;
    _alignment = alignment;
    _showWhenUnlinked = showWhenUnlinked;
    _hideOnExit = hideOnExit;
    _contentBuilder = contentBuilder;

    if (_entry == null || !_entry!.mounted) {
      final overlay = Overlay.maybeOf(context, rootOverlay: rootOverlay);
      if (overlay == null) {
        _log('show-aborted');
        return;
      }
      // 如果旧 entry 存在，先移除它（无论是否 mounted）
      // 这是避免 entry 残留的关键
      if (_entry != null) {
        try {
          _entry!.remove();
          _log('cleanup entry#${identityHashCode(_entry!)}');
        } catch (_) {
          // ignore: entry 可能已被移除
        }
      }
      _entry = OverlayEntry(builder: _buildOverlayEntry);
      _log('insert entry#${identityHashCode(_entry!)}');
      overlay.insert(_entry!);
    }
    // 注意：如果 _entry 已存在且 mounted，说明浮层已经在显示，
    // 此时不需要重新 insert，只需要更新参数即可
  }

  void rebuild() {
    if (_entry != null && _entry!.mounted) {
      _entry!.markNeedsBuild();
    }
  }

  void hide() {
    _deactivateGroup();
    final entry = _entry;
    _entry = null;
    _anchorContext = null;
    _layerLink = null;
    _contentBuilder = null;
    if (entry != null && entry.mounted) {
      _log('remove entry#${identityHashCode(entry)}');
      entry.remove();
    }
  }

  void dispose() {
    hide();
  }

  void _activateGroup(Object? groupId) {
    if (_groupId == groupId && groupId != null) {
      _activeControllers[groupId] = this;
      return;
    }
    _deactivateGroup();
    _groupId = groupId;
    if (groupId == null) return;
    final active = _activeControllers[groupId];
    if (active != null && !identical(active, this)) {
      _log('evict ${active._debugLabel ?? active._controllerId}');
      active.hide();
    }
    _activeControllers[groupId] = this;
  }

  void _deactivateGroup() {
    final groupId = _groupId;
    if (groupId != null && identical(_activeControllers[groupId], this)) {
      _activeControllers.remove(groupId);
    }
    _groupId = null;
  }

  Widget _buildOverlayEntry(BuildContext overlayContext) {
    final anchorContext = _anchorContext;
    final layerLink = _layerLink;
    final contentBuilder = _contentBuilder;
    if (anchorContext == null || layerLink == null || contentBuilder == null) {
      return const SizedBox.shrink();
    }

    return CompositedTransformFollower(
      link: layerLink,
      showWhenUnlinked: _showWhenUnlinked,
      offset: _offset,
      child: Align(
        alignment: _alignment,
        child: MouseRegion(
          onExit: _hideOnExit ? (_) => hide() : null,
          child: contentBuilder(anchorContext, hide),
        ),
      ),
    );
  }

  void _log(String event) {
    _logOverlay(
      type: 'hover',
      label: _debugLabel,
      group: _groupId,
      event: event,
    );
  }
}

class DropdownOverlayController {
  static final Map<Object, DropdownOverlayController> _activeControllers = {};

  DropdownOverlayController({String? debugLabel}) : _debugLabel = debugLabel;

  OverlayEntry? _entry;
  BuildContext? _context;
  LayerLink? _layerLink;
  Offset _offset = Offset.zero;
  Alignment _alignment = Alignment.topLeft;
  bool _showWhenUnlinked = false;
  bool _useFollower = false;
  bool _barrierDismissible = true;
  Color _barrierColor = Colors.transparent;
  BuildContext? _anchorContext;
  Size _panelSize = Size.zero;
  double _gap = 4;
  EdgeInsets _viewportMargin = const EdgeInsets.all(8);
  DropdownOverlayPlacement _placement = DropdownOverlayPlacement.bottomLeft;
  OverlayContentBuilder? _contentBuilder;
  Object? _groupId;
  final String? _debugLabel;
  final int _controllerId = identityHashCode(Object());

  bool get isShowing => _entry?.mounted ?? false;

  static DropdownOverlayController showAnchored({
    required BuildContext context,
    required BuildContext anchorContext,
    required Size panelSize,
    required OverlayContentBuilder contentBuilder,
    DropdownOverlayPlacement placement = DropdownOverlayPlacement.bottomLeft,
    double gap = 4,
    EdgeInsets viewportMargin = const EdgeInsets.all(8),
    bool barrierDismissible = true,
    Color barrierColor = Colors.transparent,
    Object? groupId,
    String? debugLabel,
    bool rootOverlay = true,
  }) {
    final controller = DropdownOverlayController(debugLabel: debugLabel);
    controller.showAnchoredOverlay(
      context: context,
      anchorContext: anchorContext,
      panelSize: panelSize,
      contentBuilder: contentBuilder,
      placement: placement,
      gap: gap,
      viewportMargin: viewportMargin,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      groupId: groupId,
      rootOverlay: rootOverlay,
    );
    return controller;
  }

  void showFollower({
    required BuildContext context,
    required LayerLink layerLink,
    required Offset offset,
    required OverlayContentBuilder contentBuilder,
    Alignment alignment = Alignment.topLeft,
    bool showWhenUnlinked = false,
    Object? groupId,
    bool rootOverlay = true,
  }) {
    _activateGroup(groupId);
    _context = context;
    _layerLink = layerLink;
    _offset = offset;
    _alignment = alignment;
    _showWhenUnlinked = showWhenUnlinked;
    _useFollower = true;
    _contentBuilder = contentBuilder;
    _insertOrRebuild(rootOverlay: rootOverlay);
  }

  void showAnchoredOverlay({
    required BuildContext context,
    required BuildContext anchorContext,
    required Size panelSize,
    required OverlayContentBuilder contentBuilder,
    DropdownOverlayPlacement placement = DropdownOverlayPlacement.bottomLeft,
    double gap = 4,
    EdgeInsets viewportMargin = const EdgeInsets.all(8),
    bool barrierDismissible = true,
    Color barrierColor = Colors.transparent,
    Object? groupId,
    bool rootOverlay = true,
  }) {
    _activateGroup(groupId);
    _context = context;
    _anchorContext = anchorContext;
    _panelSize = panelSize;
    _placement = placement;
    _gap = gap;
    _viewportMargin = viewportMargin;
    _barrierDismissible = barrierDismissible;
    _barrierColor = barrierColor;
    _useFollower = false;
    _contentBuilder = contentBuilder;
    _insertOrRebuild(rootOverlay: rootOverlay);
  }

  void rebuild() {
    if (_entry != null && _entry!.mounted) {
      _entry!.markNeedsBuild();
    }
  }

  void hide() {
    _deactivateGroup();
    final entry = _entry;
    _entry = null;
    _context = null;
    _layerLink = null;
    _anchorContext = null;
    _contentBuilder = null;
    if (entry != null && entry.mounted) {
      _log('remove entry#${identityHashCode(entry)}');
      entry.remove();
    }
  }

  void dispose() {
    hide();
  }

  void _activateGroup(Object? groupId) {
    if (_groupId == groupId && groupId != null) {
      _activeControllers[groupId] = this;
      return;
    }
    _deactivateGroup();
    _groupId = groupId;
    if (groupId == null) return;
    final active = _activeControllers[groupId];
    if (active != null && !identical(active, this)) {
      _log('evict ${active._debugLabel ?? active._controllerId}');
      active.hide();
    }
    _activeControllers[groupId] = this;
  }

  void _deactivateGroup() {
    final groupId = _groupId;
    if (groupId != null && identical(_activeControllers[groupId], this)) {
      _activeControllers.remove(groupId);
    }
    _groupId = null;
  }

  void _insertOrRebuild({required bool rootOverlay}) {
    final context = _context;
    if (context == null) return;

    if (_entry == null || !_entry!.mounted) {
      final overlay = Overlay.maybeOf(context, rootOverlay: rootOverlay);
      if (overlay == null) {
        _log('show-aborted');
        return;
      }
      // 如果旧 entry 存在，先移除它（无论是否 mounted）
      // 这是避免 entry 残留的关键
      if (_entry != null) {
        try {
          _entry!.remove();
          _log('cleanup entry#${identityHashCode(_entry!)}');
        } catch (_) {
          // ignore: entry 可能已被移除
        }
      }
      _entry = OverlayEntry(builder: _buildOverlayEntry);
      _log('insert entry#${identityHashCode(_entry!)}');
      overlay.insert(_entry!);
    }
  }

  Widget _buildOverlayEntry(BuildContext overlayContext) {
    final contentBuilder = _contentBuilder;
    if (contentBuilder == null) {
      return const SizedBox.shrink();
    }

    if (_useFollower) {
      final layerLink = _layerLink;
      if (layerLink == null) {
        return const SizedBox.shrink();
      }
      return CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: _showWhenUnlinked,
        offset: _offset,
        child: Align(
          alignment: _alignment,
          child: contentBuilder(overlayContext, hide),
        ),
      );
    }

    final position = _computeAnchoredPosition(overlayContext);
    if (position == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (_barrierDismissible || _barrierColor.opacity > 0)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _barrierDismissible ? hide : null,
              child: ColoredBox(color: _barrierColor),
            ),
          ),
        Positioned(
          left: position.dx,
          top: position.dy,
          child: contentBuilder(overlayContext, hide),
        ),
      ],
    );
  }

  Offset? _computeAnchoredPosition(BuildContext overlayContext) {
    final anchorContext = _anchorContext;
    final anchorRender = anchorContext?.findRenderObject();
    final overlayRender = Overlay.maybeOf(overlayContext)?.context.findRenderObject();
    if (anchorRender is! RenderBox || overlayRender is! RenderBox) {
      return null;
    }

    final anchorRect = Rect.fromPoints(
      anchorRender.localToGlobal(Offset.zero, ancestor: overlayRender),
      anchorRender.localToGlobal(
        anchorRender.size.bottomRight(Offset.zero),
        ancestor: overlayRender,
      ),
    );

    double left;
    double top;

    switch (_placement) {
      case DropdownOverlayPlacement.bottomLeft:
        left = anchorRect.left;
        top = anchorRect.bottom + _gap;
        break;
      case DropdownOverlayPlacement.bottomCenter:
        left = anchorRect.left + (anchorRect.width - _panelSize.width) / 2;
        top = anchorRect.bottom + _gap;
        break;
      case DropdownOverlayPlacement.bottomRight:
        left = anchorRect.right - _panelSize.width;
        top = anchorRect.bottom + _gap;
        break;
      case DropdownOverlayPlacement.topLeft:
        left = anchorRect.left;
        top = anchorRect.top - _panelSize.height - _gap;
        break;
      case DropdownOverlayPlacement.topCenter:
        left = anchorRect.left + (anchorRect.width - _panelSize.width) / 2;
        top = anchorRect.top - _panelSize.height - _gap;
        break;
      case DropdownOverlayPlacement.topRight:
        left = anchorRect.right - _panelSize.width;
        top = anchorRect.top - _panelSize.height - _gap;
        break;
    }

    final minLeft = _viewportMargin.left;
    final minTop = _viewportMargin.top;
    final maxLeft =
        overlayRender.size.width - _panelSize.width - _viewportMargin.right;
    final maxTop =
        overlayRender.size.height - _panelSize.height - _viewportMargin.bottom;

    return Offset(
      left.clamp(minLeft, maxLeft < minLeft ? minLeft : maxLeft),
      top.clamp(minTop, maxTop < minTop ? minTop : maxTop),
    );
  }

  void _log(String event) {
    _logOverlay(
      type: 'dropdown',
      label: _debugLabel,
      group: _groupId,
      event: event,
    );
  }
}

class AppOverlayDialogs {
  static Future<T?> showModalLike<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    String barrierLabel = 'Dialog',
    Color barrierColor = Colors.black54,
    Duration transitionDuration = Duration.zero,
    bool useRootNavigator = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: barrierLabel,
      barrierColor: barrierColor,
      transitionDuration: transitionDuration,
      useRootNavigator: useRootNavigator,
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          builder(dialogContext),
    );
  }
}

class OverlayPanel extends StatelessWidget {
  const OverlayPanel({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.elevation = 10,
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      color: Theme.of(context).cardColor,
      borderRadius: borderRadius,
      child: Container(
        width: width,
        padding: padding,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: borderRadius,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: child,
      ),
    );
  }
}

class HoverOverlayPanel extends StatelessWidget {
  const HoverOverlayPanel({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.elevation = 10,
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return OverlayPanel(
      width: width,
      padding: padding,
      borderRadius: borderRadius,
      elevation: elevation,
      child: child,
    );
  }
}
