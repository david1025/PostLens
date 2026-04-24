import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class TreeController extends ChangeNotifier {
  bool _isExpanded;
  TreeController({bool isExpanded = false}) : _isExpanded = isExpanded;

  bool get isExpanded => _isExpanded;

  void expand() {
    if (!_isExpanded) {
      _isExpanded = true;
      _safeNotify();
    }
  }

  void collapse() {
    if (_isExpanded) {
      _isExpanded = false;
      _safeNotify();
    }
  }

  void toggle() {
    _isExpanded = !_isExpanded;
    _safeNotify();
  }

  void _safeNotify() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }
}

class HoverContainer extends StatefulWidget {
  final Widget Function(bool isHovered) builder;
  const HoverContainer({super.key, required this.builder});

  @override
  State<HoverContainer> createState() => HoverContainerState();
}

class HoverContainerState extends State<HoverContainer> {
  bool _isHovered = false;
  bool _isPopupOpen = false;

  void setPopupOpen(bool isOpen) {
    if (mounted) {
      setState(() {
        _isPopupOpen = isOpen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(_isHovered || _isPopupOpen),
    );
  }
}
